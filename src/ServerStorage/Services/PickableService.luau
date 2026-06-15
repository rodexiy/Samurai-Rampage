local CollectionService = game:GetService("CollectionService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local Items = require(game.ReplicatedStorage.Shared.Index.Items)

local PickableService = Knit.CreateService({
	Name = "PickableService",
	Client = {},
})

local ItemService
local InventoryService
local RenderService
local DebounceService

local PICK_ANIMATION_DURATION = 1
local PICK_PROMPT_NAME = "PickPrompt"
local PICK_PROMPT_DISTANCE = 5

local Pickables = {
	Apple = {
		Amount = 1,
		RespawnTime = { 180, 360 },
	},
	Blueberry = {
		Amount = 1,
		RespawnTime = { 30, 60 },
	},

	HealingHerbs = {
		Amount = {1, 2},
		RespawnTime = { 30, 60 },
	},

	
	Rice = {
		Amount = {1, 2},
		RespawnTime = { 30, 60 },
	},
}

function PickableService:Pick(Player: Player, Pickable: Model)
	task.spawn(function()
		if Pickable.Parent == nil then
			return
		end

		local OldParent = Pickable.Parent

		Pickable.Parent = nil

		local Character = Player.Character
		if Character then
			DebounceService:AddDebounce(Character, "SkillLockMovement", PICK_ANIMATION_DURATION)
		end

		local PickableData = Pickables[Pickable.Name]
		local Amount = PickableData.Amount
		if type(Amount) == "table" then
			Amount = math.random(Amount[1], Amount[2])
		end

		local RespawnTime = PickableData.RespawnTime
		if type(RespawnTime) == "table" then
			RespawnTime = math.random(RespawnTime[1], RespawnTime[2])
		end

		local Item = ItemService:CreateItem(Pickable.Name, Amount)
		InventoryService:GiveItemToPlayer(Player, Item)
		task.spawn(function()
			RenderService:RenderForPlayer(
				Player,
				"FloorDrop",
				"PickAnim"
			)
		end)
		task.wait(RespawnTime)

		Pickable.Parent = OldParent

	end)
end

function PickableService:BindPickable(Pickable: Model)
	local Prompt = Pickable:FindFirstChild(PICK_PROMPT_NAME)
	if not Prompt then
		Prompt = Instance.new("ProximityPrompt")
		Prompt.Name = PICK_PROMPT_NAME
		Prompt.Parent = Pickable
	end

	local ItemData = Items[Pickable.Name]
	local DisplayName = if ItemData then ItemData.DisplayName or ItemData.Name else Pickable.Name
	local Rarity = if ItemData then ItemData.Rarity or "Common" else "Common"

	Prompt.ActionText = "Pick up"
	Prompt.ObjectText = DisplayName
	Prompt.HoldDuration = 0
	Prompt.KeyboardKeyCode = Enum.KeyCode.F
	Prompt.MaxActivationDistance = PICK_PROMPT_DISTANCE
	Prompt.RequiresLineOfSight = false
	Prompt.Style = Enum.ProximityPromptStyle.Custom
	Prompt:SetAttribute("callback", "Pick")
	Prompt:SetAttribute("DisplayName", DisplayName)
	Prompt:SetAttribute("Pickable", true)
	Prompt:SetAttribute("Rarity", Rarity)
end

function PickableService.KnitInit()
	for _, Pickable in CollectionService:GetTagged("Pickable") do
		PickableService:BindPickable(Pickable)
	end
	CollectionService:GetInstanceAddedSignal("Pickable"):Connect(function(Pickable)
		PickableService:BindPickable(Pickable)
	end)

	local PickablesFolder = workspace:FindFirstChild("Pickable")
	if PickablesFolder then
		for _, Pickable in PickablesFolder:GetChildren() do
			if not Pickable:HasTag("Pickable") then
				Pickable:AddTag("Pickable")
			end
		end
	end
end

function PickableService.KnitStart()
	ItemService = Knit.GetService("ItemService")
	InventoryService = Knit.GetService("InventoryService")
	RenderService = Knit.GetService("RenderService")
	DebounceService = Knit.GetService("DebounceService")
end

return PickableService
