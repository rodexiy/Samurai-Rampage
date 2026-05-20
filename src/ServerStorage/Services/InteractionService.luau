local Knit = require(game.ReplicatedStorage.Packages.Knit)

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
local PrisonService

local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

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
	OpenDoor = function(Player: Player, ProximityPrompt: ProximityPrompt)
		local DoorParent = ProximityPrompt.Parent
		local tInfo = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		for _, door in ipairs(DoorParent:GetChildren()) do
			if not door:IsA("Model") then
				continue
			end

			local doorOffset = door:GetAttribute("OpenOffset") :: CFrame
			if not door:GetAttribute("Opening") then
				door:SetAttribute("Opening", true)
				if not door:GetAttribute("Open") then
					TweenService:Create(door.PrimaryPart, tInfo, { CFrame = door.PrimaryPart.CFrame * doorOffset })
						:Play()
				else
					TweenService:Create(door.PrimaryPart, tInfo, {
						CFrame = door.PrimaryPart.CFrame * doorOffset:Inverse(),
					}):Play()
				end

				local FirstBasePart = door:FindFirstChildWhichIsA("BasePart")

				if FirstBasePart then
					local doorSound: Sound = FirstBasePart:FindFirstChild("DoorSound") or Instance.new("Sound")
					doorSound.Name = "DoorSound"
					doorSound.RollOffMaxDistance = 100
					doorSound.Volume = 0.3
					doorSound.SoundId = "rbxassetid://115359467353541"
					doorSound.Parent = FirstBasePart

					doorSound:Play()
				end

				door:SetAttribute("Open", not door:GetAttribute("Open"))

				task.delay(1, function()
					door:SetAttribute("Opening", false)
				end)
			end
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
			local _Item = InventoryService:GetPlayerItemByName(Player, ItemName)
			if _Item and _Item.Stack >= ItemData.MaxStack then
				if _Item.MaxStack == 1 then
					AlertService:AlertPlayer(Player, "You already have a " .. ItemData.DisplayName .. ".", "Error")
				else
					AlertService:AlertPlayer(
						Player,
						"You have reached the maximum amount of " .. ItemData.DisplayName .. ".",
						"Error"
					)
				end

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

	["OpenCityBoard"] = function(Player: Player, Prompt: ProximityPrompt)
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
		local callback = callback or ProximityPrompt:GetAttribute("callback")
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
	PrisonService = Knit.GetService("PrisonService")
end

function InteractionService.KnitStart()
	ProximityPromptService.PromptTriggered:Connect(InteractionService.ButtonTriggered)
end

return InteractionService
