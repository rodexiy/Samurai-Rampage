local MarketplaceService = game:GetService("MarketplaceService")
local StarterGui = game:GetService("StarterGui")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local CallbackController = Knit.CreateController({
	Name = "CallbackController",
})

local Player = game.Players.LocalPlayer
local PlayerGui
local Menu

local GamepassService
local PartyService
local QuestService
local PrivateServerService
local MissionBoardService
local InventoryController
local SkillTreeController

local PartyController
local MenuController

local Callbacks = {
	ChangeInventoryTab = function(button)
		InventoryController:ChangeTab(button.Name)
	end,

	Equip = function(button)
		InventoryController:EquipItem()
	end,

	EquipLeft = function(button)
		InventoryController:EquipLeftItem()
	end,

	EquipLeftButton = function(button)
		InventoryController:EquipLeftItem()
	end,

	BuyGamepass = function(Button: ImageButton)
		GamepassService:BuyGamepass(Button.Name)
	end,

	CreateParty = function(button: TextButton)
		PartyController:CreateParty()
	end,
	LeaveParty = function(button: TextButton)
		PartyService:LeaveParty()
	end,

	AcceptParty = function(button: TextButton)
		PartyController:PartyAccept()
	end,

	DeclineParty = function(button: TextButton)
		PartyController:PartyDecline()
	end,

	AbandonQuest = function()
		MissionBoardService:AbandonMissions()
		QuestService:AbandonQuest(Player)
	end,

	GenerateServerCode = function()
		PrivateServerService:GenerateCode(Player)
	end,

	OpenSkillTree = function()
		MenuController:OpenMenu("SkillTree", true)
		PlayerGui.Menu.Meditate.Enabled = false
		SkillTreeController:UpdateTree()
	end,

	UnlockSkill = function()
		SkillTreeController:UnlockSkillButton()
	end,

	RerollQuestBoard = function()
		MissionBoardService:RerollMissions()
	end,
}

function CallbackController:BindCallbacks()
	for _, v in ipairs(PlayerGui:GetDescendants()) do
		if v:IsA("TextButton") or v:IsA("ImageButton") then
			v.Activated:Connect(function()
				local CallbackName = if v.Name == "EquipLeftButton" then "EquipLeft" else v:GetAttribute("callback")

				if Callbacks[CallbackName] then
					Callbacks[CallbackName](v)
				end
			end)
		end
	end
end

function CallbackController.KnitInit()
	SkillTreeController = Knit.GetController("SkillTreeController")
	MenuController = Knit.GetController("MenuController")
	PartyController = Knit.GetController("PartyController")
	InventoryController = Knit.GetController("InventoryController")
	GamepassService = Knit.GetService("GamepassService")
	PartyService = Knit.GetService("PartyService")
	QuestService = Knit.GetService("QuestService")
	PrivateServerService = Knit.GetService("PrivateServerService")
	MissionBoardService = Knit.GetService("MissionBoardService")
end

function CallbackController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Menu = PlayerGui:WaitForChild("Menu")

	repeat
		task.wait()
	until #PlayerGui:GetDescendants() >= #StarterGui:GetDescendants()

	CallbackController:BindCallbacks()
end

return CallbackController
