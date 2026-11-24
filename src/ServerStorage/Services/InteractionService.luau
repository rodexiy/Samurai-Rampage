local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[[
    Recebe inputs de proximity prompts e executa seus callbacks
]]

local InteractionService = Knit.CreateService({
	Name = "InteractionService",
	Client = {
		EnablePrompt = Knit.CreateSignal(),
	},
})

local QuestService
local DialogService
local ItemService
local TetsuService
local InventoryService
local AlertService
local MissionBoardService
local CarryService
local DuelService
local PickableService
local DoorService

local ProximityPromptService = game:GetService("ProximityPromptService")

function InteractionService:EnablePromptForPlayer(Player: Player, ProximityPrompt: ProximityPrompt, state: boolean)
	InteractionService.Client.EnablePrompt:Fire(Player, ProximityPrompt, state)
end

local callbacks = {
	GetAssassinateQuest = function(Player: Player)
		QuestService:GiveQuest(Player, "Assassinate")
	end,
	Carry = function(Player: Player, ProximityPrompt: ProximityPrompt)
		local CharacterBeingCarried = ProximityPrompt.Parent :: Model
		local Character = Player.Character or Player.CharacterAdded:Wait() :: Model
		CarryService:Carry(Character, CharacterBeingCarried)
		ProximityPrompt:Destroy()
	end,
	Pick = function(Player: Player, ProximityPrompt: ProximityPrompt)
		PickableService:Pick(Player, ProximityPrompt.Parent)
	end,

	OpenDoor = function(_Player: Player, ProximityPrompt: ProximityPrompt)
		local DoorParent = ProximityPrompt.Parent
		if DoorParent then
			DoorService:ToggleDoors(DoorParent)
		end
	end,

	["Dialog"] = function(Player: Player, Prompt: ProximityPrompt)
		local npc = Prompt:GetAttribute("NPC") or Prompt:FindFirstAncestorWhichIsA("Model").Name

		DialogService:StartDialog(Player, npc)
	end,

	["Buy"] = function(Player: Player, Prompt: ProximityPrompt)
		local Price = tonumber(Prompt:GetAttribute("Price"))
		local ItemName = Prompt:GetAttribute("Item")
		if Price and ItemName then
			local ItemData = ItemService:GetItemData(ItemName)
			if not ItemData then
				return
			end
			if not InventoryService:CanReceiveItem(Player, { Name = ItemName, Stack = 1 }) then
				AlertService:AlertPlayer(Player, "Not enough backpack space.", "Error")
				return
			end

			if TetsuService:HaveTetsu(Player, Price) then
				TetsuService:RemoveTetsu(Player, Price)
				local Item = ItemService:CreateItem(ItemName, 1)
				InventoryService:GiveItemToPlayer(Player, Item)
				AlertService:AlertPlayer(
					Player,
					"You bought " .. ItemData.DisplayName .. " for " .. Price .. " Tetsu.",
					"Success"
				)
			else
				AlertService:AlertPlayer(Player, "You don't have enough Tetsu.", "Error")
			end
		end
	end,

	["OpenCityBoard"] = function(Player: Player, _Prompt: ProximityPrompt)
		MissionBoardService:OpenBoard(Player)
	end,

	Challenge = function(Player: Player, Prompt: ProximityPrompt)
		local Mob = Prompt.Parent
		DuelService:Challenge(Player, Mob)
	end,
}

function InteractionService:CreateButton(
	Parent: Instance,
	KeyboardKeycode: Enum.KeyCode?,
	Callback: string,
	Name: string?,
	MaxActivationDistance: number?,
	ActionText: string?
)
	local ProximityPrompt = Instance.new("ProximityPrompt")
	ProximityPrompt.KeyboardKeyCode = KeyboardKeycode or Enum.KeyCode.F
	ProximityPrompt.Parent = Parent
	ProximityPrompt.Name = Name or "ProximityPrompt"
	ProximityPrompt.HoldDuration = 0
	ProximityPrompt.ActionText = ActionText or "Interact"
	ProximityPrompt.MaxActivationDistance = MaxActivationDistance or 10
	ProximityPrompt.RequiresLineOfSight = false
	ProximityPrompt:SetAttribute("callback", Callback)
end

function InteractionService.ButtonTriggered(ProximityPrompt: ProximityPrompt, Player: Player, callback)
	if not ProximityPrompt or not ProximityPrompt.Parent then
		return
	end

	local Character = Player.Character

	if
		not ProximityPrompt
		or (ProximityPrompt.Parent:GetPivot().Position - Character:GetPivot().Position).Magnitude
			<= (ProximityPrompt.MaxActivationDistance + 5)
	then
		callback = callback or ProximityPrompt:GetAttribute("callback")
		if not ProximityPrompt and not callback then
			return
		end

		if callbacks[callback] then
			callbacks[callback](Player, ProximityPrompt)
		end
	end
end
function InteractionService.Client:Interact(Player: Player, ProximityPrompt: ProximityPrompt, callback)
	self.Server.ButtonTriggered(ProximityPrompt, Player, callback)
end

function InteractionService.KnitInit()
	QuestService = Knit.GetService("QuestService")
	DialogService = Knit.GetService("DialogService")
	ItemService = Knit.GetService("ItemService")
	TetsuService = Knit.GetService("TetsuService")
	InventoryService = Knit.GetService("InventoryService")
	AlertService = Knit.GetService("AlertService")
	MissionBoardService = Knit.GetService("MissionBoardService")
	CarryService = Knit.GetService("CarryService")
	DuelService = Knit.GetService("DuelService")
	PickableService = Knit.GetService("PickableService")
	DoorService = Knit.GetService("DoorService")
end

function InteractionService.KnitStart()
	ProximityPromptService.PromptTriggered:Connect(InteractionService.ButtonTriggered)
end

return InteractionService
