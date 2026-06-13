local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local FloorDropService = Knit.CreateService({
	Name = "FloorDropService",
	Client = {},
})

local RenderService
local InventoryService
local ItemService

local EXPIRATION = 10 * 60
local RADIUS = 8
local TRIES = 10

local DropItems = {}

local DropItemClass = {}
DropItemClass.__index = DropItemClass

function DropItemClass.new(Name: string, Amount: number, Position: Vector3, Player: Player)
	local self = setmetatable({}, DropItemClass)
	self.Name = Name
	self.Amount = Amount
	self.Position = Position
	self.UserId = Player and Player.UserId or 0
	self.Id = HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 8)
	self.ExpirationTask = self:StartExpiration()

	DropItems[self.Id] = self

	return self
end

function DropItemClass:Render()
	if self.UserId == 0 then
		RenderService:RenderForAllPlayers(
			"FloorDrop",
			"Drop",
			{ Name = self.Name, Amount = self.Amount, Id = self.Id, Position = self.Position }
		)
	end
	local Player = Players:GetPlayerByUserId(self.UserId)
	if not Player then
		return
	end
	RenderService:RenderForPlayer(
		Player,
		"FloorDrop",
		"Drop",
		{ Name = self.Name, Amount = self.Amount, Id = self.Id, Position = self.Position }
	)
end

function DropItemClass:StartExpiration()
	return task.spawn(function()
		task.wait(EXPIRATION)
		if self and self.Id then
			self:Destroy()
		end
	end)
end

function DropItemClass:Destroy()
	DropItems[self.Id] = nil

	RenderService:RenderForAllPlayers("FloorDrop", "Remove", { Id = self.Id })
	pcall(function()
		task.cancel(self.ExpirationTask)
	end)

	for index in self do
		self[index] = nil
	end
end

function DropItemClass:Claim(Player: Player)
	if self.UserId == 0 then
		self.UserId = Player.UserId
	end

	print(self.Claimed)
	if self.Claimed then
		return
	end

	self.Claimed = true

	InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem(self.Name, self.Amount))

	self:Destroy()
end
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

function FloorDropService:GetAvailablePosition(Position: Vector3, tryCount: number?)
	RayParams.FilterDescendantsInstances = { workspace.Entity, workspace.NPCs, workspace.FaceHeadFolder }
	local RadiusOffset =
		Vector3.new(math.random(-RADIUS * 10, RADIUS * 10) / 10, RADIUS, math.random(-RADIUS * 10, RADIUS * 10) / 10)

	local ray = workspace:Raycast(Position + RadiusOffset, Vector3.new(0, -RADIUS * 2, 0), RayParams)
	if ray then
		return ray.Position
	end

	if tryCount > 0 then
		return self:GetAvailablePosition(Position, tryCount - 1)
	end

	return self:GetAvailablePosition(Position)
end

function FloorDropService:DropItems(Items: { { Name: string, Amount: number } }, Position: Vector3, Player: Player?)
	for _, ItemData in Items do
		local AvailablePosition = self:GetAvailablePosition(Position, TRIES)
		if not AvailablePosition then
			continue
		end

		local Item = DropItemClass.new(ItemData.Name, ItemData.Amount, AvailablePosition, Player)
		Item:Render()
	end
end

function FloorDropService:ClaimItem(Player: Player, Id: string)
	local Item = DropItems[Id]
	if Item then
		Item:Claim(Player)
	end
end
function FloorDropService.Client:ClaimItem(Player: Player, Id: string)
	self.Server:ClaimItem(Player, Id)
end

function FloorDropService.KnitInit()
	RenderService = Knit.GetService("RenderService")
	InventoryService = Knit.GetService("InventoryService")
	ItemService = Knit.GetService("ItemService")
end

function FloorDropService.KnitStart() end

return FloorDropService
