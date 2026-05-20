local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local GamepassService = Knit.CreateService({
	Name = "GamepassService",
	Client = {},
})

local DebounceService
local InventoryService
local ItemService
local AlertService

local DataService

local DevProducts = {
	[2658339061] = function(Player, whoGifted: string)
		local Item = ItemService:CreateItem("ResetSkillTree", 1)
		InventoryService:GiveItemToPlayer(Player, Item)
		if whoGifted then
			AlertService:AlertPlayer(Player, whoGifted .. " purchased a Reset Skill Tree for you.", "Success")
			AlertService:AlertPlayer(
				whoGifted,
				"A Reset Skill Tree was added to " .. Player.Name .. "'s inventory.",
				"Success"
			)
		else
			AlertService:AlertPlayer(Player, "A Reset Skill Tree was added to your inventory.", "Success")
		end
	end,

	[2675020429] = function(Player, whoGifted: string)
		local Item = ItemService:CreateItem("RaceReroll", 1)
		InventoryService:GiveItemToPlayer(Player, Item)
		if whoGifted then
			AlertService:AlertPlayer(Player, whoGifted .. " purchased a Race Reroll for you.", "Success")
			AlertService:AlertPlayer(
				whoGifted,
				"A Race Reroll was added to " .. Player.Name .. "'s inventory.",
				"Success"
			)
		else
			AlertService:AlertPlayer(Player, "A Race Reroll was added to your inventory.", "Success")
		end
	end,

	[2671790112] = function(player, whoGifted: string)
		local Item = ItemService:CreateItem("TradingSign", 1)
		InventoryService:GiveItemToPlayer(player, Item)

		if whoGifted then
			AlertService:AlertPlayer(player, whoGifted .. " purchased a Trading Sign for you.", "Success")
			AlertService:AlertPlayer(
				whoGifted,
				"A Trading Sign was added to " .. player.Name .. "'s inventory.",
				"Success"
			)
		else
			AlertService:AlertPlayer(player, "A Trading Sign was added to your inventory.", "Success")
		end
	end,

	[2676937508] = function(player, whoGifted: string)
		local Item = ItemService:CreateItem("ArtifactRemover", 1)
		InventoryService:GiveItemToPlayer(player, Item)

		if whoGifted then
			AlertService:AlertPlayer(player, whoGifted .. " purchased an Artifact Remover for you.", "Success")
			AlertService:AlertPlayer(
				whoGifted,
				"An artifact Remover was added to " .. player.Name .. "'s inventory.",
				"Success"
			)
		else
			AlertService:AlertPlayer(player, "An Artifact Remover was added to your inventory.", "Success")
		end
	end,
}

local NamesToId = {
	ResetSkillTree = 2658339061,
	RaceReroll = 2675020429,
	MeditateAnywhere = 966346738,
	TradingSign = 2671790112,
	ArtifactBag = 13600173502,
	ArtifactRemover = 2676937508,
	PrivateServer = 13600173502,
}

local DevProductVariant = {
	MeditateAnywhere = 2670571196,
	ArtifactBag = 2676455504,
}

local Validation = {}

local function CheckProductAmount(Player: Player, GiftingTo: Player, DevProductName: string)
	local ItemData = ItemService:GetItemData(DevProductName)
	local ItemInInventory = InventoryService:GetPlayerItemByName(GiftingTo or Player, DevProductName)

	if not ItemData then
		return false
	end

	if ItemInInventory and ItemInInventory.Stack >= (ItemData.MaxStack or 1) then
		if GiftingTo then
			AlertService:AlertPlayer(
				Player,
				"" .. GiftingTo.Name .. " has reached the maximum amount of " .. ItemData.DisplayName,
				"Error"
			)
		else
			AlertService:AlertPlayer(Player, "You have reached the maximum amount of " .. ItemData.DisplayName, "Error")
		end

		return false
	end

	return true
end

