local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local FootstepConfig = require(ReplicatedStorage.Shared.FootstepConfig)

local FootstepPlaybackController = {}
local Randomizer = Random.new()
local Footprints: { BasePart } = {}
type Voice = { Sound: Sound, Owner: { Sound }?, LastUsed: number }
local AudioPools: { [string]: { Voice } } = {}
local VoiceEntries: { [Sound]: Voice } = {}
local Cache: Folder? = nil
local Preloaded = false

local function GetCache(): Folder
	if not Cache or not Cache.Parent then
		Cache = Instance.new("Folder")
		Cache.Name = "ClientFootstepCache"
		Cache.Parent = SoundService
	end

	return Cache
end

local function ReleaseVoice(Sound: Sound)
	local Entry = VoiceEntries[Sound]
	if not Entry then
		return
	end
	if Entry.Owner then
		local Index = table.find(Entry.Owner, Sound)
		if Index then
			table.remove(Entry.Owner, Index)
		end
		Entry.Owner = nil
	end

	if not Sound.Parent then
		VoiceEntries[Sound] = nil
		local Pool = AudioPools[Sound.SoundId]
		local Index = Pool and table.find(Pool, Entry)
		if Pool and Index then
			table.remove(Pool, Index)
		end
		return
	end

	Sound:Stop()
	Sound.Parent = GetCache()
end

local function CreateVoice(Id: string): Voice
	local Sound = Instance.new("Sound")
	Sound.Name = "FootstepVoice"
	Sound.SoundId = Id
	Sound.RollOffMode = Enum.RollOffMode.InverseTapered
	Sound.RollOffMinDistance = FootstepConfig.RollOffMinDistance
	Sound.RollOffMaxDistance = FootstepConfig.AudibleDistance
	Sound.Parent = GetCache()
	local Pitch = Instance.new("PitchShiftSoundEffect")
	Pitch.Parent = Sound
	local Entry: Voice = { Sound = Sound, LastUsed = -math.huge }
	VoiceEntries[Sound] = Entry
	Sound.Ended:Connect(function()
		if not Sound.IsPlaying then
			ReleaseVoice(Sound)
		end
	end)

	return Entry
end

function FootstepPlaybackController.Preload()
	if Preloaded then
		return
	end
	Preloaded = true
	local Assets: { Sound } = {}
	for _, Sounds in FootstepConfig.Sounds do
		for _, Id in Sounds do
			if not AudioPools[Id] then
				local Pool: { Voice } = {}
				AudioPools[Id] = Pool
				for _ = 1, FootstepConfig.PreloadedVoicesPerSound do
					local Entry = CreateVoice(Id)
					table.insert(Pool, Entry)
					table.insert(Assets, Entry.Sound)
				end
			end
		end
	end

	pcall(function()
		ContentProvider:PreloadAsync(Assets)
	end)
end

export type State = {
	Character: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Emitter: Attachment,
	Params: RaycastParams,
	SurfaceVoices: { Sound },
	ArmorVoices: { Sound },
	LastSurface: string?,
	LastArmor: string?,
	LastStep: number,
	NextFoot: number,
	SamplePosition: Vector3,
	SampleTime: number,
}

function FootstepPlaybackController.Create(Character: Model): State?
	local Root = Character.PrimaryPart
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if not Root or not Humanoid then
		return nil
	end

	local Emitter = Instance.new("Attachment")
	Emitter.Name = "ClientFootsteps"
	Emitter.Parent = Root
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.RespectCanCollide = true

	return {
		Character = Character, Root = Root, Humanoid = Humanoid, Emitter = Emitter, Params = Params,
		SurfaceVoices = {}, ArmorVoices = {}, LastStep = -math.huge, NextFoot = 1,
		SamplePosition = Root.Position, SampleTime = os.clock(),
	}
end

function FootstepPlaybackController.Destroy(State: State)
	for _, Voices in { State.SurfaceVoices, State.ArmorVoices } do
		for Index = #Voices, 1, -1 do
			ReleaseVoice(Voices[Index])
		end
	end
	State.Emitter:Destroy()
	table.clear(State.SurfaceVoices)
	table.clear(State.ArmorVoices)
end

