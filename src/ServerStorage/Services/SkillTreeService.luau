local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.SkillTreeConfig)
local Progression = require(ReplicatedStorage.Shared.SkillTreeProgression)

local SkillTreeService = Knit.CreateService({
	Name = "SkillTreeService",
	Client = { UpdateUI = Knit.CreateSignal() },
})

local AllNodes = Progression.Index(Config.Trees)
local AlertService
local DataService
local InventoryService
local ItemService
local ValuesService

local function GetFolder(Player: Player): Folder
	local Existing = Player:FindFirstChild("UnlockedNodes")
	if Existing and Existing:IsA("Folder") then
		return Existing
	end

	local Folder = Instance.new("Folder")
	Folder.Name = "UnlockedNodes"
	Folder.Parent = Player
	return Folder
end

function SkillTreeService:Instantiate(NodeName: string): BoolValue
	local Node = Instance.new("BoolValue")
	Node.Name = NodeName
	Node.Value = true
	return Node
end

function SkillTreeService:GetTreeNodes(TreeName: string): { [string]: any }
	local Nodes = {}
	for Name, Node in AllNodes do
		if Node.Stat == TreeName then
			Nodes[Name] = Node
		end
	end

	return Nodes
end

function SkillTreeService:RefreshPoints(Player: Player)
	local Data = DataService:GetData(Player)
	if not Data then
		return
	end

	Data.SkillPoints = Data.SkillPoints or {}
	for _, Stat in Config.Names do
		local Points = Progression.GetPoints(Data, Stat, AllNodes)
		Data.SkillPoints[Stat] = Points
		Player:SetAttribute(Stat .. "SkillPoints", Points)
	end
	Player:SetAttribute("FreePoints", nil)
end

