local Shovel = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local InventoryService = Knit.GetService("InventoryService")
local AnimationService = Knit.GetService("AnimationService")
local DebounceService = Knit.GetService("DebounceService")
local WeaponService = Knit.GetService("WeaponService")
local ItemService = Knit.GetService("ItemService")
local StaminaService = Knit.GetService("StaminaService")

local Rewards = {
	"IronOre",
	"IronOre",
	"GoldOre",
	"Coal",
	"Coal",
	"Coal",
	"Stone",
	"Stone",
	"Stone",
	"Stone",
	"Stone",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
	"",
}

function Shovel.Activated(Character: Model, Data: { any })
	local Tool = Character:FindFirstChildWhichIsA("Tool")
	if
		not Tool
		or Character:GetAttribute("ShovelDig")
		or Character:GetAttribute("Died")
		or Character:GetAttribute("Ragdoll")
		or Character:GetAttribute("Stamina") < 25
	then
		return
	end

	local Params = RaycastParams.new()
	Params.FilterDescendantsInstances = { workspace:WaitForChild("Entity") }
	Params.FilterType = Enum.RaycastFilterType.Exclude
	local raycast: RaycastResult = workspace:Raycast(Character:GetPivot().Position, Vector3.new(0, -1, 0) * 5, Params)

	if not raycast or raycast.Material ~= Enum.Material.Sand then
		return
	end

	local DigAnimation = Tool:FindFirstChild("Activated", true)
	if not DigAnimation then
		return
	end

	StaminaService:RemoveStamina(Character, 25)
	DebounceService:AddDebounce(Character, "ShovelDig", 1)
	local Track = AnimationService:PlayAnimation(Character, DigAnimation)
	Track.Priority = Enum.AnimationPriority.Action4

	local Player = game.Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end

	local Item = ItemService:CreateItem(Rewards[math.random(1, #Rewards)], 1)
	if not Item then
		return
	end
	InventoryService:GiveItemToPlayer(Player, Item)
end

return Shovel
