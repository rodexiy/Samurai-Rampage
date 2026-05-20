local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ResourceService = Knit.CreateService({
	Name = "ResourceService",
	Client = {},
})

local RewardService
local PickableService
local ItemService
local InventoryService
local RenderService
local QuestService

local ResourceTypes = {
	NormalTree = {
		Name = "Normal Tree",
		Rewards = {
			{ Name = "WoodLog", Amount = { 2, 5 }, Weight = 100 },
		},
		RespawnTime = { 5, 10 },
	},

	Crystal = {
		Name = "Crystal",
		Rewards = {
			{ Name = "Crystal", Amount = 1, Weight = 100 },
		},
		RespawnTime = { 5, 10 },
	},

	Iron = {
		Name = "Iron",
		Rewards = {
			{ Name = "IronOre", Amount = { 1, 2 }, Weight = 100 },
		},
		RespawnTime = { 5, 10 },
	},

	Gold = {
		Name = "Gold",
		Rewards = {
			{ Name = "GoldOre", Amount = 1, Weight = 100 },
		},
		RespawnTime = { 5, 10 },
	},

	Coal = {
		Name = "Coal",
		Rewards = {
			{ Name = "Coal", Amount = { 1, 4 }, Weight = 100 },
		},
		RespawnTime = { 5, 10 },
	},
}

local PickablesParams = OverlapParams.new()
PickablesParams.FilterType = Enum.RaycastFilterType.Whitelist
PickablesParams.FilterDescendantsInstances = { workspace:FindFirstChild("Pickable") }

local FadeOutInfo = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

function ResourceService:BreakAnimation(Resource: Model)
	task.spawn(function()
		local Clone = Resource:Clone()

		for _, Part in Resource:GetDescendants() do
			if Part:IsA("BasePart") then
				Part:RemoveTag("WindShake")
				Part.Anchored = false
				Part.CanCollide = true
				Part.CollisionGroup = "Debris"
				Part.Transparency = 0.5
			end
		end

		local OldParent = Resource.Parent
		Resource.Parent = workspace.VFX

		task.wait(5)

		for _, Part in Resource:GetDescendants() do
			if Part:IsA("BasePart") then
				TweenService:Create(Part, FadeOutInfo, { Transparency = 1 }):Play()
				Debris:AddItem(Part, 3)
			end
		end

		task.delay(3, function()
			Resource:Destroy()
		end)

	end)
end

function ResourceService:Respawn(Resource: Model, Parent: Instance, ResourceType: table)
	local RespawnTime = math.random(ResourceType.RespawnTime[1], ResourceType.RespawnTime[2])
	task.wait(RespawnTime)

	Resource:SetAttribute("Health", Resource:GetAttribute("MaxHealth"))
	Resource:SetAttribute("Broken", nil)

	Resource.Parent = Parent
end

local CustomFunctions = {
	NormalTree = function(Player: Player, Resource: Model)
		local cf, size = Resource:GetBoundingBox()
		local PickablexInArea = workspace:GetPartBoundsInBox(cf, size, PickablesParams)

		local Apples = {}
		for _, Pickable in PickablexInArea do
			local Pickable = Pickable:FindFirstAncestorWhichIsA("Model")
			if Pickable and Pickable.Name == "Apple" and not table.find(Apples, Pickable) then
				table.insert(Apples, Pickable)
				PickableService:Pick(Player, Pickable)
			end
		end

		table.clear(Apples)
		Apples = nil
	end,
}

function ResourceService:BreakResource(Player: Player, Resource: Model)
	local ResourceType = ResourceTypes[Resource.Name] or ResourceTypes["NormalTree"]
	if not ResourceType then
		return
	end

	local CustomFunctions = CustomFunctions[Resource.Name] or CustomFunctions["NormalTree"]
	CustomFunctions(Player, Resource)

	local Clone = Resource:Clone()
	local OldParent = Resource.Parent
	for _ in ResourceType.Rewards do
		local ItemName, Amount = RewardService:GetRandomRewardFromWeight(ResourceType.Rewards)
		local Item = ItemService:CreateItem(ItemName, Amount)
		InventoryService:GiveItemToPlayer(Player, Item)
	end

	QuestService:CallQuestFunction(Player, "BreakResource", ResourceType.Name)
	ResourceService:BreakAnimation(Resource)

	ResourceService:Respawn(Clone, OldParent, ResourceType)

end

function ResourceService.KnitInit()
	RewardService = Knit.GetService("RewardService")
	PickableService = Knit.GetService("PickableService")
	ItemService = Knit.GetService("ItemService")
	InventoryService = Knit.GetService("InventoryService")
	RenderService = Knit.GetService("RenderService")
	QuestService = Knit.GetService("QuestService")
end

function ResourceService.KnitStart() end

return ResourceService