local GameId = game.GameId
local BasePath = "https://games.roproxy.com/v1/games/%s/game-passes?limit=100&sortOrder=Asc"
function GamepassService:Request()
	local URL = BasePath:format(GameId)

	local success, result = pcall(function()
		return HttpService:GetAsync(URL)
	end)

	if success then
		return HttpService:JSONDecode(result).data
	end

	return nil
end

function GamepassService:GetAllGamepass(Player: Player)
	if Player:GetAttribute("GamepassRequest") then
		return
	end
	DebounceService:AddDebounce(Player, "GamepassRequest", 10)

	local Passes = self:Request()

	if not Passes then
		return {}
	end
	for _, Pass in Passes do
		local MarketData = MarketplaceService:GetProductInfo(Pass.id, Enum.InfoType.GamePass)
		if MarketData then
			Pass.icon = MarketData.IconImageAssetId
			Pass.description = MarketData.Description
		end
	end

	return Passes
end
function GamepassService.Client:GetAllGamepass(Player: Player)
	return self.Server:GetAllGamepass(Player)
end

function GamepassService:LoadAttributes(Player: Player)
	if GamepassService:HasGamepass(Player, "MeditateAnywhere") then
		Player:SetAttribute("MeditateAnywhere", true)
	end
end

function GamepassService:GrantProduct(Player: Player, DevproductId: number, whoGifted: Player)
	if DevProducts[DevproductId] then
		DevProducts[DevproductId](Player, whoGifted)
	end
end

function GamepassService:HasGamepass(Player: Player, GamepassName: string)
	if RunService:IsStudio() then
		return true
	end

	local PlayerData = DataService:GetData(Player)
	if not PlayerData.Gamepass[GamepassName] then
		PlayerData.Gamepass[GamepassName] =
			MarketplaceService:UserOwnsGamePassAsync(Player.UserId, NamesToId[GamepassName])
	end

	return PlayerData.Gamepass[GamepassName] == true
end

function GamepassService:BuyGamepass(Player: Player, GamepassName: string, GiftingTo: string)
	GamepassName = GamepassName:gsub("!", "")
	GamepassName = GamepassName:gsub(" ", "")

	local Id = NamesToId[GamepassName]

	local PlayerToGift

	if GiftingTo then
		PlayerToGift = Players:FindFirstChild(GiftingTo)
	end

	if GiftingTo and PlayerToGift then
		Player:SetAttribute("GiftingTo", GiftingTo)

		if DevProductVariant[GamepassName] then
			Id = DevProductVariant[GamepassName]
		end
	else
		Player:SetAttribute("GiftingTo", nil)
	end

	if not Id then
		return
	end

	if PlayerToGift and Id then
		if GamepassService:HasGamepass(PlayerToGift, GamepassName) then
			AlertService:AlertPlayer(Player, PlayerToGift.Name .. " already has this gamepass", "Error")
			return
		end
	end

	if not CheckProductAmount(Player, PlayerToGift, GamepassName) then
		return
	end

	local successProduct, _ = pcall(function()
		return MarketplaceService:GetProductInfo(Id, Enum.InfoType.Product)
	end)

	if successProduct then
		MarketplaceService:PromptProductPurchase(Player, Id)
	else
		local successGamepass, _ = pcall(function()
			return MarketplaceService:GetProductInfo(Id, Enum.InfoType.GamePass)
		end)
		if successGamepass then
			MarketplaceService:PromptGamePassPurchase(Player, Id)
		end
	end
end
function GamepassService.Client:BuyGamepass(Player: Player, GamepassName: string, GiftingTo: string)
	self.Server:BuyGamepass(Player, GamepassName, GiftingTo)
end

function GamepassService.KnitInit()
	DataService = Knit.GetService("DataService")
	DebounceService = Knit.GetService("DebounceService")
	InventoryService = Knit.GetService("InventoryService")
	ItemService = Knit.GetService("ItemService")
	AlertService = Knit.GetService("AlertService")
end

return GamepassService