function FootstepPlaybackController.PickSound(Assets: { string }, Previous: string?): string?
	if #Assets == 0 then
		return nil
	end
	local PreviousIndex = if Previous then table.find(Assets, Previous) else nil
	local Index = Randomizer:NextInteger(1, if PreviousIndex and #Assets > 1 then #Assets - 1 else #Assets)
	if PreviousIndex and #Assets > 1 and Index >= PreviousIndex then
		Index += 1
	end

	return Assets[Index]
end

function FootstepPlaybackController.CanStep(State: State, Listener: Vector3, Now: number): boolean
	local Character = State.Character
	if not Character:IsDescendantOf(workspace) or State.Root ~= Character.PrimaryPart or State.Root.Anchored
		or State.Humanoid.Health <= 0 or State.Humanoid.Sit or State.Humanoid.PlatformStand
		or (State.Root.Position - Listener).Magnitude > FootstepConfig.AudibleDistance
		or Now - State.LastStep < FootstepConfig.MinimumStepInterval then
		return false
	end

	for _, Attribute in FootstepConfig.BlockedAttributes do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end

	local HumanoidState = State.Humanoid:GetState()
	return HumanoidState ~= Enum.HumanoidStateType.Jumping and HumanoidState ~= Enum.HumanoidStateType.Freefall
		and HumanoidState ~= Enum.HumanoidStateType.Swimming and HumanoidState ~= Enum.HumanoidStateType.Climbing
end

local function GetFoot(Character: Model, Name: string, Fallback: string): BasePart?
	local Part = Character:FindFirstChild(Name) or Character:FindFirstChild(Fallback)

	return if Part and Part:IsA("BasePart") then Part else nil
end

local function GetGround(State: State, MarkerValue: string): RaycastResult?
	local Left = GetFoot(State.Character, "LeftFoot", "Left Leg")
	local Right = GetFoot(State.Character, "RightFoot", "Right Leg")
	local Foot: BasePart? = nil
	local Value = string.lower(MarkerValue)
	if Value == "l" or string.find(Value, "left", 1, true) then
		Foot = Left
	elseif Value == "r" or string.find(Value, "right", 1, true) then
		Foot = Right
	elseif Left and Right then
		local LeftBottom = (Left.CFrame * CFrame.new(0, -Left.Size.Y * 0.5, 0)).Position
		local RightBottom = (Right.CFrame * CFrame.new(0, -Right.Size.Y * 0.5, 0)).Position
		Foot = if math.abs(LeftBottom.Y - RightBottom.Y) > 0.05
			then (if LeftBottom.Y < RightBottom.Y then Left else Right) else (if State.NextFoot == 1 then Left else Right)
	else
		Foot = Left or Right
	end
	if not Foot then
		return nil
	end

	local Filter: { Instance } = { State.Character }
	for _, Name in { "Entity", "NPCs", "VFX" } do
		local Container = workspace:FindFirstChild(Name)
		if Container then
			table.insert(Filter, Container)
		end
	end
	State.Params.FilterDescendantsInstances = Filter
	local Bottom = (Foot.CFrame * CFrame.new(0, -Foot.Size.Y * 0.5, 0)).Position
	local Origin = Bottom + Vector3.yAxis * FootstepConfig.ProbeHeight
	local Hit = workspace:Raycast(Origin, -Vector3.yAxis * (FootstepConfig.ProbeHeight + FootstepConfig.ProbeDepth), State.Params)
	if Hit then
		return Hit
	end

	-- Marker events can precede the frame's animated foot position; use physical support as a fallback.
	local LegHeight = if State.Humanoid.RigType == Enum.HumanoidRigType.R6 then Foot.Size.Y else 0
	local Depth = State.Root.Size.Y * 0.5 + State.Humanoid.HipHeight + LegHeight + FootstepConfig.ProbeDepth
	return workspace:Raycast(State.Root.Position, -Vector3.yAxis * Depth, State.Params)
end

local function GetVoice(State: State, Voices: { Sound }, Id: string): Sound?
	local Pool = AudioPools[Id]
	if not Pool then
		return nil
	end
	for Index = #Pool, 1, -1 do
		if not Pool[Index].Sound.Parent then
			ReleaseVoice(Pool[Index].Sound)
		end
	end
	local Candidate: Voice? = nil
	for _, Entry in Pool do
		if Entry.Sound.IsLoaded then
			if not Entry.Sound.IsPlaying then
				Candidate = Entry
				break
			elseif not Candidate or Entry.LastUsed < Candidate.LastUsed then
				Candidate = Entry
			end
		end
	end
	if (not Candidate or Candidate.Sound.IsPlaying) and #Pool < FootstepConfig.MaximumVoicesPerSound then
		local Extra = CreateVoice(Id)
		table.insert(Pool, Extra)
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ Extra.Sound })
			end)
		end)
	end
	if not Candidate then
		return nil
	end

	ReleaseVoice(Candidate.Sound)
	if #Voices >= FootstepConfig.VoicesPerLayer then
		ReleaseVoice(Voices[1])
	end
	Candidate.Owner, Candidate.LastUsed = Voices, os.clock()
	Candidate.Sound.Parent = State.Emitter
	table.insert(Voices, Candidate.Sound)
	return Candidate.Sound
