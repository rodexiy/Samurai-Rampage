local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SkillTreeService = Knit.CreateService({
	Name = "SkillTreeService",
	Client = {
		UpdateUI = Knit.CreateSignal(),
	},
})

local AlertService
local InventoryService
local ItemService
local ValuesService

local AllNodes = {}
local SkillTrees = require(game.ReplicatedStorage.Shared.Index.SkillTrees)
local LevelFunctions = require(game.ReplicatedStorage.Shared.LevelFunctions)

local DataService

function SkillTreeService:Instantiate(NodeName: string)
	local NodeInstance = Instance.new("BoolValue")
	NodeInstance.Name = NodeName
	return NodeInstance
end

function SkillTreeService:GetTreeNodes(TreeName: string)
	local Tree = SkillTrees[TreeName]

	local Nodes = {}
	local function AddNode(Node, PreviousName)
		local Clone = table.clone(Node)
		Clone.Previous = PreviousName
		Clone.Branches = nil
		Nodes[Node.Name] = Clone

		if Node.Branches then
			for _, Branch in Node.Branches do
				AddNode(Branch, Node.Name)
			end
		end
	end

	for _, Node in Tree.Branches do
		AddNode(Node, Tree.Name)
	end

	return Nodes
end

function SkillTreeService:ResetSpecificSkillTree(Player: Player, TreeName: string)
	local PlayerData = DataService:GetData(Player)

	local TreeNodes = self:GetTreeNodes(TreeName)

	for Node in TreeNodes do
		local Index = table.find(PlayerData.UnlockedNodes, Node)
		if Index then
			table.remove(PlayerData.UnlockedNodes, Index)

			PlayerData.FreePoints += TreeNodes[Node].PointsRequired
			local NodeInstance = Player.UnlockedNodes:FindFirstChild(Node)
			if NodeInstance then
				NodeInstance:Destroy()
			end

			if not Node.Passive then
				InventoryService:RemoveItemFromPlayer(Player, Node:gsub(" ", ""), "all")
			end
		end
	end

	Player:SetAttribute("FreePoints", PlayerData.FreePoints)
	ValuesService:UpdateAll(Player.Character)
end

function SkillTreeService:ResetSkillTree(Player: Player)
	local PlayerData = DataService:GetData(Player)
	PlayerData.UnlockedNodes = {}
	PlayerData.FreePoints = LevelFunctions:GetPlayerFreePointsFromLevel(PlayerData.Level)

	local PlayerSkills = {}
	for _, Item in PlayerData.Inventory do
		if Item.Class == "Skill" then
			table.insert(PlayerSkills, Item)
		end
	end

	for _, Item in PlayerSkills do
		InventoryService:RemoveItemFromPlayer(Player, Item.Name, Item.Stack)
	end

	Player.UnlockedNodes:ClearAllChildren()
	Player:SetAttribute("FreePoints", PlayerData.FreePoints)

	ValuesService:UpdateAll(Player.Character)
end

function SkillTreeService:LoadAttributes(Player: Player)
	local PlayerData = DataService:GetData(Player)

	local UnlockedNodes = Player:FindFirstChild("UnlockedNodes") or Instance.new("Folder", Player)
	UnlockedNodes.Name = "UnlockedNodes"

	UnlockedNodes:ClearAllChildren()
	for _, NodeName in PlayerData.UnlockedNodes do
		local NodeInstance = self:Instantiate(NodeName)
		NodeInstance.Parent = UnlockedNodes
	end

	for _, NodeName in PlayerData.OtherSkills do
		local NodeInstance = self:Instantiate(NodeName)
		NodeInstance.Parent = UnlockedNodes
	end

	local OtherAttributes = {
		"Movement",
		"Kendo",
		"Resistance",
		PlayerData.Race,
		PlayerData.Artifact,
	}

	local SpentPoints = 0

	for _, Node in PlayerData.UnlockedNodes do
		local NodeInfo = AllNodes[Node]
		if NodeInfo then
			SpentPoints += NodeInfo.PointsRequired or 0
		end
	end

	PlayerData.FreePoints = LevelFunctions:GetPlayerFreePointsFromLevel(PlayerData.Level) - SpentPoints

	if PlayerData.FreePoints < 0 then
		self:ResetSkillTree(Player)
	end

	Player:SetAttribute("FreePoints", PlayerData.FreePoints)
	for _, Attribute in OtherAttributes do
		Attribute = Attribute:gsub(" ", "")
		local NodeInstance = self:Instantiate(Attribute)
		NodeInstance.Parent = UnlockedNodes
	end
end

function SkillTreeService:UpdateUI(Player: Player)
	SkillTreeService.Client.UpdateUI:Fire(Player, SkillTreeService:GetTreesName(Player))
end

function SkillTreeService:GetTreesName(Player: Player)
	local PlayerData = DataService:GetData(Player)

	return {
		"Movement",
		"Kendo",
		"Resistance",
		PlayerData.Race,
		PlayerData.Artifact,
	}
