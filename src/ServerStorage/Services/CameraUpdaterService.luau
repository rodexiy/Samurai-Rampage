local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CameraReplication = require(ReplicatedStorage.Shared.CameraReplication)

local CameraUpdaterService = Knit.CreateService({ Name = "CameraUpdaterService", Client = {} })
local CameraEvent: UnreliableRemoteEvent
local LastUpdate: { [Player]: number } = {}

function CameraUpdaterService:UpdateCamera(Player: Player, Camera: any, Movement: any, Active: any)
	local Now = os.clock()
	if Now - (LastUpdate[Player] or -math.huge) < CameraReplication.MinimumServerInterval then
		return
	end
	LastUpdate[Player] = Now

	local Character = Player.Character
	local Root = Character and Character.PrimaryPart
	if not Character or not Root or not Character:IsDescendantOf(workspace)
		or not CameraReplication.IsValid(Camera, Movement, Active)
		or (Camera.Position - Root.Position).Magnitude > CameraReplication.MaximumCameraDistance then
		return
	end

	-- Identity and proximity come from server-owned player/character references.
	local ServerTime = workspace:GetServerTimeNow()
	for _, Observer in Players:GetPlayers() do
		local ObserverCharacter = Observer.Character
		local ObserverRoot = ObserverCharacter and ObserverCharacter.PrimaryPart
		if Observer ~= Player and ObserverRoot and ObserverRoot:IsDescendantOf(workspace)
			and CameraReplication.InRange(Root.Position, ObserverRoot.Position) then
			CameraEvent:FireClient(Observer, Player, Character, Camera, Movement, Active, ServerTime)
		end
	end
end

function CameraUpdaterService.KnitInit()
	local Public = ReplicatedStorage.Assets:FindFirstChild("Public")
	if not Public then
		Public = Instance.new("Folder")
		Public.Name = "Public"
		Public.Parent = ReplicatedStorage.Assets
	end

	local Existing = Public:FindFirstChild("CameraUpdater")
	if Existing then
		assert(Existing:IsA("UnreliableRemoteEvent"), "Assets.Public.CameraUpdater must be an UnreliableRemoteEvent")
		CameraEvent = Existing
	else
		CameraEvent = Instance.new("UnreliableRemoteEvent")
		CameraEvent.Name = "CameraUpdater"
		CameraEvent.Parent = Public
	end
end

function CameraUpdaterService.KnitStart()
	CameraEvent.OnServerEvent:Connect(function(Player: Player, Camera: any, Movement: any, Active: any)
		CameraUpdaterService:UpdateCamera(Player, Camera, Movement, Active)
	end)
	Players.PlayerRemoving:Connect(function(Player: Player)
		LastUpdate[Player] = nil
	end)
end

return CameraUpdaterService
