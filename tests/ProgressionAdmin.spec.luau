-- Run with production services/commands and isolated player profiles, Knit signals, and horse despawning.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.InventoryConfig)
local Grid = require(ReplicatedStorage.Shared.Utils.InventoryGrid)
local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)

return function(Inventory: any, GridService: any, Horses: any, Commands: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	Context.Data = {Inventory = {}, Equipped = {}, Hotbar = {}}
	local Layout = GridService:GetLayout(Player)
	Check(Layout.Tier == 1 and Layout.Columns == 6 and Layout.Rows == 8, "New backpacks must start at 6x8")

	for Index = 1, 96 do
		table.insert(Context.Data.Inventory, {Name = "TierResource" .. tostring(Index), Class = "Resource", Stack = 1})
	end
	local ExpectedRows = {8, 12, 16, 100}
	for Tier, Rows in ExpectedRows do
		Check(Inventory:SetBackpackTier(Player, Tier), "Every configured backpack must be selectable")
		Layout = GridService:GetLayout(Player)
		Check(Layout.Tier == Tier and Layout.Columns == 6 and Layout.Rows == Rows, "Tier must choose its exact dimensions")
		Check(Context.Data.Backpack.Tier == Tier and #Context.Data.Inventory == 96, "Tier selection must persist without deleting inventory")
		Check(#Layout.Overflow == math.max(0, 96 - 6 * Rows), "Only items that exceed the selected capacity may overflow")
		for Name, Placement in Layout.Positions do
			Check(Grid.Fits(Layout.Positions, Placement, 6, Rows, Name), "Items must stay in bounds without overlaps")
		end
		Context.Data = DeepCopy(Context.Data)
		Check(GridService:GetLayout(Player).Tier == Tier, "The tier must survive profile serialization")
	end

	Check(Inventory:SetBackpackTier(Player, 1), "Admin backpacks must be reducible to starter backpacks")
	Layout = GridService:GetLayout(Player)
	Check(#Layout.Overflow == 48 and #Context.Data.Inventory == 96, "Downgrading must retain excess items")
	local Revision = Layout.Revision
	Check(Inventory:SetBackpackTier(Player, 1) and GridService:GetLayout(Player).Revision == Revision, "Setting the current tier must be idempotent")
	Check(not GridService:Move(Player, "TierResource1", 1, 1, false, Revision - 1), "Old layout revisions must be rejected")
	for _, Invalid in {0, 5, 1.5, math.huge, 0 / 0, "4", {}} do
		Check(not Inventory:SetBackpackTier(Player, Invalid), "Invalid backpack tiers must fail")
		Check(Context.Data.Backpack.Tier == 1 and Context.Data.Backpack.Revision == Revision, "Invalid tiers must not mutate the backpack")
	end
	Check(not Inventory:SetBackpackTier(Player, nil), "Missing backpack tiers must fail")

	Context.Data = {Inventory = {}, Equipped = {}, Hotbar = {}, Backpack = {Version = 1, Tier = 1, Columns = 6, Rows = 6, Revision = 0, Positions = {}}}
	Layout = GridService:GetLayout(Player)
	Check(Layout.Rows == 8 and Layout.Revision == 1, "Reconciled old starter backpacks must migrate from six to eight rows")
	Check(GridService:GetLayout(Player).Revision == 1, "Starter migration must run only once")
	Context.Data = {Inventory = {}, Equipped = {}, Hotbar = {}, Backpack = {Version = 1, Columns = 8, Rows = 6, Revision = 0, Positions = {}}}
	Layout = GridService:GetLayout(Player)
	Check(Layout.Columns == 6 and Layout.Rows == 8, "Old eight-column backpacks must migrate to 6x8")

	Check(Horses:GetTier(Player) == 1, "Missing horse levels must default to level one")
	for Level = 1, 5 do
		Check(Horses:SetTier(Player, Level), "Every existing horse level must be selectable")
		Check(Context.Data.HorseTier == Level and Horses:GetTier(Player) == Level, "Horse level must persist and control the selected tier")
		Context.Data = DeepCopy(Context.Data)
		Check(Horses:GetTier(Player) == Level, "Horse level must survive profile serialization")
	end
	local Despawns = Context.Despawns
	Check(Horses:SetTier(Player, 5) and Context.Despawns == Despawns, "Setting the same horse level must not despawn the horse")
	for _, Invalid in {0, 6, 1.5, math.huge, 0 / 0, "5", {}} do
		Check(not Horses:SetTier(Player, Invalid), "Invalid horse levels must fail")
		Check(Context.Data.HorseTier == 5 and Context.Despawns == Despawns, "Invalid levels must not change or despawn the horse")
	end
	Check(not Horses:SetTier(Player, nil), "Missing horse levels must fail")

	Check(Commands.BackpackDefinition.Group == "Admin" and Commands.HorseDefinition.Group == "Admin", "Both commands must use existing admin permissions")
	local Result = Commands.Backpack({Executor = Player}, 2)
	Check(Context.Data.Backpack.Tier == 2 and Result:find(Player.Name, 1, true) ~= nil, "Backpack command must default to the executor")
	Result = Commands.Horse({Executor = Player}, 3, {})
	Check(Context.Data.HorseTier == 3 and Result:find(Player.Name, 1, true) ~= nil, "Horse command must default to the executor for an empty target list")

	local Other = {Name = "OtherTestPlayer"}
	local OtherData = {Inventory = {}, Equipped = {}, Hotbar = {}}
	Context.DataByPlayer = {[Player] = Context.Data, [Other] = OtherData}
	Result = Commands.Backpack({Executor = Player}, 4, {Player, Other})
	Check(Context.Data.Backpack.Tier == 4 and OtherData.Backpack.Tier == 4, "Backpack command must update every selected player")
	Check(Result:find(Other.Name, 1, true) ~= nil, "Command response must list its targets")
	Result = Commands.Horse({Executor = Player}, 5, {Other})
	Check(OtherData.HorseTier == 5 and Context.Data.HorseTier == 3, "Horse command must update only the selected players")

	local Missing = {Name = "UnloadedTestPlayer"}
	Result = Commands.Backpack({Executor = Player}, 1, {Other, Missing})
	Check(OtherData.Backpack.Tier == 1 and Result:find(Missing.Name, 1, true) ~= nil, "Commands must report missing profiles while updating valid targets")
	Check(not Horses:SetTier(Missing, 1), "Horse changes must reject unloaded player data")
	Context.DataByPlayer = nil
	Check(Config.Rows == 8 and #Config.Backpacks == 4, "Configuration must expose the four backpack tiers")

	return tostring(Checks) .. " progression admin checks passed"
end
