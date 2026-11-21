return function(Controller: any, Config: any, IntroOptions: any): string
	local Lighting = game:GetService("Lighting")
	local SoundService = game:GetService("SoundService")
	local Clouds = workspace.Terrain:FindFirstChildWhichIsA("Clouds")
	local OriginalColor = Clouds and Clouds.Color
	local Source = "LightningValidation"
	local OtherSource = "LightningValidationWeather"
	local EffectsRoot: Instance?
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		local NearDelay, NearVolume = Controller.GetThunderAudio(0)
		local Delay, Volume = Controller.GetThunderAudio(300)
		local FarDelay, FarVolume = Controller.GetThunderAudio(600)
		Check(NearDelay == 0 and NearVolume == Config.Thunder.MaximumVolume, "Nearby thunder has bounded volume and zero travel time")
		Check(math.abs(Delay - 300 * Config.Thunder.MetersPerStud / Config.Thunder.SpeedOfSound) < 0.000001,
			"Thunder delay uses distance converted to meters and the speed of sound")
		Check(math.abs(FarDelay - Delay * 2) < 0.000001 and NearDelay < Delay, "Doubling distance doubles propagation delay")
		Check(NearVolume > Volume and Volume > FarVolume, "Volume attenuates with distance")
		local _, Inaudible = Controller.GetThunderAudio(Config.Thunder.MaximumDistance + 1)
		Check(Inaudible == 0, "Thunder outside audible range is silent")

		local Generator = Random.new(173)
		local Center = Vector3.new(8000, 100, -7000)
		for _ = 1, 200 do
			local Position = Controller.GetStrikePosition(Center, IntroOptions, Generator)
			local Radius = (Vector3.new(Position.X, 0, Position.Z) - Vector3.new(Center.X, 0, Center.Z)).Magnitude
			Check(Radius >= IntroOptions.MinimumRadius - 0.01 and Radius <= IntroOptions.MaximumRadius + 0.01,
				"Intro strikes remain in their configured ring around the ship")
			Check(Position.Y == IntroOptions.SurfaceY, "Intro lightning strikes the ocean surface")
		end

		local Camera = assert(workspace.CurrentCamera, "A local camera is required")
		local Position = Camera.CFrame.Position + Vector3.xAxis * 300
		local function GetCenter(): Vector3
			return Position
		end
		local Slow = { MinimumInterval = 60, MaximumInterval = 60 }
		Controller:StartStorm(Source, GetCenter, Slow)
		local Sounds = SoundService:FindFirstChild(Source .. "Thunder") :: Folder
		Controller:StartStorm(Source, GetCenter, Slow)
		Check(Sounds == SoundService:FindFirstChild(Source .. "Thunder"), "Repeated starts reuse their storm")
		Controller:StartStorm(OtherSource, GetCenter, Slow)
		local OtherSounds = SoundService:FindFirstChild(OtherSource .. "Thunder")

		local Started = os.clock()
		local Strike = assert(Controller:Strike(Position, Source), "An active storm can emit a strike")
		EffectsRoot = Strike.Parent and Strike.Parent.Parent
		Check(Strike:GetAttribute("StrikePosition") == Position, "The bolt reaches its requested position")
		local Parts = Strike:QueryDescendants("BasePart")
		Check(#Parts == Config.Bolt.Segments + Config.Bolt.BranchCount * Config.Bolt.BranchSegments,
			"Main bolt and branches use the configured segment budget")
		for _, Instance in Parts do
			local Part = Instance :: BasePart
			Check(Part.Material == Enum.Material.Neon and Part.Color == Color3.new(1, 1, 1), "Lightning is white Neon")
			Check(Part.Anchored and not Part.CanCollide and not Part.CanTouch and not Part.CanQuery,
				"Client lightning cannot affect collisions, interactions or raycasts")
		end
		if Clouds then
			Check(Clouds.Color == Config.Flash.CloudColor, "Clouds brighten with the strike")
		end
		local Flash = Lighting:FindFirstChild("LightningFlash") :: ColorCorrectionEffect
		Check(Flash ~= nil and Flash.Brightness > 0 and Flash:GetAttribute("Core") == true,
			"The sky flash survives lighting preset refreshes")
		local Sound = Sounds:FindFirstChildWhichIsA("Sound") :: Sound
		Check(Sound ~= nil and Sound:IsDescendantOf(SoundService), "Thunder plays in the local SoundService")
		Check(table.find(Config.Thunder.SoundIds, Sound.SoundId) ~= nil, "Use one of the requested thunder sounds")
		Check(math.abs(Sound.Volume - Volume) < 0.00001 and not Sound.IsPlaying, "Distance sets volume before delayed playback")
		local PlayedAt: number?
		Sound.Played:Once(function()
			PlayedAt = os.clock()
		end)
		task.wait(math.max(Delay, Config.Flash.HoldTime + Config.Flash.FadeTime, Config.Bolt.Lifetime) + 0.15)
		Check(PlayedAt ~= nil and PlayedAt - Started >= Delay - 0.025, "Thunder waits for sound propagation")
		Check(Strike.Parent == nil, "Bolts and branches are cleaned up after their flash")
		Check(Lighting:FindFirstChild("LightningFlash") == nil, "The sky flash ends automatically")
		if Clouds then
			Check(Clouds.Color == OriginalColor, "Clouds return to their original color")
		end

		local Cancelled = assert(Controller:Strike(Position, Source))
		local Pending = Sounds:GetChildren()
		Controller:StopStorm(Source)
		Check(Cancelled.Parent == nil and Sounds.Parent == nil, "Stopping a storm clears its effects and thunder")
		Check(OtherSounds ~= nil and OtherSounds.Parent == SoundService, "Another storm remains independent")
		Check(Controller:Strike(Position, Source) == nil, "Stopped storms cannot emit stale strikes")
		Controller:StopStorm(OtherSource)
		Check(Lighting:FindFirstChild("LightningFlash") == nil, "Stopping the final storm immediately clears its flash")
		if Clouds then
			Check(Clouds.Color == OriginalColor, "Stopping during a flash restores cloud color")
		end
		task.wait(Delay + 0.05)
		for _, PendingSound in Pending do
			Check(PendingSound.Parent == nil, "Cancelled delayed thunder cannot outlive the storm")
		end
	end)
	Controller:StopStorm(Source)
	Controller:StopStorm(OtherSource)
	if EffectsRoot then
		EffectsRoot:Destroy()
	end
	assert(Success, tostring(Error))

	return string.format("Lightning: %d checks passed", Checks)
end
