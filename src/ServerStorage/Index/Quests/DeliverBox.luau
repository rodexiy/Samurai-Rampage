local Knit = require(game.ReplicatedStorage.Packages.Knit)
local DataService = Knit.GetService("DataService")
local TetsuService = Knit.GetService("TetsuService")
local QuestService = Knit.GetService("QuestService")
local LevelService = Knit.GetService("LevelService")
local AlertService = Knit.GetService("AlertService")
local DebounceService = Knit.GetService("DebounceService")
local ObjectiveService = Knit.GetService("ObjectiveService")

return {
	Name = "DeliverBox",
	QuestType = "Deliver",

	OnStart = function(Player: Player)
		local Character = Player.Character
		if not Character then
			return
		end
		if Player:GetAttribute("DeliverBoxCooldown") then
			AlertService:AlertPlayer(Player, "You are on cooldown!")
			return false
		end

		QuestService:CreateTarget(Player, "Deliver", workspace.NPCs.Sakamoto.HumanoidRootPart)

		local Box = game.ReplicatedStorage.Assets.Equipables.Back.WoodenBox:Clone()
		local Weld = Instance.new("WeldConstraint")
		Weld.Part1 = Box.PrimaryPart
		Weld.Part0 = Character.Torso
		Weld.Parent = Box.PrimaryPart
		Box.Name = "SAKAMOTO_BOX"
		Box:PivotTo(Character.Torso:GetPivot())
		Box.Parent = Character

		ObjectiveService:AddObjective(Player, "QuestDeliverBox", {
			{ Name = "Deliver Box to Sakamoto", TargetAmount = 1, CurrentAmount = 0 },
		})

		return true
	end,

	TalkedWithSakamoto = function(Player: Player)
		local Character = Player.Character
		if not Character then
			return
		end

		local PlayerData = DataService:GetData(Player)
		if not PlayerData.Quest.TalkedWithSakamoto then
			return
		end

		if Character:FindFirstChild("SAKAMOTO_BOX") then
			Character.SAKAMOTO_BOX:Destroy()
		end

		QuestService:RemoveTarget(Player, "Deliver")
		QuestService:CreateTarget(Player, "Talk to Jimbe", workspace.NPCs.Jimbe.HumanoidRootPart)

		ObjectiveService:UpdateProgress(Player, "QuestDeliverBox", 1, 1)
		ObjectiveService:AddObjective(Player, "QuestDeliverBox", {
			{ Name = "Deliver Box to Sakamoto", TargetAmount = 1, CurrentAmount = 1 },
			{ Name = "Talk to Jimbe", TargetAmount = 1, CurrentAmount = 0 },
		})
	end,

	Completed = function(Player: Player)
		QuestService:RemoveTarget(Player, "Deliver")
		QuestService:RemoveTarget(Player, "Talk to Jimbe")
		QuestService:RemoveQuest(Player)

		DebounceService:AddDebounce(Player, "DeliverBoxCooldown", 5)

		local PlayerData = DataService:GetData(Player)
		PlayerData.NPCs.DeliveredBoxToSakamoto = true
		TetsuService:AddTetsu(Player, 125)
		LevelService:GiveExp(Player, 1000)

		ObjectiveService:UpdateProgress(Player, "QuestDeliverBox", 2, 1)
		ObjectiveService:ClearObjectives(Player, true)
	end,

	Cancel = function(Player: Player)
		QuestService:RemoveTarget(Player, "Deliver")
		QuestService:RemoveTarget(Player, "Talk to Jimbe")

		local PlayerData = DataService:GetData(Player)
		PlayerData.NPCs.DeliveredBoxToSakamoto = false

		local Character = Player.Character
		if Character and Character:FindFirstChild("SAKAMOTO_BOX") then
			Character.SAKAMOTO_BOX:Destroy()
		end

		ObjectiveService:ClearObjectives(Player)
	end,

	Died = function(Player: Player)
		local PlayerData = DataService:GetData(Player)
		if not PlayerData.Quest.TalkedWithSakamoto then
			QuestService:RemoveTarget(Player, "Deliver")
			QuestService:RemoveQuest(Player)
			ObjectiveService:ClearObjectives(Player)
		end
	end,
}
