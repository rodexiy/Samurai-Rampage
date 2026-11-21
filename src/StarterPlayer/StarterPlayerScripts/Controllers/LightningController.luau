local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local LightningBolt = require(ReplicatedStorage.Assets.Libraries.LightningBolt)
local LightningConfig = require(ReplicatedStorage.Shared.LightningConfig)

local LightningController = Knit.CreateController({ Name = "LightningController" })

export type StormOptions = {
	MinimumInterval: number?,
	MaximumInterval: number?,
	MinimumRadius: number?,
	MaximumRadius: number?,
	SurfaceY: number?,
}

type Storm = {
	Center: () -> Vector3?,
	Options: StormOptions,
	Effects: Folder,
	Sounds: Folder,
	NextStrike: thread?,
	Paused: boolean?,
}

local RandomGenerator = Random.new()
local Storms: { [string]: Storm } = {}
local EffectsFolder: Folder?
local FlashRevision = 0
local FlashClouds: Clouds?
local OriginalCloudColor: Color3?
local CloudTween: Tween?
local FlashEffect: ColorCorrectionEffect?
local FlashTween: Tween?

local function GetEffectsFolder(): Folder
	if not EffectsFolder or not EffectsFolder.Parent then
		EffectsFolder = Instance.new("Folder")
		EffectsFolder.Name = "ClientLightning"
		EffectsFolder.Parent = workspace
	end

	return EffectsFolder
end

function LightningController.GetThunderAudio(Distance: number): (number, number)
	local Config = LightningConfig.Thunder
	local Studs = math.max(0, Distance)
	local Delay = Studs * Config.MetersPerStud / Config.SpeedOfSound
	local Volume = if Studs > Config.MaximumDistance then 0
		else Config.MaximumVolume * Config.ReferenceDistance / math.max(Config.ReferenceDistance, Studs)

	return Delay, Volume
end

function LightningController.GetStrikePosition(Center: Vector3, Options: StormOptions, Generator: Random): Vector3
	local Defaults = LightningConfig.Storm
	local Minimum = math.max(0, Options.MinimumRadius or Defaults.MinimumRadius)
	local Maximum = math.max(Minimum, Options.MaximumRadius or Defaults.MaximumRadius)
	local Angle = Generator:NextNumber(0, 2 * math.pi)
	local Radius = Generator:NextNumber(Minimum, Maximum)

	return Vector3.new(Center.X + math.cos(Angle) * Radius, Options.SurfaceY or Center.Y, Center.Z + math.sin(Angle) * Radius)
end

local function RestoreFlash()
	FlashRevision += 1
	if CloudTween then
		CloudTween:Cancel()
		CloudTween = nil
	end
	if FlashTween then
		FlashTween:Cancel()
		FlashTween = nil
	end
	if FlashClouds and FlashClouds.Parent and OriginalCloudColor then
		FlashClouds.Color = OriginalCloudColor
	end
	if FlashEffect then
		FlashEffect:Destroy()
		FlashEffect = nil
	end

	FlashClouds = nil
	OriginalCloudColor = nil
end

