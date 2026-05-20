local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TradingService = Knit.CreateService({
	Name = "TradingService",
	Client = {
		Updated = Knit.CreateSignal(),
		Requested = Knit.CreateSignal(),
		Accepted = Knit.CreateSignal(),
		CountdownStarted = Knit.CreateSignal(),
		Cancelled = Knit.CreateSignal(),
		Completed = Knit.CreateSignal(),
		Confirmed = Knit.CreateSignal(),
	},
})

local DataService
local AlertService
local InventoryService
local Requests = {}
local Trades = {}

local PlayersContext = {
	"Requester",
	"Requested",
}

local OtherPlayerContext = {
	Requester = "Requested",
	Requested = "Requester",
}

export type TradeType = {
	Requester: Player,
	Requested: Player,
	RequesterItems: { any },
	RequestedItems: { any },
	RequesterConfirmed: boolean,
	RequestedConfirmed: boolean,
	InCountdown: boolean,
	CountdownEnded: boolean,
	TradeCompleted: boolean,
	CountdownThread: nil | thread,
}

local DeepCopy = require(game.ReplicatedStorage.Shared.Utils.DeepCopy)

function TradingService:UpdateBoth(Trade: TradeType, Event: string)
	TradingService.Client[Event]:Fire(Trade.Requester, Trade)
	TradingService.Client[Event]:Fire(Trade.Requested, Trade)
end

function TradingService:AlreadyRequested(PlayerRequested: Player)
	for _, request in Requests do
		if request.PlayerRequested == PlayerRequested then
			return request
		end
	end

	return false
end

function TradingService:Request(Requester: Player, PlayerRequested: Player)
	if PlayerRequested:GetAttribute("InTrade") then
		return AlertService:AlertPlayer(Requester, "Player is currently in a trade.", "Warn")
	end

	local PlayerRequestedData = DataService:GetData(PlayerRequested)
	if not PlayerRequestedData.Settings.Trade then
		return AlertService:AlertPlayer(Requester, "Player disabled trading!", "Warn")
	end

	if TradingService:AlreadyRequested(PlayerRequested) then
		return AlertService:AlertPlayer(Requester, "This player is already being requested!.", "Warn")
	end

	table.insert(Requests, {
		Requester = Requester,
		PlayerRequested = PlayerRequested,
	})

	TradingService.Client.Requested:Fire(PlayerRequested, Requester)
	AlertService:AlertPlayer(Requester, "Request sent to " .. PlayerRequested.Name, "Success")
end
function TradingService.Client:Request(Requester: Player, PlayerRequested: Player)
	self.Server:Request(Requester, PlayerRequested)
end

function TradingService:RemoveRequest(Requester: Player, PlayerRequested: Player)
	for index, request in Requests do
		if request.Requester == Requester and request.PlayerRequested == PlayerRequested then
			table.remove(Requests, index)
			return true
		end
	end

	return false
end

function TradingService:AcceptRequest(PlayerRequested: Player)
	local Request = TradingService:AlreadyRequested(PlayerRequested)

	if not Request then
		return
	end

	local Requester = Request.Requester

	if not Requester.Parent then
		return
	end

	if PlayerRequested:GetAttribute("InTrade") then
		return AlertService:AlertPlayer(Requester, "Player currently in trade", "Warn")
	end

	if Requester:GetAttribute("InTrade") then
		return AlertService:AlertPlayer(PlayerRequested, "Player currently in trade", "Warn")
	end

	if not TradingService:RemoveRequest(Requester, PlayerRequested) then
		return
	end

	local Trade = {
		Requester = Requester,
		Requested = PlayerRequested,
		RequesterItems = {},
		RequestedItems = {},
		RequesterConfirmed = false,
		RequestedConfirmed = false,
		InCountdown = false,
		CountdownEnded = false,
		TradeCompleted = false,
		CountdownThread = nil,
	}
	table.insert(Trades, Trade)

	TradingService:SetInTrade(Trade, true)

	TradingService:UpdateBoth(Trade, "Accepted")
end
function TradingService.Client:AcceptRequest(PlayerRequested: Player)
	self.Server:AcceptRequest(PlayerRequested)
end

function TradingService:GetTradeByPlayer(Player: Player): TradeType & string
	local Trade
	local Context
	for _, _Trade in Trades do
		if _Trade.Requester == Player then
			Trade = _Trade
			Context = "Requester"
			break
		elseif _Trade.Requested == Player then
			Trade = _Trade
			Context = "Requested"
			break
		end
	end

	if not Trade then
		task.defer(coroutine.close, coroutine.running())
		coroutine.yield(coroutine.running())
		return nil
	end
	return Trade, Context
end

function TradingService:GetPlayerItem(Player: Player, Identifier: string)
	local ItemInInventory, InventoryIndex = InventoryService:GetItemByName(Player, Identifier)

	if ItemInInventory then
		return ItemInInventory, InventoryIndex, "Inventory"
	end
end

function TradingService:GetTradeItemById(Trade: TradeType, Identifier: string)
	for index, Item in Trade.RequestedItems do
		if Item.Id == Identifier then
			return Item, index
		end
	end

	for index, Item in Trade.RequesterItems do
		if Item.Id == Identifier then
			return Item, index
		end
	end
end