end

local function PlaySound(State: State, Voices: { Sound }, Id: string, Volume: number): boolean
	local Sound = GetVoice(State, Voices, Id)
	if not Sound then
		return false
	end

	Sound.Volume = Volume
	Sound.PlaybackSpeed = 1
	local Pitch = Sound:FindFirstChildWhichIsA("PitchShiftSoundEffect")
	if Pitch then
		Pitch.Octave = Randomizer:NextNumber(FootstepConfig.MinimumPitch, FootstepConfig.MaximumPitch)
	end
	Sound.TimePosition = 0
	Sound:Play()
	return true
end

local function AddFootprint(State: State, Hit: RaycastResult)
	if not FootstepConfig.FootprintMaterials[Hit.Material] then
		return
	end
	local Template = ReplicatedStorage.Assets.Models:FindFirstChild("Footstep")
	if not Template or not Template:IsA("BasePart") then
		return
	end

	local Forward = State.Root.CFrame.LookVector
	Forward -= Hit.Normal * Forward:Dot(Hit.Normal)
	if Forward.Magnitude < 0.001 then
		return
	end
	local Position = Hit.Position + Hit.Normal * 0.02
	local Footprint = Template:Clone()
	Footprint.CFrame = CFrame.lookAt(Position, Position + Forward, Hit.Normal)
	Footprint.Anchored = true
	Footprint.CanCollide, Footprint.CanTouch, Footprint.CanQuery = false, false, false
	Footprint.Parent = workspace:FindFirstChild("VFX") or workspace
	Debris:AddItem(Footprint, FootstepConfig.FootprintLifetime)
	table.insert(Footprints, Footprint)
	if #Footprints > FootstepConfig.MaximumFootprints then
		table.remove(Footprints, 1):Destroy()
	end
end

function FootstepPlaybackController.Play(State: State, Listener: Vector3, MarkerValue: string, Now: number, Movement: Vector3?): boolean
	if not FootstepPlaybackController.CanStep(State, Listener, Now) then
		return false
	end
	local Hit = GetGround(State, MarkerValue)
	if not Hit then
		return false
	end

	local GroundVelocity = if Hit.Instance:IsA("BasePart") then Hit.Instance:GetVelocityAtPosition(State.Root.Position) else Vector3.zero
	local RootVelocity = State.Root.AssemblyLinearVelocity
	local Elapsed = Now - State.SampleTime
	if Elapsed > 0.001 and Elapsed <= 1 and (RootVelocity * Vector3.new(1, 0, 1)).Magnitude < FootstepConfig.MinimumSpeed then
		-- Remote physics can report zero velocity between updates while the rendered root still moves.
		RootVelocity = (State.Root.Position - State.SamplePosition) / Elapsed
	end
	State.SamplePosition, State.SampleTime = State.Root.Position, Now
	local Velocity = (RootVelocity - GroundVelocity) * Vector3.new(1, 0, 1)
	local LocalPlayer = Players.LocalPlayer
	local Intent = if LocalPlayer and LocalPlayer.Character == State.Character then State.Humanoid.MoveDirection else Movement
	local Moving = if Intent then Intent.Magnitude > 0 else Velocity.Magnitude >= FootstepConfig.MinimumSpeed
	if not Moving then
		return false
	end
	local Assets = FootstepConfig.GetSounds(Hit.Material)
	local Id = Assets and FootstepPlaybackController.PickSound(Assets, State.LastSurface)
	if not Id then
		return false
	end

	State.LastStep, State.LastSurface = Now, Id
	State.NextFoot = if State.NextFoot == 1 then 2 else 1
	local Played = PlaySound(State, State.SurfaceVoices, Id, FootstepConfig.GetVolume(Hit.Material))
	if State.Character:GetAttribute("HasMetalArmor") then
		local Armor = FootstepPlaybackController.PickSound(FootstepConfig.Sounds.MetalArmor, State.LastArmor)
		if Armor then
			State.LastArmor = Armor
			PlaySound(State, State.ArmorVoices, Armor, FootstepConfig.ArmorVolume)
		end
	end
	AddFootprint(State, Hit)
	return Played
end

return FootstepPlaybackController
