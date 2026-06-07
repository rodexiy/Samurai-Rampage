local Knit = require(game.ReplicatedStorage.Packages.Knit)

local JournalController = Knit.CreateController({
	Name = "JournalController",
})

local Player = game.Players.LocalPlayer

local LevelService
local MenuController

local Journal
local ChapterTitle
local ChapterSubtitle
local LevelText
local StepsContent
local ActivitiesContent
local StepTemplate
local ActivityTemplate

local Chapters = {
	{
		MinLevel = 1,
		MaxLevel = 3,
		Title = "Samurai Initiation",
		Subtitle = "Learn the fundamentals before facing the wider world.",
		Steps = {
			"Practice attacking, blocking, and breaking enemy posture.",
			"Defeat bandits and learn when to heal.",
			"Reach level 4 to begin taking village contracts.",
		},
	},
	{
		MinLevel = 4,
		MaxLevel = 6,
		Title = "Village Work",
		Subtitle = "Build experience through contracts and gathering.",
		Steps = {
			"Visit the Mission Board and accept a contract.",
			"Use an Axe for wood contracts and a Pickaxe for ore contracts.",
			"Complete contracts until you reach level 7.",
		},
	},
	{
		MinLevel = 7,
		MaxLevel = 10,
		Title = "Path of the Warrior",
		Subtitle = "Turn experience into strength and prepare for greater enemies.",
		Steps = {
			"Spend your skill points in the Skill Tree.",
			"Complete quests and contracts to improve your equipment.",
			"Challenge Hanzo when you are ready.",
		},
	},
	{
		MinLevel = 11,
		MaxLevel = 15,
		Title = "Supernatural Threat",
		Subtitle = "Seek artifacts and survive the dangers beyond ordinary bandits.",
		Steps = {
			"Hunt undead and stronger enemies.",
			"Search for artifacts and unlock their skills.",
			"Prepare to challenge Yamarashi.",
		},
	},
	{
		MinLevel = 16,
		MaxLevel = math.huge,
		Title = "Mastery",
		Subtitle = "Choose your own challenges and pursue rare rewards.",
		Steps = {
			"Complete difficult contracts and side quests.",
			"Challenge bosses, dungeons, and other players.",
			"Experiment with stances, artifacts, and equipment.",
		},
	},
}

local Activities = {
	{
		Title = "Journey & Side Quests",
		Description = "Follow NPC objectives to discover mechanics, locations, and substantial experience rewards.",
	},
	{
		Title = "Mission Board",
		Description = "Take repeatable combat, exploration, and resource contracts for steady EXP and Tetsu.",
	},
	{
		Title = "Combat & Bosses",
		Description = "Defeat enemies while exploring, then challenge bosses for greater rewards.",
	},
	{
		Title = "Gathering",
		Description = "Use tools to gather resources. Resource Contracts turn gathering into EXP and Tetsu.",
	},
	{
		Title = "Skill Tree",
		Description = "Leveling grants skill points. Spend them to unlock stronger combat and movement options.",
	},
}

local function AddCard(Template: Frame, Title: string, Description: string, Parent: Instance)
	local Card = Template:Clone()
	Card.Name = "Card"
	Card.Title.Text = Title
	Card.Description.Text = Description
	Card.Visible = true
	Card.Parent = Parent
end

local function ClearCards(Content: Instance, Template: Frame)
	for _, Child in Content:GetChildren() do
		if Child:IsA("Frame") and Child ~= Template then
			Child:Destroy()
		end
	end
end

function JournalController:GetChapter(Level: number)
	for _, Chapter in Chapters do
		if Level >= Chapter.MinLevel and Level <= Chapter.MaxLevel then
			return Chapter
		end
	end

	return Chapters[#Chapters]
end

function JournalController:Refresh()
	if not Journal then
		return
	end

	local _, Level = LevelService:GetExpLevel()
	local Chapter = self:GetChapter(Level)

	LevelText.Text = "LEVEL " .. Level
	ChapterTitle.Text = Chapter.Title
	ChapterSubtitle.Text = Chapter.Subtitle

	ClearCards(StepsContent, StepTemplate)

	if Player:GetAttribute("HasQuest") then
		AddCard(StepTemplate, "Current Objective", "Finish your active objective before taking another one.", StepsContent)
	end

	for Index, Step in Chapter.Steps do
		AddCard(StepTemplate, tostring(Index), Step, StepsContent)
	end
end

function JournalController:BindUI()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Menus = PlayerGui:WaitForChild("Menu")
	Journal = Menus:WaitForChild("Journal")

	local Shade = Journal:WaitForChild("Shade")
	local Window = Shade:WaitForChild("Window")
	local Header = Window:WaitForChild("Header")
	local Body = Window:WaitForChild("Body")
	local CurrentPath = Body:WaitForChild("CurrentPath")
	local ActivitiesPanel = Body:WaitForChild("Activities")

	LevelText = Header:WaitForChild("Level")
	ChapterTitle = CurrentPath:WaitForChild("ChapterTitle")
	ChapterSubtitle = CurrentPath:WaitForChild("ChapterSubtitle")
	StepsContent = CurrentPath:WaitForChild("Content")
	ActivitiesContent = ActivitiesPanel:WaitForChild("Content")
	StepTemplate = StepsContent:WaitForChild("Template")
	ActivityTemplate = ActivitiesContent:WaitForChild("Template")

	for _, Activity in Activities do
		AddCard(ActivityTemplate, Activity.Title, Activity.Description, ActivitiesContent)
	end

	Header.Close.Activated:Connect(function()
		MenuController:CloseAllMenus()
	end)

	Shade.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			MenuController:CloseAllMenus()
		end
	end)

	Window.InputBegan:Connect(function() end)

	Journal:GetPropertyChangedSignal("Enabled"):Connect(function()
		if Journal.Enabled then
			self:Refresh()
		end
	end)
end

function JournalController.KnitInit()
	LevelService = Knit.GetService("LevelService")
	MenuController = Knit.GetController("MenuController")
end

function JournalController.KnitStart()
	JournalController:BindUI()
	JournalController:Refresh()

	LevelService.ExpUpdated:Connect(function()
		JournalController:Refresh()
	end)

	Player:GetAttributeChangedSignal("HasQuest"):Connect(function()
		JournalController:Refresh()
	end)
end

return JournalController