function TradingService:AddItem(Player: Player, Identifier: string)
	local Trade, Context = TradingService:GetTradeByPlayer(Player)
	assert(not Trade.InCountdown)

	Trade["RequesterConfirmed"] = false
	Trade["RequestedConfirmed"] = false

	local Item, _, ItemContext = TradingService:GetPlayerItem(Player, Identifier)

	local TradeItem = TradingService:GetTradeItemById(Trade, Identifier)

	if not TradeItem then
		local TradeItem = DeepCopy(Item)
		if TradeItem.Amount then
			TradeItem.Amount = 1
		end
		table.insert(Trade[Context .. "Items"], TradeItem)
	elseif TradeItem.Amount and TradeItem.Amount < Item.Amount then
		TradeItem.Amount += 1
	end

	TradingService:UpdateBoth(Trade, "Updated")
end
function TradingService.Client:AddItem(Player: Player, Identifier: string)
	self.Server:AddItem(Player, Identifier)
end

function TradingService:RemoveItem(Player: Player, Identifier: string)
	local Trade, Context = TradingService:GetTradeByPlayer(Player)
	assert(not Trade.InCountdown)

	Trade["RequesterConfirmed"] = false
	Trade["RequestedConfirmed"] = false

	local TradeItem, Index = TradingService:GetTradeItemById(Trade, Identifier)

	if not TradeItem then
		return AlertService:AlertPlayer(Player, "The item is not in trade", "Error")
	end

	if TradeItem.Amount and TradeItem.Amount <= 0 then
		TradeItem.Amount -= 1
	else
		table.remove(Trade[Context .. "Items"], Index)
	end

	TradingService:UpdateBoth(Trade, "Updated")
end
function TradingService.Client:RemoveItem(Player: Player, Identifier: string)
	self.Server:RemoveItem(Player, Identifier)
end

function TradingService:CheckIfLeft(Trade: TradeType)
	return not Trade.Requested or not Trade.Requested.Parent or not Trade.Requester or not Trade.Requester.Parent
end

function TradingService:RemoveItemByContext(Player: Player, Context: string, Item: { any })
	InventoryService:RemoveItemByName(Player, Item.Name, Item.Amount or 1)
end

function TradingService:AddItemByContext(Player: Player, Context: string, Item: { any })
	InventoryService:AddItemTableToInventory(Player, Item)
end

function TradingService:PerformTrade(Trade: TradeType)
	for _, PlayerContext in PlayersContext do
		local Player = Trade[PlayerContext]
		local Items = Trade[PlayerContext .. "Items"]

		local OtherPlayerContext = OtherPlayerContext[PlayerContext]
		local OtherPlayer = Trade[OtherPlayerContext]

		for _, Item in Items do
			local Item, _, ItemContext = TradingService:GetPlayerItem(Player, Item.Id)
			TradingService:RemoveItemByContext(Player, ItemContext, Item)
			TradingService:AddItemByContext(OtherPlayer, ItemContext, Item)
		end
	end

	Trade.TradeCompleted = true

	TradingService:EndTrade(Trade)

	TradingService:UpdateBoth(Trade, "Completed")
	AlertService:AlertPlayers({ Trade.Requested, Trade.Requester }, "Trade completed!", "Success")
end

function TradingService:SetInTrade(Trade: TradeType, State: boolean)
	Trade.Requested:SetAttribute("InTrade", State)
	Trade.Requester:SetAttribute("InTrade", State)
end

function TradingService:EndTrade(Trade: TradeType)
	if Trade.CountdownThread then
		pcall(function()
			task.cancel(Trade.CountdownThread)
		end)
		Trade.CountdownThread = nil
	end

	TradingService:SetInTrade(Trade, false)

	local Index = table.find(Trades, Trade)

	if Index then
		table.remove(Trades, Index)
	end
end

function TradingService:StartCountdown(Trade: TradeType)
	Trade.InCountdown = true

	if Trade.CountdownThread then
		task.cancel(Trade.CountdownThread)
	end

	TradingService:UpdateBoth(Trade, "CountdownStarted")
	Trade.CountdownThread = task.spawn(function()
		local Count = 10
		repeat
			task.wait(1)
			Count -= 1

			if TradingService:CheckIfLeft(Trade) then
				TradingService:EndTrade(Trade)
				break
			end

			if Count <= 0 then
				Trade.InCountdown = false
				Trade.CountdownEnded = true
			end
		until Trade.CountdownEnded

		if Trade.CountdownEnded then
			TradingService:PerformTrade(Trade)
		end
	end)
end

function TradingService:Cancel(Player: Player)
	local Trade = TradingService:GetTradeByPlayer(Player)

	if Trade.CountdownThread and Trade.CountdownEnded then
		return false
	end

	TradingService:EndTrade(Trade)

	Trade.Requested:SetAttribute("InTrade", false)
	Trade.Requester:SetAttribute("InTrade", false)

	TradingService:UpdateBoth(Trade, "Cancelled")
	AlertService:AlertPlayers({ Trade.Requested, Trade.Requester }, "Trade cancelled!", "Error")
end
function TradingService.Client:Cancel(Player: Player)
	self.Server:Cancel(Player)
end

function TradingService:Confirm(Player: Player)
	local Trade, Context = TradingService:GetTradeByPlayer(Player)
	Trade[Context .. "Confirmed"] = true

	TradingService:UpdateBoth(Trade, "Confirmed")
	if Trade.RequesterConfirmed and Trade.RequestedConfirmed then
		TradingService:StartCountdown(Trade)
	end
end
function TradingService.Client:Confirm(Player: Player)
	self.Server:Confirm(Player)
end

function TradingService.KnitInit()
	DataService = Knit.GetService("DataService")
	AlertService = Knit.GetService("AlertService")
	InventoryService = Knit.GetService("InventoryService")
end

return TradingService