local function FlashSky()
	local Clouds = workspace.Terrain:FindFirstChildWhichIsA("Clouds")
	if FlashClouds ~= Clouds then
		RestoreFlash()
	end
	FlashRevision += 1
	local Revision = FlashRevision
	if CloudTween then
		CloudTween:Cancel()
	end
	if FlashTween then
		FlashTween:Cancel()
	end

	if Clouds then
		if not OriginalCloudColor then
			OriginalCloudColor = Clouds.Color
		end
		FlashClouds = Clouds
		Clouds.Color = LightningConfig.Flash.CloudColor
	end
	if not FlashEffect or not FlashEffect.Parent then
		FlashEffect = Instance.new("ColorCorrectionEffect")
		FlashEffect.Name = "LightningFlash"
		FlashEffect:SetAttribute("Core", true)
		FlashEffect.Parent = Lighting
	end
	FlashEffect.Brightness = LightningConfig.Flash.Brightness

	task.delay(LightningConfig.Flash.HoldTime, function()
		if Revision ~= FlashRevision or not FlashEffect then
			return
		end

		local Fade = TweenInfo.new(LightningConfig.Flash.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if FlashClouds and FlashClouds.Parent and OriginalCloudColor then
			CloudTween = TweenService:Create(FlashClouds, Fade, { Color = OriginalCloudColor })
			CloudTween:Play()
		end
		FlashTween = TweenService:Create(FlashEffect, Fade, { Brightness = 0 })
		FlashTween.Completed:Once(function(State: Enum.PlaybackState)
			if Revision == FlashRevision and State == Enum.PlaybackState.Completed then
				RestoreFlash()
			end
		end)
		FlashTween:Play()
	end)
end

local function CreateBolt(Start: Vector3, Finish: Vector3, Segments: number, Thickness: number, Parent: Model): any
	local Config = LightningConfig.Bolt
	local Bolt = LightningBolt.new(
		{ WorldPosition = Start, WorldAxis = -Vector3.yAxis },
		{ WorldPosition = Finish, WorldAxis = -Vector3.yAxis },
		Segments
	)
	Bolt.Color = Config.Color
	Bolt.Thickness = Thickness
	Bolt.MinRadius = Config.JitterRadius * 0.25
	Bolt.MaxRadius = Config.JitterRadius
	-- Freeze both the shape and opacity for the entire brief flash.
	Bolt.AnimationSpeed = 0
	Bolt.MinTransparency = 0
	Bolt.MaxTransparency = 0
	Bolt.Frequency = 2
	Bolt.PulseSpeed = 1000
	-- Lifetime is owned by the strike model, including cancellation when its storm stops.
	Bolt.PulseLength = 1000000
	for _, Part: BasePart in Bolt.Parts do
		Part.CanTouch = false
		Part.CanQuery = false
		Part.Parent = Parent
	end

	return Bolt
end

local function ScheduleThunder(Position: Vector3, Parent: Instance)
	local Camera = workspace.CurrentCamera
	if not Camera then
		return
	end

	local Delay, Volume = LightningController.GetThunderAudio((Camera.CFrame.Position - Position).Magnitude)
	if Volume <= 0 then
		return
	end

	local Ids = LightningConfig.Thunder.SoundIds
	local Sound = Instance.new("Sound")
	Sound.Name = "StormThunder"
	Sound.SoundId = Ids[RandomGenerator:NextInteger(1, #Ids)]
	Sound.Volume = Volume
	Sound.Parent = Parent
	Sound.Ended:Once(function()
		Sound:Destroy()
	end)
	Debris:AddItem(Sound, Delay + LightningConfig.Thunder.MaximumLifetime)

	task.delay(Delay, function()
		if Sound.Parent then
			Sound:Play()
		end
	end)
end

-- One local strike, optionally owned by an active storm for coordinated cleanup.
function LightningController:Strike(Position: Vector3, Source: string?): Model?
	local Storm = if Source then Storms[Source] else nil
	if Source and (not Storm or Storm.Paused) then
		return nil
	end

	local Config = LightningConfig.Bolt
	local Start = Position + Vector3.new(
		RandomGenerator:NextNumber(-Config.CloudOffset, Config.CloudOffset),
		RandomGenerator:NextNumber(Config.MinimumHeight, Config.MaximumHeight),
		RandomGenerator:NextNumber(-Config.CloudOffset, Config.CloudOffset)
	)
	local Model = Instance.new("Model")
	Model.Name = "LightningStrike"
	Model:SetAttribute("StrikePosition", Position)
	Model.Parent = if Storm then Storm.Effects else GetEffectsFolder()
	local Bolts = { CreateBolt(Start, Position, Config.Segments, Config.Thickness, Model) }
	for _ = 1, Config.BranchCount do
		local BranchStart = Start:Lerp(Position, RandomGenerator:NextNumber(0.2, 0.65))
		local BranchEnd = BranchStart + Vector3.new(
			RandomGenerator:NextNumber(-Config.BranchLength, Config.BranchLength),
			-Config.BranchLength,
			RandomGenerator:NextNumber(-Config.BranchLength, Config.BranchLength)
		)
		table.insert(Bolts, CreateBolt(BranchStart, BranchEnd, Config.BranchSegments, Config.Thickness * 0.45, Model))
	end
	Model.Destroying:Once(function()
		for _, Bolt in Bolts do
			Bolt:Destroy()
		end
	end)
	Debris:AddItem(Model, Config.Lifetime)

	FlashSky()
	ScheduleThunder(Position, if Storm then Storm.Sounds else SoundService)
	return Model
end

local function ScheduleStrike(Source: string, Storm: Storm)
	local Config = LightningConfig.Storm
	local Minimum = math.max(0.1, Storm.Options.MinimumInterval or Config.MinimumInterval)
	local Maximum = math.max(Minimum, Storm.Options.MaximumInterval or Config.MaximumInterval)
	Storm.NextStrike = task.delay(RandomGenerator:NextNumber(Minimum, Maximum), function()
		Storm.NextStrike = nil
		if Storms[Source] ~= Storm then
			return
		end

		local Center = Storm.Center()
		if Center and not Storm.Paused then
			LightningController:Strike(LightningController.GetStrikePosition(Center, Storm.Options, RandomGenerator), Source)
		end
		if Storms[Source] == Storm then
			ScheduleStrike(Source, Storm)
		end
	end)
end

function LightningController:StartStorm(Source: string, Center: () -> Vector3?, Options: StormOptions?)
	if Storms[Source] then
		return
	end

	local Effects = Instance.new("Folder")
	Effects.Name = Source
	Effects.Parent = GetEffectsFolder()
	local Sounds = Instance.new("Folder")
	Sounds.Name = Source .. "Thunder"
	Sounds.Parent = SoundService
	local Storm: Storm = { Center = Center, Options = Options or {}, Effects = Effects, Sounds = Sounds }
	Storms[Source] = Storm
	ScheduleStrike(Source, Storm)
end

function LightningController:StopStorm(Source: string)
	local Storm = Storms[Source]
	if not Storm then
		return
	end

	Storms[Source] = nil
	if Storm.NextStrike then
		task.cancel(Storm.NextStrike)
	end
	Storm.Effects:Destroy()
	Storm.Sounds:Destroy()
	if next(Storms) == nil then
		RestoreFlash()
	end
end

function LightningController:SetStormPaused(Source: string, Paused: boolean)
	local Storm = Storms[Source]
	if Storm then
		Storm.Paused = Paused
	end
end

function LightningController.KnitStart()
	task.spawn(function()
		local Sounds: { Sound } = {}
		for _, SoundId in LightningConfig.Thunder.SoundIds do
			local Sound = Instance.new("Sound")
			Sound.SoundId = SoundId
			Sound.Volume = 0
			Sound.Parent = SoundService
			table.insert(Sounds, Sound)
		end

		local Success, Error = pcall(function()
			ContentProvider:PreloadAsync(Sounds)
		end)
		for _, Sound in Sounds do
			Sound:Destroy()
		end

		if not Success then
			warn("Unable to preload storm thunder:", Error)
		end
	end)
end

return LightningController
