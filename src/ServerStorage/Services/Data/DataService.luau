local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local STUDIO_DATA_STORE_KEY = "Rampage Studio 1"
local LIVE_DATA_STORE_KEY = "Progression Test 1"
local DataStoreKey = if RunService:IsStudio() then STUDIO_DATA_STORE_KEY else LIVE_DATA_STORE_KEY

local Knit = require(ReplicatedStorage.Packages.Knit)
local ProfileStore = require(game.ServerStorage.ServerAssets.Libraries.ProfileStore)
local PROFILE_TEMPLATE = require(script.Parent.ProfileTemplate)
local PlayerStore = ProfileStore.New(DataStoreKey, PROFILE_TEMPLATE)
local Profiles: { [Player]: typeof(PlayerStore:StartSessionAsync()) } = {}

local DataService = Knit.CreateService({
	Name = "DataService",
})

local GamepassService

local Gifts = {}

function DataService:GetData(Player: Player)
	if not Profiles[Player] then
		return nil
	end
	return Profiles[Player].Data
end

function DataService:IsDataLoaded(Player: Player)
	return Profiles[Player] ~= nil
end

local function processReceipt(receipt_info)
	local userId = receipt_info.PlayerId

	local player = Players:GetPlayerByUserId(userId)
	if player then
		local productName = GamepassService:GetGamepassName(receipt_info.ProductId)
			or GamepassService:GetProductName(receipt_info.ProductId)
		local PlayerToGiftId = player:GetAttribute("PlayerToGift")

		if Gifts and Gifts[player.UserId] and Gifts[player.UserId].PlayerToGift then
			local recipientPlayer = Gifts[player.UserId].PlayerToGift
			GamepassService:GrantProduct(recipientPlayer, receipt_info.ProductId)
			Gifts[player.UserId] = nil
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif PlayerToGiftId then
			local PlayerToGift = Players:GetPlayerByUserId(PlayerToGiftId)
			if PlayerToGift then
				local GamepassName = GamepassService:GetGamepassName(receipt_info.ProductId)
				local RealId
				if GamepassName then
					DataService:GetData(PlayerToGift).Gamepass[GamepassName] = true
					RealId = GamepassService:GetRealId(GamepassName)
				else
					local ProductName = GamepassService:GetProductName(receipt_info.ProductId)
					RealId = GamepassService:GetRealId(ProductName)
				end

				GamepassService:GrantProduct(PlayerToGift, RealId, player)
				player:SetAttribute("PlayerToGift", nil)
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		else
			GamepassService:GrantProduct(player, receipt_info.ProductId)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function DataService:LoadData(player)
	local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from PROFILE_TEMPLATE (optional)

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick(`Profile session end - Please rejoin`)
		end)

		if player.Parent == Players then
			Profiles[player] = profile
			print(`Profile loaded for {player.DisplayName}!`, profile.Data)
		else
			profile:EndSession()
		end
	else
		player:Kick(`Profile load fail - Please rejoin`)
	end
end

function DataService.Client.GiftSelection(_, Player: Player, OreName: string, PlayerToGift: Player)
	Gifts[Player.UserId] = {
		Player = Player,
		OreName = OreName,
		PlayerToGift = PlayerToGift,
	}
end

function DataService.ClearGift(PlayerID: number)
	Gifts[PlayerID] = nil
end

function DataService:SaveData(Player: Player)
	local profile = Profiles[Player]
	if profile ~= nil then
		profile:EndSession()
	end
end

function DataService.KnitInit()
	MarketplaceService.ProcessReceipt = processReceipt
	GamepassService = Knit.GetService("GamepassService")
end

return DataService
