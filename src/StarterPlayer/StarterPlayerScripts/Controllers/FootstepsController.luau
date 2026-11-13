local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local FootstepConfig = require(ReplicatedStorage.Shared.FootstepConfig)
local FootstepPlaybackController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.FootstepPlaybackController)

local FootstepsController = Knit.CreateController({ Name = "FootstepsController" })
type TrackState = { Connections: { RBXScriptConnection }, Order: number }
type MutedSound = { Volume: number, Connection: RBXScriptConnection }
type Record = {
	Character: Model,
	State: FootstepPlaybackController.State?,
	Animator: Animator?,
	AnimatorConnection: RBXScriptConnection?,
	Connections: { RBXScriptConnection },
	Tracks: { [AnimationTrack]: TrackState },
	Muted: { [Sound]: MutedSound },
	Order: number,
}

local Records: { [Model]: Record } = {}
local AnimationIds: { [string]: boolean } = {}
local CameraUpdaterController

local function IsLocomotionAnimation(Animation: Animation): boolean
	local Presets = ReplicatedStorage.Assets.Presets
	local Object: Instance? = Animation
	while Object and Object ~= Presets do
		if FootstepConfig.AnimationNames[string.lower(Object.Name)] then
			return true
		end
		Object = Object.Parent
	end

	return false
end

local function IndexAnimation(Object: Instance)
	if Object:IsA("Animation") and IsLocomotionAnimation(Object) then
		AnimationIds[Object.AnimationId:match("%d+") or Object.AnimationId] = true
	end
end

local function IsLocomotionTrack(Track: AnimationTrack): boolean
	local Animation = Track.Animation
	return Animation ~= nil and (FootstepConfig.AnimationNames[string.lower(Animation.Name)] == true
		or AnimationIds[Animation.AnimationId:match("%d+") or Animation.AnimationId] == true)
end

local function DisconnectTrack(Record: Record, Track: AnimationTrack)
	local Entry = Record.Tracks[Track]
	if Entry then
		Record.Tracks[Track] = nil
		for _, Connection in Entry.Connections do
			Connection:Disconnect()
		end
	end
end

local function IsDominantTrack(Record: Record, Track: AnimationTrack): boolean
	local Entry = Record.Tracks[Track]
	if not Entry or not Track.IsPlaying or Track.WeightCurrent < FootstepConfig.MinimumTrackWeight then
		return false
	end

	for Other, OtherEntry in Record.Tracks do
		if Other ~= Track and Other.IsPlaying
			and (Other.WeightCurrent > Track.WeightCurrent + 0.01
				or (math.abs(Other.WeightCurrent - Track.WeightCurrent) <= 0.01 and OtherEntry.Order > Entry.Order)) then
			return false
		end
	end

	return true
end

local function ConnectTrack(Record: Record, Track: AnimationTrack)
	if Record.Tracks[Track] or not IsLocomotionTrack(Track) then
		return
	end

	Record.Order += 1
	local Entry: TrackState = { Connections = {}, Order = Record.Order }
	Record.Tracks[Track] = Entry
	table.insert(Entry.Connections, Track:GetMarkerReachedSignal(FootstepConfig.Marker):Connect(function(Value: string)
		local Camera = workspace.CurrentCamera
		local State = Record.State
		if State and Camera and IsDominantTrack(Record, Track) then
			local Owner = Players:GetPlayerFromCharacter(Record.Character)
			local Movement = if Owner and CameraUpdaterController then CameraUpdaterController:GetMovement(Owner) else nil
			FootstepPlaybackController.Play(State, Camera.CFrame.Position, Value, os.clock(), Movement)
		end
	end))
	table.insert(Entry.Connections, Track.Stopped:Connect(function()
		-- A deferred Stopped event can arrive after the same track has been replayed.
		if not Track.IsPlaying then
			DisconnectTrack(Record, Track)
		end
	end))
	table.insert(Entry.Connections, Track.Destroying:Connect(function()
		DisconnectTrack(Record, Track)
	end))
end

local function RestoreRunningSounds(Record: Record)
	for Sound, Entry in Record.Muted do
		Entry.Connection:Disconnect()
		if Sound.Parent then
			Sound.Volume = Entry.Volume
		end
	end
	table.clear(Record.Muted)
end

