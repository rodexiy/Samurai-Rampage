local CollectionService = game:GetService("CollectionService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local PickableService = Knit.CreateService({
	Name = "PickableService",
	Client = {},
})

local ItemService
local InventoryService

local Pickables = {
	Apple = {
		Amount = 1,
		RespawnTime = { 180, 360 },
	},
	Blueberry = {
		Amount = 1,
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
		task.wait(RespawnTime)

		Pickable.Parent = OldParent
	end)
end

function PickableService:BindPickable(Pickable: Model)
	local Detector = Pickable:FindFirstChild("ClickDetector")
	if not Detector then
		Detector = Instance.new("ClickDetector")
		Detector.Parent = Pickable
	end

	Detector.MouseClick:Connect(function(Player)
		PickableService:Pick(Player, Pickable)
	end)
end

function PickableService.KnitInit()
	for _, Pickable in CollectionService:GetTagged("Pickable") do
		PickableService:BindPickable(Pickable)
	end
	CollectionService:GetInstanceAddedSignal("Pickable"):Connect(function(Pickable)
		PickableService:BindPickable(Pickable)
	end)
end

function PickableService.KnitStart()
	ItemService = Knit.GetService("ItemService")
	InventoryService = Knit.GetService("InventoryService")
end

return PickableService
