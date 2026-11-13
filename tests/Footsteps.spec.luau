return function(Config: any, Playback: any): string
	Playback.Preload()
	task.wait(0.1)

	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	Check(Playback.PickSound({}, nil) == nil, "Empty libraries do not loop")
	Check(Playback.PickSound({ "one" }, "one") == "one", "Single-sample libraries remain playable")
	for _ = 1, 20 do
		Check(Playback.PickSound({ "one", "two", "three" }, "two") ~= "two", "Avoid consecutive repeats without waiting")
	end
	Check(Config.GetSounds(Enum.Material.Air) == nil and Config.GetSounds(Enum.Material.Water) == nil, "Unsupported air/water contacts stay silent")
	Check(Config.GetSounds(Enum.Material.LeafyGrass) == Config.GetSounds(Enum.Material.Grass), "Retain grass aliases")

	local Fixture = Instance.new("Folder")
	Fixture.Name = "FootstepTests"
	Fixture.Parent = workspace
	local Floor = Instance.new("Part")
	Floor.Size = Vector3.new(40, 2, 40)
	Floor.Position = Vector3.new(0, 24999, 0)
	Floor.Anchored = true
	Floor.Parent = Fixture
	local Character = Instance.new("Model")
	Character.Parent = Fixture
	local function Part(Name: string, Position: Vector3, Size: Vector3): Part
		local Object = Instance.new("Part")
		Object.Name, Object.Position, Object.Size = Name, Position, Size
		Object.CanCollide = false
		Object.Parent = Character

		return Object
	end

	local Root = Part("HumanoidRootPart", Vector3.new(0, 25003, 0), Vector3.new(2, 2, 1))
	Character.PrimaryPart = Root
	local Left = Part("Left Leg", Vector3.new(-0.5, 25001, 0), Vector3.new(1, 2, 1))
	local Right = Part("Right Leg", Vector3.new(0.5, 25001, 0), Vector3.new(1, 2, 1))
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Parent = Character
	Humanoid:ChangeState(Enum.HumanoidStateType.Running)
	local State = assert(Playback.Create(Character))
	local Listener = Root.Position
	local Created: { Instance } = {}

	local Success, Error = pcall(function()
		Root.AssemblyLinearVelocity = Vector3.new(8, 0, 0)
		for Index, Material in { Enum.Material.Grass, Enum.Material.Wood, Enum.Material.Metal, Enum.Material.Concrete } do
			Floor.Material = Material
			Check(Playback.Play(State, Listener, "Left", Index), "Ground ray selects " .. Material.Name)
			Check(table.find(Config.GetSounds(Material), State.LastSurface) ~= nil, "Use the correct surface library")
			Check(State.SurfaceVoices[1].Parent == State.Emitter and State.Emitter.Parent == Root, "Audio is spatial and follows the character")
			Check(State.SurfaceVoices[1].RollOffMaxDistance == 60, "Footsteps attenuate within the configured radius")
		end
		Check(not Playback.Play(State, Listener, "Right", State.LastStep + 0.01), "Blend markers cannot duplicate one step")
		Check(Playback.Play(State, Listener, "Right", State.LastStep + 0.08), "Fast animation markers retain their cadence")
		local Now = 10
		Check(not Playback.Play(State, Listener + Vector3.new(60.01, 0, 0), "Right", Now), "Distant markers do not create audio")
		Check(Playback.CanStep(State, Listener + Vector3.new(60, 0, 0), Now), "The range boundary is included")
		Root.AssemblyLinearVelocity = Vector3.zero
		Check(not Playback.Play(State, Listener, "Right", Now), "Stopped characters do not play footsteps")
		Check(Playback.Play(State, Listener, "Right", Now, Vector3.xAxis), "Replicated movement preserves remote markers during zero-velocity physics updates")
		Now += 0.5
		Root.AssemblyLinearVelocity = Vector3.new(8, 0, 0)
		Check(not Playback.Play(State, Listener, "Right", Now, Vector3.zero), "Replicated stop input suppresses footsteps even with residual velocity")
		Root.AssemblyLinearVelocity = Vector3.zero
		Playback.Play(State, Listener, "Right", Now)
		Character:PivotTo(Character:GetPivot() + Vector3.xAxis * 0.5)
		Now += 0.5
		Check(Playback.Play(State, Listener, "Right", Now), "Rendered displacement supports remote roots between velocity updates")
		Now += 1
		Root.AssemblyLinearVelocity = Vector3.new(8, 0, 0)
		for _, Attribute in Config.BlockedAttributes do
			Character:SetAttribute(Attribute, true)
			Check(not Playback.Play(State, Listener, "Right", Now), Attribute .. " suppresses footsteps")
			Character:SetAttribute(Attribute, nil)
		end
		Root.Anchored = true
		Check(not Playback.CanStep(State, Listener, Now), "Anchored characters remain silent")
		Root.Anchored = false
		Root.AssemblyLinearVelocity = Vector3.new(8, 0, 0)
		Left.Position += Vector3.yAxis * 5
		Right.Position += Vector3.yAxis * 5
		Check(Playback.Play(State, Listener, "Left", Now), "Grounded animation markers survive a stale animated foot pose")
		Now += 1
		Root.Position += Vector3.yAxis * 5
		Check(not Playback.Play(State, Listener, "Left", Now), "Missing ground contact suppresses airborne steps")
		Root.Position -= Vector3.yAxis * 5
		Left.Position -= Vector3.yAxis * 5
		Right.Position -= Vector3.yAxis * 5
		Character:SetAttribute("HasMetalArmor", true)
		Floor.Material = Enum.Material.Concrete
		Check(Playback.Play(State, Listener, "Right", Now), "Armored characters still play surface footsteps")
		Check(#State.ArmorVoices > 0 and table.find(Config.Sounds.MetalArmor, State.LastArmor) ~= nil, "Armor has its own audio layer")
		local AssignedIds: { [Sound]: string } = {}
		for Index = 1, 20 do
			Playback.Play(State, Listener, "", Now + Index)
			for _, Voices in { State.SurfaceVoices, State.ArmorVoices } do
				for _, Voice in Voices do
					Check(AssignedIds[Voice] == nil or AssignedIds[Voice] == Voice.SoundId,
						"Reused voices keep the loaded asset instead of swapping SoundId at the marker")
					AssignedIds[Voice] = Voice.SoundId
				end
			end
		end
		Check(#State.SurfaceVoices <= Config.VoicesPerLayer and #State.ArmorVoices <= Config.VoicesPerLayer, "Sound counts stay bounded")
		for _, Voice in State.SurfaceVoices do
			Check(Voice.PlaybackSpeed == 1, "Pitch variation cannot change footstep duration")
			local Pitch = Voice:FindFirstChildWhichIsA("PitchShiftSoundEffect")
			Check(Pitch ~= nil and Pitch.Octave >= Config.MinimumPitch and Pitch.Octave <= Config.MaximumPitch, "Pitch variation is retained")
			Check(Voice.IsLoaded, "Only loaded samples play at the animation marker")
		end

		Floor.Material = Enum.Material.Snow
		local Parent = workspace:FindFirstChild("VFX") or workspace
		local Before: { [Instance]: boolean } = {}
		for _, Child in Parent:GetChildren() do
			Before[Child] = true
		end
		Check(Playback.Play(State, Listener, "Left", Now + 30), "Snow generates a footstep")
		for _, Child in Parent:GetChildren() do
			if not Before[Child] and Child.Name == "Footstep" then
				table.insert(Created, Child)
			end
		end
		Check(#Created == 1, "Each step generates one footprint")
		Check(not (Created[1] :: BasePart).CanQuery and not (Created[1] :: BasePart).CanCollide, "Footprints cannot interfere with ground queries")
		Floor.Material = Enum.Material.Concrete
		local Streamed = assert(Playback.Create(Character))
		Check(Playback.Play(Streamed, Listener, "Left", Now + 40), "Another character state shares the preloaded audio cache")
		Streamed.Emitter:Destroy()
		local Released = pcall(function()
			Playback.Destroy(Streamed)
		end)
		Check(Released, "Already-destroyed streamed voices are released without reparenting destroyed instances")
	end)

	Playback.Destroy(State)
	for _, Object in Created do
		Object:Destroy()
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("Footsteps: %d checks passed", Checks)
end
