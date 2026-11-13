local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local Settings = HorseConfig.HoofSounds
local HorseHoofSoundController = {}
local Randomizer = Random.new()

export type State = {
	Emitter: Attachment,
	Sounds: { Sound },
	LastSoundId: string?,
	PreviousCycle: number?,
	WasSwing: boolean,
	Elapsed: number,
	LastStep: number,
}
type Contact = {
	InSwing: boolean, Grounded: boolean, Cycle: number, SolverEnabled: boolean,
	GroundHit: RaycastResult?, Rest: CFrame,
}

function HorseHoofSoundController.Preload()
	local Assets = table.clone(Settings.Hard)
	if Settings.SoftEnabled then
		for _, Asset in Settings.Soft do
			table.insert(Assets, Asset)
		end
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(Assets)
		end)
	end)
end

function HorseHoofSoundController.Create(Parent: BasePart, Name: string): State
	local Emitter = Instance.new("Attachment")
	Emitter.Name = Name .. "HoofSound"
	Emitter.Parent = Parent

	return {
		Emitter = Emitter, Sounds = {}, LastSoundId = nil,
		PreviousCycle = nil, WasSwing = false, Elapsed = 0, LastStep = -math.huge,
	}
end

function HorseHoofSoundController.Reset(State: State)
	State.PreviousCycle = nil
	State.WasSwing = false
	State.LastStep = -math.huge
end

function HorseHoofSoundController.Destroy(State: State)
	for _, Sound in State.Sounds do
		local Emitter = Sound.Parent
		if Emitter then
			Emitter:Destroy()
		end
	end
	table.clear(State.Sounds)
	State.Emitter:Destroy()
end

local function GetSound(State: State): Sound
	for _, Sound in State.Sounds do
		if not Sound.Playing then
			return Sound
		end
	end
	local Emitter = Instance.new("Attachment")
	Emitter.Name = State.Emitter.Name .. "Voice" .. (#State.Sounds + 1)
	Emitter.Parent = State.Emitter.Parent
	local Sound = Instance.new("Sound")
	Sound.Name = "HorseHoofImpact"
	Sound.RollOffMode = Enum.RollOffMode.InverseTapered
	Sound.RollOffMinDistance = Settings.RollOffMinDistance
	Sound.RollOffMaxDistance = Settings.RollOffMaxDistance
	Sound.Parent = Emitter
	table.insert(State.Sounds, Sound)
	Sound.Ended:Connect(function()
		-- Trim only finished, unused voices; a queued Ended event may arrive after a voice was reused.
		if Sound.Playing or #State.Sounds <= Settings.RetainedVoicesPerHoof then
			return
		end
		local Index = table.find(State.Sounds, Sound)
		if Index then
			table.remove(State.Sounds, Index)
			Emitter:Destroy()
		end
	end)

	return Sound
end

local function Play(State: State, Hit: RaycastResult, Speed: number, Sprint: number)
	if Hit.Material == Enum.Material.Water or Hit.Material == Enum.Material.Air then
		return
	end
	local Sound = GetSound(State)
	local Assets = if Settings.SoftEnabled and Settings.SoftMaterials[Hit.Material] then Settings.Soft else Settings.Hard
	local Asset = Assets[Randomizer:NextInteger(1, #Assets)]
	State.LastSoundId = Asset
	State.LastStep = State.Elapsed
	-- Voices remain attached to the horse's root and follow it throughout playback.
	Sound.SoundId = Asset
	Sound.PlaybackSpeed = 1
	Sound.Volume = (Settings.Volume + (Settings.RunningVolume - Settings.Volume) * math.clamp(Sprint, 0, 1))
		* (0.7 + 0.3 * math.clamp(Speed / 24, 0, 1))
	Sound:Play()
end

function HorseHoofSoundController.Update(State: State, Foot: Contact, Root: BasePart, Params: RaycastParams,
	Speed: number, Sprint: number, DeltaTime: number)
	State.Elapsed += DeltaTime
	local Landed = if Foot.SolverEnabled then State.WasSwing and not Foot.InSwing and Foot.Grounded
		else State.PreviousCycle ~= nil and Foot.Cycle < State.PreviousCycle and Speed > HorseConfig.Animation.MoveThreshold
	State.PreviousCycle = Foot.Cycle
	State.WasSwing = Foot.InSwing
	if not Landed or State.Elapsed - State.LastStep < Settings.MinimumInterval then
		return
	end

	local Hit = Foot.GroundHit
	if not Foot.SolverEnabled then
		-- Distant/offscreen rigs skip IK; query the material only when a hoof's gait reaches touchdown.
		local Rest = Root.CFrame:PointToWorldSpace(Foot.Rest.Position)
		local Height, Depth = HorseConfig.Animation.ProbeHeight, HorseConfig.Animation.ProbeDepth
		Hit = workspace:Raycast(Rest + Vector3.yAxis * Height, -Vector3.yAxis * (Height + Depth), Params)
	end
	if Hit and Hit.Instance:IsDescendantOf(workspace)
		and Hit.Normal.Y >= math.cos(HorseConfig.Grounding.MaximumSupportSlope) then
		Play(State, Hit, Speed, Sprint)
	end
end

return HorseHoofSoundController
