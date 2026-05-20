local Knit = require(game.ReplicatedStorage.Packages.Knit)

local CodeService = Knit.CreateService({
	Name = "CodeService",
	Client = {},
})

local DataService
local AlertService

local Codes = {
	TestCode = {
		Reward = function() end,
		Message = "You reedemed the test code!",
		Expired = false,
	},
}

local HttpService = game:GetService("HttpService")

local function PlayerIsFollowing(FollowerId: number, FollowedId: number, Cursor: string?): boolean
	Cursor = Cursor or ""

	local Url = "https://friends.roproxy.com/v1/users/"
		.. FollowerId
		.. "/followings?cursor="
		.. Cursor
		.. "&sortOrder=Asc&limit=100"
	local Success, Response = pcall(function()
		return HttpService:RequestAsync({
			Url = Url,
			Method = "GET",
		})
	end)

	if Success and Response.Success then
		local Body = HttpService:JSONDecode(Response.Body)
		for _, User in pairs(Body.data) do
			if User.id == FollowedId then
				return true
			end
		end

		if Body.nextPageCursor then
			return PlayerIsFollowing(FollowerId, FollowedId, Body.nextPageCursor)
		end
	end

	return false
end

function CodeService:CanRedeemCode(Player: Player, Code: string): (boolean, string)
	local PlayerData = DataService:GetData(Player)
	local CodeData = Codes[Code]

	if not CodeData then
		return false, "Invalid code."
	end

	if CodeData.Expired then
		return false, "This code has expired."
	end

	PlayerData.Codes = PlayerData.Codes or {}
	if table.find(PlayerData.Codes, Code) then
		return false, "You have already redeemed this code!"
	end

	local groupId = 32878451
	if not Player:IsInGroup(groupId) then
		return false, "You must join the game group to redeem this code!"
	end

	if not PlayerIsFollowing(Player.UserId, 354629099) then
		return false, "You must follow the creator (@rodexiy) on Roblox to redeem this code!"
	end

	return true, CodeData.Message
end

function CodeService:ReedemCode(Player: Player, Code: string)
	local Success, Message = self:CanRedeemCode(Player, Code)
	if not Success then
		AlertService:AlertPlayer(Player, Message, "Error")
		return
	end

	local CodeData = Codes[Code]
	CodeData.Reward(Player)
end

function CodeService.KnitInit()
	DataService = Knit.GetService("DataService")
	AlertService = Knit.GetService("AlertService")
end

function CodeService.KnitStart() end

return CodeService
