local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local RealmControl = require(script.Parent.Parent.Parent.Classes.RealmControl)

local RealmService = Knit.CreateService({
	Name = "RealmService",
	Client = {},
})

local AlertService
local DataService

local PLOT_SPACE = 4096

local TeleportCharacter = require(game.ReplicatedStorage.Shared.Utils.TeleportCharacter)

local RealmsFolder
local Realms = {}

function RealmService:GetRealm(Player: Player)
	for _, Realm in Realms do
		if Realm:GetAttribute("OwnerId") == Player.UserId then
			return Realm
		end
	end
end

function RealmService:GetAvailablePositionForRealm(Player: Player)
	local Available = {}

	for _, Realm in Realms do
		Available[Realm:GetAttribute("PlotOffset")] = false
	end

	for PlotOffset = 1, 20 do
		if Available[PlotOffset] == nil then
			return Vector3.new(PlotOffset * PLOT_SPACE, 0, PlotOffset * PLOT_SPACE)
		end
	end
end

function RealmService:BreakResource(Player: Player, Resource: Model)
	if not RealmService:HasOwnership(Player, Resource) then
		return
	end

	local Id = Resource:GetAttribute("ResourceId")
	if not Id then
		return
	end

	local PlayerData = DataService:GetData(Player)
	PlayerData.Realm.Removable[Id] = true
end

function RealmService:LoadRemovable(Player: Player)
	local Realm = self:GetRealm(Player)

	if not Realm then
		return
	end

	local RealmId = Realm:GetAttribute("OwnerId")
	local PlayerData = DataService:GetData(Player)
	for _, Folder in Realm.Removable:GetChildren() do
		for _, Model in Folder:GetChildren() do
			local Id = Model:GetAttribute("ResourceId")
			if not Id then
				warn(Model, "Does not have a resource id")
				continue
			end

			if PlayerData.Realm.Removable[Id] then
				Model:Destroy()
			else
				Model:SetAttribute("RealmId", RealmId)
			end
		end
	end
end

function RealmService:DestroyRealmByPlayer(Player: Player)
	local Realm = self:GetRealm(Player)
	Realm:Destroy()
	Realms[Player.UserId] = nil
end

function RealmService:LoadRealm(Player: Player)
	local Realm = self:GetRealm(Player)
	if Realm then
		return Realm
	end

	local RealmTemplate = ServerStorage.ServerAssets.RealmTemplate:Clone()
	local RealmModel = Instance.new("Model")

	for _, Child in RealmTemplate:GetChildren() do
		Child.Parent = RealmModel
	end
	RealmTemplate:Destroy()
	RealmModel:SetAttribute("Loaded", false)
	RealmModel.Name = Player.UserId
	RealmModel:SetAttribute("OwnerId", Player.UserId)

	RealmModel.PrimaryPart = RealmModel.Foundation.Baseplate
	local AvailablePosition = self:GetAvailablePositionForRealm(Player)
	RealmModel:PivotTo(CFrame.new(AvailablePosition))
	RealmModel:SetAttribute("PlotOffset", math.floor(AvailablePosition.X / PLOT_SPACE))

	Realms[Player.UserId] = RealmModel

	self:LoadRemovable(Player)

	RealmModel.Parent = RealmsFolder
	RealmModel:SetAttribute("Loaded", true)

	return self:GetRealm(Player)
end

function RealmService.Client:Teleport(Player: Player)
	if Player:GetAttribute("InCombat") then
		return
	end
	local Character = Player.Character
	if Character then
		local RealmMeditateCFrame = Character:GetAttribute("RealmMeditateCFrame")
		local Realm = self.Server:GetRealm(Player)

		if not Realm then
			Realm = self.Server:LoadRealm(Player)
		end
		if Realm then
			if RealmMeditateCFrame then
				TeleportCharacter(Character, RealmMeditateCFrame)
				Character.Parent = Workspace:FindFirstChild("Entity")
				Character:SetAttribute("RealmMeditateCFrame", nil)
				Character:SetAttribute("InRealm", false)
			else
				local _RealmControl = RealmControl.new(Realm)
				local conn
				conn = _RealmControl.PlayerChanged.Event:Connect(function(AmountPlayers: number)
					table.insert(_RealmControl.connections, conn)
					if AmountPlayers == 0 then
						self.Server:DestroyRealmByPlayer(Player)
						Realm = nil
					end
				end)
				Character.Parent = Realm:FindFirstChild("Players")
				if not Realm:GetAttribute("Loaded") then
					AlertService:AlertPlayer(Player, "Realm not loaded!", "Warn")
					return
				end

				Character:SetAttribute("RealmMeditateCFrame", Character:GetPivot())

				if Realm then
					Character:SetAttribute("InRealm", true)
					TeleportCharacter(Character, Realm.Structures.Spawn:GetPivot() * CFrame.new(0, -2, -5))
				end
			end
		end
	end
end

function RealmService:HasOwnership(Player: Player, Object: Model)
	if not Object:GetAttribute("RealmId") then
		return true
	end
	return Object:GetAttribute("RealmId") == Player.UserId
end

function RealmService.KnitInit()
	RealmsFolder = Instance.new("Folder")
	RealmsFolder.Name = "Realms"
	RealmsFolder.Parent = game.Workspace

	DataService = Knit.GetService("DataService")
	AlertService = Knit.GetService("AlertService")
end

function RealmService.KnitStart() end

return RealmService
