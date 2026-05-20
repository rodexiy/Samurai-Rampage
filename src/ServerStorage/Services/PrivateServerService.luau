local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local PrivateServerService = Knit.CreateService({
	Name = "PrivateServerService",
	Client = {
		GeneratedCode = Knit.CreateSignal(),
	},
})

local PlaceService
local GamepassService
local AlertService
local DataService

local PrivateServers = DataStoreService:GetDataStore("PrivateServers")

function PrivateServerService:GetServerType()
	if game.PrivateServerId ~= "" then
		if game.PrivateServerOwnerId ~= 0 then
			return "VIPServer"
		else
			return "ReservedServer"
		end
	else
		return "StandardServer"
	end
end

function PrivateServerService:GenerateCode(Player: Player)
	local PlayerData = DataService:GetData(Player)
	local ReservedServerCode = TeleportService:ReserveServer(PlaceService:GetPlaceId("SHURA"))
	local PSCode = string.sub(ReservedServerCode, 1, 7)

	if GamepassService:HasGamepass(Player, "PrivateServer") then
		local AlreadyGeneratedCode = PlayerData.PrivateServerCode
		if AlreadyGeneratedCode then
			local RPSCode = string.sub(AlreadyGeneratedCode, 1, 7)
			PrivateServers:RemoveAsync(RPSCode)
		end

		PrivateServers:SetAsync(
			PSCode,
			HttpService:JSONEncode({
				Owner = Player.UserId,
				Code = ReservedServerCode,
				DayOfCreation = os.date("%j"),
			})
		)

		PlayerData.PrivateServerCode = PSCode

		PrivateServerService.Client.GeneratedCode:Fire(Player, PSCode)
	else
		GamepassService:BuyGamepass(Player, "PrivateServer")
	end
end
function PrivateServerService.Client:GenerateCode(Player: Player)
	return self.Server:GenerateCode(Player)
end

function PrivateServerService:GetReservedCode(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData.PrivateServerCode then
		return "???"
	end
	return PlayerData.PrivateServerCode:sub(1, 7)
end
function PrivateServerService.Client:GetReservedCode(Player: Player)
	return self.Server:GetReservedCode(Player)
end

function PrivateServerService:TeleportToServer(Player: Player, ServerCode: string)
	local ServerCode = string.match(ServerCode, "^%S+$")
	if Player:GetAttribute("InCombat") then
		AlertService:AlertPlayer(Player, "You cannot teleport while in combat.", "Error")
		return
	end

	local success, err = pcall(function()
		local ServerData = PrivateServers:GetAsync(ServerCode)
		if not ServerData then
			AlertService:AlertPlayer(Player, "Invalid server code.", "Error")
			return
		end

		local ServerData = HttpService:JSONDecode(ServerData)
		TeleportService:TeleportToPrivateServer(PlaceService:GetPlaceId("SHURA"), ServerData.Code, { Player })
		AlertService:AlertPlayer(Player, "Teleporting to server...", "Success")
	end)
	if not success then
		warn(err)
	end
end
function PrivateServerService.Client:TeleportToServer(Player: Player, ServerCode: string)
	self.Server:TeleportToServer(Player, ServerCode)
end

function PrivateServerService.KnitInit()
	DataService = Knit.GetService("DataService")
	PlaceService = Knit.GetService("PlaceService")
	GamepassService = Knit.GetService("GamepassService")
	AlertService = Knit.GetService("AlertService")
end

function PrivateServerService.KnitStart() end

return PrivateServerService
