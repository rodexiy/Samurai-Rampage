local Knit = require(game.ReplicatedStorage.Packages.Knit)

local LevelService = Knit.CreateService({
	Name = "LevelService",
	Client = {
		ExpUpdated = Knit.CreateSignal(),
	},
})

local AlertService
local RenderService
local DataService

local MaxLevel = 75
local LevelFunctions = require(game.ReplicatedStorage.Shared.LevelFunctions)

function LevelService:GetRemainExpToLevelUp(Level: number, Exp: number)
	return LevelFunctions:GetPlayerLevelExpNeeded(Level) - Exp
end

function LevelService:LevelUp(Player: Player)
	RenderService:RenderForAllPlayers("Misc", "LevelUp", { Character = Player.Character })
end

function LevelService:UpdateUI(Player: Player)
	local PlayerData = DataService:GetData(Player)
	LevelService.Client.ExpUpdated:Fire(Player, PlayerData.Exp, PlayerData.Level)
end

function LevelService:GetExpLevel(Player: Player)
	local PlayerData = DataService:GetData(Player)
	return PlayerData.Exp, PlayerData.Level
end
function LevelService.Client:GetExpLevel(Player: Player)
	return self.Server:GetExpLevel(Player)
end

local POINTS_PER_LEVEL = 1
function LevelService:GiveExp(Player: Player, Amount: number)
	local PlayerData = DataService:GetData(Player)
	local CurrentLevel = PlayerData.Level
	local CurrentExp = PlayerData.Exp

	local _Exp = CurrentExp + Amount
	local _Level = CurrentLevel
	local _Points = 0

	local ExpToLevelUp = LevelService:GetRemainExpToLevelUp(CurrentLevel, _Exp)

	if _Level >= MaxLevel then
		return
	end

	if ExpToLevelUp > 0 then
		PlayerData.Exp += Amount
	elseif ExpToLevelUp == 0 then
		_Exp = 0
		_Level += 1
		_Points += POINTS_PER_LEVEL
		LevelService:LevelUp(Player)
	else
		repeat
			ExpToLevelUp = LevelService:GetRemainExpToLevelUp(_Level, _Exp)
			if -ExpToLevelUp ~= -0 then
				_Exp = -ExpToLevelUp
			else
				_Exp = 0
			end
			_Level += 1
			_Points += POINTS_PER_LEVEL
			LevelService:LevelUp(Player)
			ExpToLevelUp = LevelService:GetRemainExpToLevelUp(_Level, _Exp)
			task.wait()
		until ExpToLevelUp > 0 or _Level >= MaxLevel

		if _Level > MaxLevel then
			_Level = MaxLevel
		end

		if _Level == MaxLevel then
			_Exp = 0
		end
	end

	if PlayerData.Level - _Level == 0 and _Level ~= MaxLevel then
		RenderService:RenderForAllPlayers("Misc", "EarnExp", { Character = Player.Character, Amount = Amount })
	end
	PlayerData.Level = _Level
	PlayerData.FreePoints += _Points
	PlayerData.Exp = _Exp

	LevelService:UpdateUI(Player)
end

function LevelService.KnitInit()
	DataService = Knit.GetService("DataService")
	AlertService = Knit.GetService("AlertService")
	RenderService = Knit.GetService("RenderService")
end

function LevelService.KnitStart() end

return LevelService
