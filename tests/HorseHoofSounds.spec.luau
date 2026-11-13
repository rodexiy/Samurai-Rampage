return function(Animator: any, Audio: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Settings = Config.HoofSounds
	local OriginalSoft = Settings.Soft
	local OriginalHard = Settings.Hard
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseHoofSoundTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Origin = Vector3.new(0, 19200, 0)
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(100, 2, 1500)
	Floor.Position = Origin + Vector3.new(-50, -1, -500)
	Floor.Material = Enum.Material.Grass
	Floor.Parent = Fixture
	local Right = Floor:Clone()
	Right.Position = Origin + Vector3.new(50, -1, -500)
	Right.Material = Enum.Material.Wood
	Right.Parent = Fixture
	local Root = Instance.new("Part")
	Root.Anchored = true
	Root.CanCollide = false
	Root.CFrame = CFrame.new(Origin + Vector3.new(-2, 5, 0))
	Root.Parent = Fixture
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Root, Targets }
	Params.RespectCanCollide = true
	local State = Audio.Create(Root, "Test")
	local Active: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Contact(Material: Enum.Material): any
		Floor.Material = Material

		return {
			InSwing = false, Grounded = true, Cycle = 0, SolverEnabled = true,
			GroundHit = workspace:Raycast(Root.Position, -Vector3.yAxis * 10, Params),
			Rest = CFrame.new(0, -5, 0),
		}
	end
	local function Land(Foot: any)
		Foot.InSwing = true
		Audio.Update(State, Foot, Root, Params, 24, 0.5, 0.15)
		Foot.InSwing = false
		Audio.Update(State, Foot, Root, Params, 24, 0.5, 0.15)
	end
	local function FinishSounds(VoiceState: any)
		-- Deterministic animation playback advances faster than the audio engine's wall clock.
		for _, Sound in VoiceState.Sounds do
			Sound:Stop()
		end
	end

	local Success, Error = pcall(function()
		local Foot = Contact(Enum.Material.Grass)
		Audio.Update(State, Foot, Root, Params, 0, 0, 0.1)
		Check(#State.Sounds == 0, "Creating or standing a horse must not play an impact")
		for _, Material in {
			Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Snow, Enum.Material.Sand,
			Enum.Material.Mud, Enum.Material.Ground, Enum.Material.Wood, Enum.Material.WoodPlanks,
			Enum.Material.Concrete, Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Metal,
		} do
			Foot = Contact(Material)
			Land(Foot)
			local Assets = if Settings.SoftEnabled and Settings.SoftMaterials[Material] then Settings.Soft else Settings.Hard
			Check(table.find(Assets, State.LastSoundId) ~= nil, "Each material must select the supplied surface sounds: " .. Material.Name)
			Check(State.Emitter.Parent == Root and (State.Emitter.WorldPosition - Root.Position).Magnitude < 0.01,
				"Audio must emit from the horse instead of the ground contact")
			Land(Foot)
			Check(State.LastStep == State.Elapsed, "Every touchdown must play even when the sample repeats")
			local Time = State.LastStep
			for _ = 1, 15 do
				Audio.Update(State, Foot, Root, Params, 24, 0.5, 1 / 60)
			end
			Check(State.LastStep == Time, "Holding support must never replay the impact")
			FinishSounds(State)
		end
		Check(#State.Sounds <= 2, "Finished voices must be reused during ordinary playback")
		for _, Sound in State.Sounds do
			Check(Sound.Parent:IsA("Attachment") and Sound.Parent.Parent == State.Emitter.Parent and not Sound.Looped,
				"Each playing voice must have its own positional emitter")
			Check(Sound.PlaybackSpeed == 1, "The original pitch and playback duration must be preserved")
			Check(Sound.RollOffMaxDistance == Settings.RollOffMaxDistance, "Distant hoof sounds must attenuate")
		end
		Foot.Grounded = false
		local LastStep = State.LastStep
		Land(Foot)
		Check(State.LastStep == LastStep, "Missing ground cannot produce hoof impacts")
		Audio.Reset(State)
		Check(State.PreviousCycle == nil and not State.WasSwing, "Culling and teleports must clear pending contacts")
		Foot.SolverEnabled = false
		Foot.Cycle = 0.9
		Audio.Update(State, Foot, Root, Params, 24, 0, 0.2)
		Foot.Cycle = 0.1
		Audio.Update(State, Foot, Root, Params, 24, 0, 0.2)
		Check(State.LastStep == State.Elapsed, "Offscreen/distant horses must use gait touchdown without requiring IK")
		Floor.CanCollide = false
		LastStep = State.LastStep
		Foot.Cycle = 0.9
		Audio.Update(State, Foot, Root, Params, 24, 0, 0.2)
		Foot.Cycle = 0.1
		Audio.Update(State, Foot, Root, Params, 24, 0, 0.2)
		Check(State.LastStep == LastStep, "Distant hooves must stay silent over a missing floor")
		Floor.CanCollide = true
		Floor.Material = Enum.Material.Grass
		FinishSounds(State)

		local Overlap = Audio.Create(Root, "Overlap")
		local First: Sound? = nil
		local FirstAsset: string? = nil
		local FirstPosition = Vector3.zero
		Settings.Soft = { OriginalSoft[1] }
		Settings.Hard = { OriginalSoft[1] }
		for Index = 1, 12 do
			local Impact = Contact(Enum.Material.Grass)
			Impact.GroundHit = workspace:Raycast(Root.Position + Vector3.xAxis * Index * 0.05, -Vector3.yAxis * 10, Params)
			Impact.InSwing = true
			Audio.Update(Overlap, Impact, Root, Params, 80, 1, 0.15)
			Impact.InSwing = false
			Audio.Update(Overlap, Impact, Root, Params, 80, 1, 0.15)
			if not First then
				First = Overlap.Sounds[1]
				FirstAsset = First.SoundId
				FirstPosition = (First.Parent :: Attachment).WorldPosition
			end
			Check(First.Playing and First.SoundId == FirstAsset,
				"A rapid step must never stop or replace an unfinished impact")
			Check(Overlap.LastSoundId == OriginalSoft[1] and #Overlap.Sounds == Index,
				"The same sample must overlap on separate voices without losing a step")
			Check(((First.Parent :: Attachment).WorldPosition - FirstPosition).Magnitude < 0.001,
				"Starting another impact must not teleport a playing sound emitter")
		end
		Check(#Overlap.Sounds == 12, "Overlapping impacts must grow beyond the old eight-voice limit")
		local Time = Overlap.LastStep
		local Impact = Contact(Enum.Material.Grass)
		Impact.InSwing = true
		Audio.Update(Overlap, Impact, Root, Params, 80, 1, 0.15)
		Impact.InSwing = false
		Audio.Update(Overlap, Impact, Root, Params, 80, 1, 0.15)
		Check(#Overlap.Sounds == 13 and Overlap.LastStep > Time and First.Playing,
			"A busy pool must play another impact without discarding it or interrupting existing audio")
		local BeforeMove = Root.CFrame
		Root.CFrame += Vector3.new(4, 1, 3)
		Check(((First.Parent :: Attachment).WorldPosition - Root.Position).Magnitude < 0.001 and First.Playing,
			"An already playing voice must follow the horse without restarting")
		Root.CFrame = BeforeMove
		Audio.Reset(Overlap)
		Check(First.Playing, "Changing animation quality must let the existing audio finish")
		FinishSounds(Overlap)
		Impact.InSwing = true
		Audio.Update(Overlap, Impact, Root, Params, 24, 0, 0.15)
		Impact.InSwing = false
		Audio.Update(Overlap, Impact, Root, Params, 24, 0, 0.15)
		Check(#Overlap.Sounds == 13 and Overlap.Sounds[1] == First and First.Playing,
			"An idle sound must be reused for the next step")
		FinishSounds(Overlap)
		Settings.Soft = OriginalSoft
		Settings.Hard = OriginalHard

		for _, Tier in { 1, 5 } do
			local Horse = (ReplicatedStorage.Assets.Models.Horses:FindFirstChild("Horse" .. Tier) :: Model):Clone()
			for _, Part in Horse:QueryDescendants("BasePart") :: { BasePart } do
				Part.Anchored = true
				Part.CanCollide = false
			end
			local Bounds, Size = Horse:GetBoundingBox()
			local Height = math.abs(Bounds.RightVector.Y) * Size.X + math.abs(Bounds.UpVector.Y) * Size.Y
				+ math.abs(Bounds.LookVector.Y) * Size.Z
			local HorseRoot = Root:Clone()
			HorseRoot:ClearAllChildren()
			HorseRoot.CFrame = CFrame.new(Bounds.Position)
			HorseRoot.Parent = Horse
			Horse.PrimaryPart = HorseRoot
			Horse:SetAttribute("HorseTier", Tier)
			Horse:PivotTo(CFrame.new(Origin + Vector3.yAxis * Height * 0.5))
			Horse.Parent = Fixture
			Active = Animator.Create(Horse, Targets)
			for _, Speed in { Config.GetTier(Tier).Speed * Config.Gaits.TrotMultiplier, Config.GetTier(Tier).Speed } do
				local Steps = { 0, 0, 0, 0 }
				for _ = 1, 240 do
					local Before = {}
					for Index, Leg in Active.Feet do
						FinishSounds(Leg.Sound)
						Before[Index] = { Time = Leg.Sound.LastStep, Swing = Leg.InSwing }
					end
					Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * Speed / 60)
					Animator.Update(Active, 1 / 60, 0, 2, true)
					for Index, Leg in Active.Feet do
						if Leg.Sound.LastStep ~= Before[Index].Time then
							Steps[Index] += 1
							Check(Before[Index].Swing and not Leg.InSwing and Leg.Grounded, "Real-rig audio must coincide with that hoof's touchdown")
							Check(Leg.Sound.Emitter.Parent == HorseRoot and (Leg.Sound.Emitter.WorldPosition - HorseRoot.Position).Magnitude < 0.01,
								"Every hoof voice must follow the moving horse's root")
							local Assets = if Settings.SoftEnabled and (Index == 1 or Index == 3) then Settings.Soft else Settings.Hard
							Check(table.find(Assets, Leg.Sound.LastSoundId) ~= nil, "Each real hoof must query its own surface")
						end
					end
				end
				for Index = 1, 4 do
					Check(Steps[Index] > 3, "All four hooves must make independent steps in each gait")
				end
			end
			local Emitter = Active.Feet[1].Sound.Emitter
			Animator.Destroy(Active)
			Active = nil
			Check(Emitter.Parent == nil, "Removing a horse must remove its emitters and sound pool")
			Horse:Destroy()
		end
	end)
	Settings.Soft = OriginalSoft
	Settings.Hard = OriginalHard

	if Active then
		Animator.Destroy(Active)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseHoofSounds: %d checks passed", Checks)
end
