local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Resources = require(ReplicatedStorage.Shared.RealmResources)
local InventoryStacks = require(ReplicatedStorage.Shared.Utils.InventoryStacks)

local RealmResourceService = Knit.CreateService({
	Name = "RealmResourceService",
	Client = {
		RequirementsRequested = Knit.CreateSignal(),
		RequirementsChanged = Knit.CreateSignal(),
	},
})
local DataService, InventoryService
local Flushing: { [Player]: boolean } = {}
local FreeBuilding: { [Player]: boolean } = {}

function RealmResourceService:AreResourcesRequired(Player: Player): boolean
	return FreeBuilding[Player] ~= true
end

function RealmResourceService:SetResourcesRequired(Player: Player, Required: any): (boolean, string?)
	if typeof(Required) ~= "boolean" then
		return false, "Resource requirement must be true or false."
	end
	if Player.Parent ~= Players then
		return false, "Player is not connected."
	end

	FreeBuilding[Player] = if Required then nil else true
	self.Client.RequirementsChanged:Fire(Player, Required)

	return true
end

function RealmResourceService:GetPlacementCost(Player: Player, Asset: PVInstance): Resources.Cost?
	local Cost = Resources.GetCost(Asset)
	if not Cost then
		return nil
	end

	return if self:AreResourcesRequired(Player) then Cost else {}
end

function RealmResourceService:CanSpend(Player: Player, Cost: Resources.Cost, IncludePending: boolean?): (boolean, string?)
	local Data = DataService:GetData(Player)
	if not Data or not Resources.IsValid(Cost) then
		return false, "Resource data is unavailable."
	end
	local Pending = Data.Realm.PendingResourceRefunds or {}
	for Name, Amount in Cost do
		local Owned = InventoryStacks.Count(Data.Inventory, Name)
		if IncludePending then
			Owned += Pending[Name] or 0
		end
		if Owned < Amount then
			return false, "Not enough " .. Name .. "."
		end
	end

	return true
end

function RealmResourceService:Spend(Player: Player, Cost: Resources.Cost, IncludePending: boolean?): (boolean, string?)
	local Success, Reason = self:CanSpend(Player, Cost, IncludePending)
	if not Success then
		return false, Reason
	end

	local Data = DataService:GetData(Player)
	local Pending = Data.Realm.PendingResourceRefunds or {}
	for Name, Amount in Cost do
		local Queued = if IncludePending then math.min(Amount, Pending[Name] or 0) else 0
		Pending[Name] = (Pending[Name] or 0) - Queued
		if Amount > Queued then
			InventoryService:RemoveItemFromPlayer(Player, Name, Amount - Queued)
		end
	end
	Data.Realm.PendingResourceRefunds = Pending

	return true
end

function RealmResourceService:FlushPending(Player: Player)
	local Data = DataService:GetData(Player)
	if Flushing[Player] or not Data then
		return
	end
	Flushing[Player] = true
	local Pending = Data.Realm.PendingResourceRefunds or {}
	for _, Name in Resources.GetNames(Pending) do
		local Amount = Pending[Name] or 0
		if Amount > 0 and Resources.IsValid({ [Name] = Amount }) then
			-- Reserve before inventory notifications can request another flush.
			Pending[Name] = 0
			local Added = InventoryService:GiveItemToPlayer(Player, { Name = Name, Stack = Amount })
			Pending[Name] = Amount - Added
		end
	end
	Data.Realm.PendingResourceRefunds = Pending
	Flushing[Player] = nil
end

function RealmResourceService:Credit(Player: Player, Cost: Resources.Cost)
	local Data = DataService:GetData(Player)
	assert(Data and Resources.IsValid(Cost), "Invalid realm resource credit")
	local Pending = Data.Realm.PendingResourceRefunds or {}
	for Name, Amount in Cost do
		Pending[Name] = (Pending[Name] or 0) + Amount
	end
	Data.Realm.PendingResourceRefunds = Pending
	self:FlushPending(Player)
end

function RealmResourceService.KnitInit()
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
end

function RealmResourceService.KnitStart()
	RealmResourceService.Client.RequirementsRequested:Connect(function(Player: Player)
		RealmResourceService.Client.RequirementsChanged:Fire(Player, RealmResourceService:AreResourcesRequired(Player))
	end)
	InventoryService.Changed:Connect(function(Player: Player)
		RealmResourceService:FlushPending(Player)
	end)
	Players.PlayerRemoving:Connect(function(Player: Player)
		Flushing[Player] = nil
		FreeBuilding[Player] = nil
	end)
end

return RealmResourceService
