local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CameraReplication = require(ReplicatedStorage.Shared.CameraReplication)
local TiltController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.TiltController)
local CharacterLookController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.CharacterLookController)

local CameraUpdaterController = Knit.CreateController({ Name = "CameraUpdaterController" })
local LocalPlayer = Players.LocalPlayer
local CameraEvent: UnreliableRemoteEvent

type Record = {
	Character: Model,
	Tilt: TiltController.State?,
	Look: CharacterLookController.State?,
	Connections: { RBXScriptConnection },
	Target: CameraReplication.Frame?,
	Camera: CFrame?,
	Received: number,
	ServerTime: number,
	Rendering: boolean,
}

local Records: { [Player]: Record } = {}
local LastSent: CameraReplication.Frame? = nil
local LastSentAt = -math.huge
local SendElapsed = 0

local function ResetRecord(Record: Record)
	if Record.Tilt then
		TiltController.Reset(Record.Tilt)
	end
	if Record.Look then
		CharacterLookController.Reset(Record.Look)
	end

	Record.Rendering = false
end

local function BuildStates(Record: Record)
	if not Record.Tilt then
		Record.Tilt = TiltController.Create(Record.Character)
	end
	if not Record.Look then
		Record.Look = CharacterLookController.Create(Record.Character)
	end
end

local function RemoveCharacter(Player: Player)
	local Record = Records[Player]
	if not Record then
		return
	end

	ResetRecord(Record)
	-- CharacterRemoving/streaming can leave the old character instance alive.
	for _, Connection in Record.Connections do
		Connection:Disconnect()
	end
	Records[Player] = nil
end

local function TrackCharacter(Player: Player, Character: Model)
	RemoveCharacter(Player)
	local Record: Record = {
		Character = Character, Connections = {}, Received = -math.huge,
		ServerTime = -math.huge, Rendering = false,
	}
	Records[Player] = Record

	table.insert(Record.Connections, Character.DescendantAdded:Connect(function()
		BuildStates(Record)
	end))
	table.insert(Record.Connections, Character.DescendantRemoving:Connect(function(Object: Instance)
		if Object:IsA("Motor6D") or Object == Character.PrimaryPart or Object:IsA("Humanoid") then
			ResetRecord(Record)
			Record.Tilt, Record.Look = nil, nil
		end
	end))
	table.insert(Record.Connections, Character:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
		ResetRecord(Record)
		Record.Tilt, Record.Look = nil, nil
		BuildStates(Record)
	end))
	BuildStates(Record)
end

local function TrackPlayer(Player: Player)
	if Player == LocalPlayer then
		return
	end

	Player.CharacterAdded:Connect(function(Character: Model)
		TrackCharacter(Player, Character)
	end)
	Player.CharacterRemoving:Connect(function()
		RemoveCharacter(Player)
	end)
	if Player.Character then
		TrackCharacter(Player, Player.Character)
	end
end

local function Receive(Player: Player, Character: Model, Camera: CFrame, Movement: Vector3, Active: boolean, ServerTime: number)
	local Record = Records[Player]
	if Player == LocalPlayer or not Record or Record.Character ~= Character or Player.Character ~= Character
		or typeof(ServerTime) ~= "number" or ServerTime ~= ServerTime or math.abs(ServerTime) == math.huge
		or ServerTime <= Record.ServerTime or not CameraReplication.IsValid(Camera, Movement, Active) then
		return
	end

	Record.Target = { Camera = Camera, Movement = Movement, Active = Active }
	Record.Camera = Record.Camera or Camera
	Record.ServerTime = ServerTime
	Record.Received = os.clock()
end

local function Send(DeltaTime: number)
	SendElapsed += DeltaTime
	if SendElapsed < CameraReplication.SendInterval then
		return
	end
	SendElapsed %= CameraReplication.SendInterval

	local Character = LocalPlayer.Character
	local Root = Character and Character.PrimaryPart
	local Humanoid = Character and Character:FindFirstChildWhichIsA("Humanoid")
	local Camera = workspace.CurrentCamera
	if not Root or not Humanoid or not Camera then
		return
	end

	local Active = Camera.CameraType == Enum.CameraType.Custom
	local Frame: CameraReplication.Frame = {
		Camera = if Active then Camera.CFrame else Root.CFrame,
		Movement = Humanoid.MoveDirection, Active = Active,
	}
	local Now = os.clock()
	if CameraReplication.ShouldSend(LastSent, Frame, Now - LastSentAt) then
		CameraEvent:FireServer(Frame.Camera, Frame.Movement, Frame.Active)
		LastSent, LastSentAt = Frame, Now
	end
end

local function Render(DeltaTime: number)
	local Character = LocalPlayer.Character
	local Root = Character and Character.PrimaryPart
	local Now = os.clock()
	local Alpha = 1 - math.exp(-CameraReplication.Response * math.max(DeltaTime, 0))
	for Player, Record in Records do
		local Target = Record.Target
		local OtherRoot = Record.Character.PrimaryPart
		if not Root or not OtherRoot or not Record.Character:IsDescendantOf(workspace) or not Target
			or Now - Record.Received > CameraReplication.Timeout
			or not CameraReplication.InRange(Root.Position, OtherRoot.Position) then
			if Record.Rendering then
				ResetRecord(Record)
			end
			continue
		end

		Record.Camera = (Record.Camera or Target.Camera):Lerp(Target.Camera, Alpha)
		if Record.Tilt then
			TiltController.Update(Record.Tilt, Target.Movement, DeltaTime)
		end
		if Record.Look then
			CharacterLookController.Update(Record.Look, Player, Record.Camera, Target.Active, DeltaTime)
		end
		Record.Rendering = true
	end
end

function CameraUpdaterController:GetMovement(Player: Player): Vector3?
	local Record = Records[Player]
	if not Record or Record.Character ~= Player.Character or not Record.Target
		or os.clock() - Record.Received > CameraReplication.Timeout then
		return nil
	end

	return Record.Target.Movement
end

function CameraUpdaterController.KnitStart()
	CameraEvent = ReplicatedStorage.Assets:WaitForChild("Public"):WaitForChild("CameraUpdater") :: UnreliableRemoteEvent
	CameraEvent.OnClientEvent:Connect(Receive)
	Players.PlayerAdded:Connect(TrackPlayer)
	Players.PlayerRemoving:Connect(RemoveCharacter)
	for _, Player in Players:GetPlayers() do
		TrackPlayer(Player)
	end

	LocalPlayer.CharacterAdded:Connect(function()
		LastSent = nil
	end)
	RunService.Heartbeat:Connect(Send)
	RunService:BindToRenderStep("NearbyCharacterPoses", Enum.RenderPriority.Camera.Value + 8, Render)
end

return CameraUpdaterController
