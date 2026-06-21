local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DataService = Knit.GetService("DataService")
local QuestService = Knit.GetService("QuestService")
local ObjectiveService = Knit.GetService("ObjectiveService")
local InventoryService = Knit.GetService("InventoryService")
local ItemService = Knit.GetService("ItemService")
local AlertService = Knit.GetService("AlertService")

local PrisonLabor = {
	Name = "PrisonLabor",
	QuestType = "Collect",

	OnStart = function(Player: Player, AmountToCollect: number)
		local Character = Player.Character
		if not Character then
			return
		end

		Character:SetAttribute("InLabor", true)

		local PlayerData = DataService:GetData(Player)
		PlayerData.Prison.Labor.AmountToCollect = AmountToCollect

		if not InventoryService:GetPlayerItemByName(Player, "Axe") then
			InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem("Axe", 1))
			AlertService:AlertPlayer(Player, "Axe was added to your inventory, use it to collect resources.", "Success")
		end

		ObjectiveService:AddObjective(Player, "PrisonLabor", {
			{ Name = "Collect Resources", TargetAmount = AmountToCollect, CurrentAmount = 0 },
		})
		return true
	end,

	BreakResource = function(Player: Player, ResourceName: string)
		local PlayerData = DataService:GetData(Player)
		PlayerData.Prison.Labor.Collected += 1

		ObjectiveService:AddObjective(Player, "PrisonLabor", {
			{
				Name = "Collect Resources",
				TargetAmount = PlayerData.Prison.Labor.AmountToCollect,
				CurrentAmount = PlayerData.Prison.Labor.Collected,
			},
		})

		if PlayerData.Prison.Labor.Collected >= PlayerData.Prison.Labor.AmountToCollect then
			QuestService:CallQuestFunction(Player, "QuestComplete")
		end

		return true
	end,

	QuestComplete = function(Player: Player)
		local PlayerData = DataService:GetData(Player)

		PlayerData.Prison.Labor.AmountToCollect = 0

		local Exit = workspace.Map.Prison:FindFirstChild("LaborExit")
		if Exit then
			local Character = Player.Character
			if Character then
				Character:SetAttribute("InLabor", false)
				Character:PivotTo(Exit.CFrame)
			end
		end

		ObjectiveService:ClearObjectives(Player, true)

		return true
	end,

	Cancel = function(Player: Player) end,
}

return PrisonLabor
