local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local TeleportCharacter = require(ReplicatedStorage.Shared.Utils.TeleportCharacter)

local RealmService = Knit.CreateService({ Name = "RealmService", Client = {} })
local AlertService, DataService
local RealmsFolder: Folder
local Realms, Busy, Plots = {}, {}, {}
local PLOT_SPACE = 4096

function RealmService:GetRealm(Player: Player): Model?
	return Realms[Player.UserId]
end

function RealmService:GetAvailablePositionForRealm(_Player: Player): Vector3?
	for Index = 1, 20 do
		if not Plots[Index] then
			Plots[Index] = true
			return Vector3.new(Index * PLOT_SPACE, 0, Index * PLOT_SPACE)
		end
	end

	return nil
end

function RealmService:BreakResource(Player: Player, Resource: Model)
	if not self:HasOwnership(Player, Resource) then
		return
	end
	local Id = Resource:GetAttribute("ResourceId")
	local Data = DataService:GetData(Player)
	if Id and Data then
		Data.Realm.Removable[Id] = true
	end
end

function RealmService:LoadRemovable(Player: Player)
	local Realm = self:GetRealm(Player)
	local Data = DataService:GetData(Player)
	if not Realm or not Data then
		return
	end
	for _, Folder in Realm.Removable:GetChildren() do
		for _, Model in Folder:GetChildren() do
			local Id = Model:GetAttribute("ResourceId")
			if not Id then
				continue
			end
			if Data.Realm.Removable[Id] then
				Model:Destroy()
			else
				Model:SetAttribute("RealmId", Player.UserId)
			end
		end
	end
end

function RealmService:DestroyRealmByPlayer(Player: Player)
	local Realm = self:GetRealm(Player)
	if not Realm or Realm:GetAttribute("Unloading") then
		return
	end
	Realm:SetAttribute("Unloading", true)
	Realm:SetAttribute("Loaded", false)
	Plots[Realm:GetAttribute("PlotOffset")] = nil
	Realms[Player.UserId] = nil
	Realm:Destroy()
end

function RealmService:LoadRealm(Player: Player): Model?
	local Existing = self:GetRealm(Player)
	if Existing then
		return if Existing:GetAttribute("Loaded") and not Existing:GetAttribute("Unloading") then Existing else nil
	end
	local Position = self:GetAvailablePositionForRealm(Player)
	assert(Position, "All twenty realm plots are occupied")
	local Realm = Instance.new("Model")
	Realm.Name = tostring(Player.UserId)
	Realm:SetAttribute("OwnerId", Player.UserId)
	Realm:SetAttribute("PlotOffset", Position.X / PLOT_SPACE)
	Realm:SetAttribute("Loaded", false)
	local Template = ServerStorage.ServerAssets.RealmTemplate:Clone()
	for _, Child in Template:GetChildren() do
		Child.Parent = Realm
	end
	Template:Destroy()
	Realm.PrimaryPart = Realm.Foundation.Baseplate
	Realm:PivotTo(CFrame.new(Position))
	Realms[Player.UserId] = Realm
	Realm.Parent = RealmsFolder

	local Success, Error = pcall(function()
		self:LoadRemovable(Player)
	end)
	if not Success or Player.Parent ~= Players then
		self:DestroyRealmByPlayer(Player)
		if not Success then
			warn("[Realm] Load failed", Player.UserId, Error)
		end
		return nil
	end
	Realm:SetAttribute("Loaded", true)
	Realm.Players.ChildRemoved:Connect(function()
		task.defer(function()
			if Realm.Parent and #Realm.Players:GetChildren() == 0 then
				self:DestroyRealmByPlayer(Player)
			end
		end)
	end)

	return Realm
end

function RealmService:TeleportPlayer(Player: Player)
	if Busy[Player] or Player:GetAttribute("InCombat") then
		return
	end
	Busy[Player] = true
	local Success, Error = pcall(function()
		local Character = Player.Character
		if not Character or not Character.PrimaryPart then
			return
		end
		local ReturnPose = Character:GetAttribute("RealmMeditateCFrame")
		if ReturnPose then
			Character:SetAttribute("InRealm", false)
			Character.Parent = workspace:FindFirstChild("Entity") or workspace
			Character:SetAttribute("RealmMeditateCFrame", nil)
			TeleportCharacter(Character, ReturnPose)
			return
		end
		local Realm = self:LoadRealm(Player)
		if not Realm or not Realm:GetAttribute("Loaded") then
			AlertService:AlertPlayer(Player, "Unable to load the Mental Realm. Please try again.", "Warn")
			return
		end
		local Destination = Realm.Structures.Spawn:GetPivot() * CFrame.new(0, -2, -5)
		if workspace.StreamingEnabled then
			Player:RequestStreamAroundAsync(Destination.Position, 10)
		end
		if Player.Character ~= Character or not Character.Parent or not Realm.Parent then
			return
		end
		Character:SetAttribute("RealmMeditateCFrame", Character:GetPivot())
		Character.Parent = Realm.Players
		Character:SetAttribute("InRealm", true)
		TeleportCharacter(Character, Destination)
	end)
	Busy[Player] = nil
	if not Success then
		warn("[Realm] Teleport failed", Error)
		AlertService:AlertPlayer(Player, "Failed to access the Mental Realm.", "Warn")
	end
end

function RealmService.Client:Teleport(Player: Player)
	self.Server:TeleportPlayer(Player)
end

function RealmService:HasOwnership(Player: Player, Object: Model): boolean
	local Id = Object:GetAttribute("RealmId")

	return Id == nil or Id == Player.UserId
end

function RealmService.KnitInit()
	RealmsFolder = workspace:FindFirstChild("Realms") :: Folder?
	if not RealmsFolder then
		RealmsFolder = Instance.new("Folder")
		RealmsFolder.Name = "Realms"
		RealmsFolder.Parent = workspace
	end
	DataService = Knit.GetService("DataService")
	AlertService = Knit.GetService("AlertService")
end

function RealmService.KnitStart()
	Players.PlayerRemoving:Connect(function(Player: Player)
		RealmService:DestroyRealmByPlayer(Player)
		Busy[Player] = nil
	end)
end

return RealmService