function SkillTreeService:ApplyCharacterTalents(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end
	local Data = DataService:GetData(Player)
	for _, Name in (Data and Data.RetiredSkillNodes) or {} do
		if not AllNodes[Name] then
			Character:SetAttribute("Talent" .. Name:gsub(" ", ""), nil)
		end
	end

	for Name in AllNodes do
		Character:SetAttribute("Talent" .. Name:gsub(" ", ""), self:IsSkillUnlocked(Player, Name))
	end
end

function SkillTreeService:ResetSpecificSkillTree(Player: Player, TreeName: string): boolean
	local Data = DataService:GetData(Player)
	if not Data or not Config.Trees[TreeName] then
		return false
	end

	local Remaining = {}
	local Folder = GetFolder(Player)
	for _, Name in Data.UnlockedNodes do
		local Node = AllNodes[Name]
		if Node and Node.Stat == TreeName then
			local Marker = Folder:FindFirstChild(Name)
			if Marker then
				Marker:Destroy()
			end
		else
			table.insert(Remaining, Name)
		end
	end
	Data.UnlockedNodes = Remaining

	self:RefreshPoints(Player)
	self:ApplyCharacterTalents(Player)
	ValuesService:UpdateAll(Player.Character, false)
	self:UpdateUI(Player)
	return true
end

function SkillTreeService:ResetSkillTree(Player: Player)
	local Data = DataService:GetData(Player)
	if not Data then
		return
	end

	Data.UnlockedNodes = {}
	self:LoadAttributes(Player)
	self:ApplyCharacterTalents(Player)
	ValuesService:UpdateAll(Player.Character, false)
	self:UpdateUI(Player)
end

function SkillTreeService:EnsureStarterSkills(Player: Player)
	local Data = DataService:GetData(Player)
	for _, Name in Config.StarterSkills do
		if not table.find(Data.OtherSkills, Name) then
			table.insert(Data.OtherSkills, Name)
		end

		local ItemName = Name:gsub(" ", "")
		if not InventoryService:GetPlayerItemByName(Player, ItemName) then
			local Item = ItemService:CreateItem(ItemName, 1)
			if Item then
				InventoryService:GiveItemToPlayer(Player, Item)
			end
		end
	end
end

function SkillTreeService:LoadAttributes(Player: Player)
	local Data = DataService:GetData(Player)
	if not Data then
		return
	end

	Progression.Reconcile(Data, AllNodes, Config.Version, Config.LegacyPermanentSkills)
	self:EnsureStarterSkills(Player)
	Data.SwordStyle = Data.SwordStyle or "Beginner"
	Player:SetAttribute("SwordStyle", Data.SwordStyle)
	if Data.FightingStyle == "Sword" or Data.FightingStyle == "Katana" then
		Data.FightingStyle = ""
	end
	Player:SetAttribute("FightingStyle", if Data.FightingStyle ~= "" then Data.FightingStyle else nil)

	local Folder = GetFolder(Player)
	Folder:ClearAllChildren()
	local function Add(Name: string)
		if not Folder:FindFirstChild(Name) then
			self:Instantiate(Name).Parent = Folder
		end
	end

	for _, Name in Data.UnlockedNodes do
		Add(Name)
	end
	for _, Name in Data.OtherSkills do
		if not AllNodes[Name] then
			Add(Name)
		end
	end
	for _, Name in Config.Names do
		Add(Name)
	end

	self:RefreshPoints(Player)
	self:ApplyCharacterTalents(Player)
end

function SkillTreeService:GetTreesName(_Player: Player): { string }
	return table.clone(Config.Names)
end

function SkillTreeService.Client:GetTreesName(Player: Player): { string }
	return self.Server:GetTreesName(Player)
end

function SkillTreeService:UpdateUI(Player: Player)
	self.Client.UpdateUI:Fire(Player, self:GetTreesName(Player))
end

function SkillTreeService:GetFreePoints(Player: Player, Stat: string): number
	local Data = DataService:GetData(Player)
	return if Data and Config.Trees[Stat] then Progression.GetPoints(Data, Stat, AllNodes) else 0
end

function SkillTreeService:LearnOtherSkill(Player: Player, SkillName: string)
	local Data = DataService:GetData(Player)
	if not Data or typeof(SkillName) ~= "string" or AllNodes[SkillName] then
		return
	end
	if self:IsSkillUnlocked(Player, SkillName) then
		AlertService:AlertPlayer(Player, "Skill already unlocked.", "Error")
		return
	end

	table.insert(Data.OtherSkills, SkillName)
	self:Instantiate(SkillName).Parent = GetFolder(Player)
end

function SkillTreeService:UnlockNode(Player: Player, NodeName: string): boolean
	local Data = DataService:GetData(Player)
	if not Data or Data.SkillTreeVersion ~= Config.Version then
		return false
	end

	local Allowed, Reason = Progression.CanUnlock(Data, NodeName, AllNodes)
	if not Allowed then
		AlertService:AlertPlayer(Player, Reason, "Error")
		return false
	end

	-- No yielding calls between validation and the saved unlock.
	table.insert(Data.UnlockedNodes, NodeName)
	self:Instantiate(NodeName).Parent = GetFolder(Player)
	self:RefreshPoints(Player)
	self:ApplyCharacterTalents(Player)
	ValuesService:UpdateAll(Player.Character, false)
	AlertService:AlertPlayer(Player, "Skill unlocked.", "Success")
	return true
end

function SkillTreeService.Client:UnlockNode(Player: Player, NodeName: string): boolean
	return self.Server:UnlockNode(Player, NodeName)
end

function SkillTreeService:IsSkillUnlocked(Subject: Player | Model, SkillName: string): boolean
	if Subject:GetAttribute("IsAI") then
		return false
	end

	local Player = if Subject:IsA("Model") then Players:GetPlayerFromCharacter(Subject) else Subject
	local Data = Player and DataService:GetData(Player)
	if not Data then
		return false
	end

	if SkillName == "No Run Stamina Drain" or SkillName == "No Climb Stamina Drain" then
		SkillName = "Travel Breath"
	end
	if AllNodes[SkillName] then
		return table.find(Data.UnlockedNodes or {}, SkillName) ~= nil
	end

	return table.find(Data.OtherSkills or {}, SkillName) ~= nil
end

function SkillTreeService.KnitInit()
	AlertService = Knit.GetService("AlertService")
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	ItemService = Knit.GetService("ItemService")
	ValuesService = Knit.GetService("ValuesService")
end

function SkillTreeService.KnitStart() end

return SkillTreeService