local function MuteRunningSound(Record: Record, Object: Instance)
	local Root = Record.Character.PrimaryPart
	if not Object:IsA("Sound") or Object.Name ~= "Running" or Object.Parent ~= Root or Record.Muted[Object] then
		return
	end

	local Volume = Object.Volume
	Object.Volume = 0
	Record.Muted[Object] = {
		Volume = Volume,
		Connection = Object:GetPropertyChangedSignal("Volume"):Connect(function()
			if Object.Volume ~= 0 then
				Object.Volume = 0
			end
		end),
	}
end

local function Detach(Record: Record)
	if Record.AnimatorConnection then
		Record.AnimatorConnection:Disconnect()
		Record.AnimatorConnection = nil
	end
	for Track in Record.Tracks do
		DisconnectTrack(Record, Track)
	end
	if Record.State then
		FootstepPlaybackController.Destroy(Record.State)
		Record.State = nil
	end
	Record.Animator = nil
	RestoreRunningSounds(Record)
end

local function Attach(Record: Record)
	if Records[Record.Character] ~= Record then
		return
	end
	local Humanoid = Record.Character:FindFirstChildWhichIsA("Humanoid")
	local Animator = Humanoid and Humanoid:FindFirstChildWhichIsA("Animator")
	if not Record.State then
		Record.State = FootstepPlaybackController.Create(Record.Character)
	end
	local Root = Record.Character.PrimaryPart
	if Root then
		local Running = Root:FindFirstChild("Running")
		if Running then
			MuteRunningSound(Record, Running)
		end
	end
	if not Record.State or not Animator or Record.Animator == Animator then
		return
	end

	Record.Animator = Animator
	Record.AnimatorConnection = Animator.AnimationPlayed:Connect(function(Track: AnimationTrack)
		ConnectTrack(Record, Track)
	end)
	for _, Track in Animator:GetPlayingAnimationTracks() do
		ConnectTrack(Record, Track)
	end
end

function FootstepsController:UntrackCharacter(Character: Model)
	local Record = Records[Character]
	if not Record then
		return
	end

	Records[Character] = nil
	Detach(Record)
	for _, Connection in Record.Connections do
		Connection:Disconnect()
	end
end

function FootstepsController:TrackCharacter(Character: Model)
	if Records[Character] then
		return
	end

	local Record: Record = { Character = Character, Tracks = {}, Connections = {}, Muted = {}, Order = 0 }
	Records[Character] = Record
	table.insert(Record.Connections, Character.DescendantAdded:Connect(function(Object: Instance)
		MuteRunningSound(Record, Object)
		if Object:IsA("Humanoid") or Object:IsA("Animator") or Object:IsA("BasePart") then
			Attach(Record)
		end
	end))
	table.insert(Record.Connections, Character.DescendantRemoving:Connect(function(Object: Instance)
		local State = Record.State
		if State and (Object == State.Root or Object == State.Humanoid or Object == Record.Animator) then
			Detach(Record)
			task.defer(Attach, Record)
		end
	end))
	table.insert(Record.Connections, Character:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
		Detach(Record)
		Attach(Record)
	end))
	table.insert(Record.Connections, Character.Destroying:Connect(function()
		self:UntrackCharacter(Character)
	end))
	Attach(Record)
end

function FootstepsController.KnitStart()
	CameraUpdaterController = Knit.GetController("CameraUpdaterController")
	local Presets = ReplicatedStorage.Assets.Presets
	for _, Animation in Presets:QueryDescendants("Animation") do
		IndexAnimation(Animation)
	end
	Presets.DescendantAdded:Connect(IndexAnimation)
	task.spawn(FootstepPlaybackController.Preload)

	local function TrackPlayer(Player: Player)
		Player.CharacterAdded:Connect(function(Character: Model)
			FootstepsController:TrackCharacter(Character)
		end)
		Player.CharacterRemoving:Connect(function(Character: Model)
			FootstepsController:UntrackCharacter(Character)
		end)
		if Player.Character then
			FootstepsController:TrackCharacter(Player.Character)
		end
	end
	Players.PlayerAdded:Connect(TrackPlayer)
	Players.PlayerRemoving:Connect(function(Player: Player)
		if Player.Character then
			FootstepsController:UntrackCharacter(Player.Character)
		end
	end)
	for _, Player in Players:GetPlayers() do
		TrackPlayer(Player)
	end
end

return FootstepsController