end
function SkillTreeService.Client:GetTreesName(Player: Player)
	return self.Server:GetTreesName(Player)
end

function SkillTreeService:GetFreePoints(Player: Player)
	local PlayerData = DataService:GetData(Player)
	return PlayerData.FreePoints
end

function SkillTreeService:LearnOtherSkill(Player: Player, SkillName: string)
	local UnlockedNodes = Player:FindFirstChild("UnlockedNodes")

	if UnlockedNodes:FindFirstChild(SkillName) then
		AlertService:AlertPlayer(Player, "Skill already unlocked.", "Error")
		return
	end

	table.insert(DataService:GetData(Player).OtherSkills, SkillName)
	local NodeInstance = self:Instantiate(SkillName)
	NodeInstance.Parent = UnlockedNodes
end

function SkillTreeService:UnlockNode(Player: Player, NodeName: string)
	local NodeInfo = AllNodes[NodeName]

	if not NodeInfo then
		AlertService:AlertPlayer(Player, "Invalid node name.", "Error")
		return
	end

	local UnlockedNodes = Player:FindFirstChild("UnlockedNodes")

	if UnlockedNodes:FindFirstChild(NodeName) then
		AlertService:AlertPlayer(Player, "Skill already unlocked.", "Error")
		return
	end
	local PlayerData = DataService:GetData(Player)

	local function SpaceOut(String)
		return String:gsub("(%l)(%u)", "%1 %2")
	end

	local IgnoreNames = {
		"Movement",
		"Kendo",
		"Resistance",
		PlayerData.Race,
	}

	if PlayerData.Artifact then
		local Subbed = SpaceOut(PlayerData.Artifact)
		table.insert(IgnoreNames, Subbed)
	end

	if not UnlockedNodes:FindFirstChild(NodeInfo.Previous) and not table.find(IgnoreNames, NodeInfo.Previous) then
		AlertService:AlertPlayer(Player, "You have to unlock the previous skill first.", "Error")
		return
	end

	if PlayerData.FreePoints < NodeInfo.PointsRequired then
		AlertService:AlertPlayer(Player, "Not enough free points.", "Error")
		return
	end

	PlayerData.FreePoints -= NodeInfo.PointsRequired
	Player:SetAttribute("FreePoints", PlayerData.FreePoints)

	table.insert(PlayerData.UnlockedNodes, NodeName)
	local NodeInstance = self:Instantiate(NodeName)
	NodeInstance.Parent = UnlockedNodes

	local SubName = NodeInfo.Name:gsub(" ", "")
	if not NodeInfo.Passive then
		local Skill = ItemService:CreateItem(SubName, 1)
		if Skill then
			InventoryService:GiveItemToPlayer(Player, Skill)
		else
			warn("Skill not found ", SubName)
		end
	end

	AlertService:AlertPlayer(Player, "Skill unlocked.", "Success")

	if SubName:find("Stamina") then
		ValuesService:UpdateMaxStamina(Player.Character)
	elseif SubName:find("Resistance") then
		ValuesService:UpdateMaxHealth(Player.Character)
	elseif SubName:find("Regeneration") then
		ValuesService:UpdateRegeneration(Player.Character)
	elseif SubName:find("KendoProficiency") or SubName:find("EnergyConservation") then
		ValuesService:UpdateDamage(Player.Character)
	end

	return true
end
function SkillTreeService.Client:UnlockNode(Player: Player, NodeName: string)
	return self.Server:UnlockNode(Player, NodeName)
end

function SkillTreeService:IsSkillUnlocked(Character: Player | Model, SkillName: string)
	if Character:GetAttribute("IsAI") then
		return false
	end

	local Player = Character
	if Player:IsA("Model") then
		Player = Players:GetPlayerFromCharacter(Character)
	end

	if not Player then
		return false
	end

	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return false
	end
	
	return table.find(PlayerData.UnlockedNodes, SkillName) ~= nil
		or table.find(PlayerData.OtherSkills, SkillName) ~= nil
end

function SkillTreeService.KnitInit()
	AlertService = Knit.GetService("AlertService")
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	ItemService = Knit.GetService("ItemService")
	ValuesService = Knit.GetService("ValuesService")
end

function SkillTreeService.KnitStart()
	local function AddNode(Node, PreviousName)
		local Clone = table.clone(Node)
		Clone.Previous = PreviousName
		Clone.Branches = nil
		AllNodes[Node.Name] = Clone

		if Node.Branches then
			for _, Branch in Node.Branches do
				AddNode(Branch, Node.Name)
			end
		end
	end

	for _, Tree in SkillTrees do
		if not Tree.Branches then
			continue
		end
		for _, Node in Tree.Branches do
			AddNode(Node, Tree.Name)
		end
	end
end

return SkillTreeService
