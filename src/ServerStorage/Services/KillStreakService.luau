local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local KillStreakService = Knit.CreateService({
	Name = "KillStreakService",
	Client = {},
})

local DataService
local InCombatService

local function GetLeaderstats(Player: Player)
	local Leaderstats = Player:FindFirstChild("leaderstats")
	if Leaderstats then
		return Leaderstats
	end

	Leaderstats = Instance.new("Folder")
	Leaderstats.Name = "leaderstats"
	Leaderstats.Parent = Player

	return Leaderstats
end

local function GetKillStreakValue(Player: Player)
	local Leaderstats = GetLeaderstats(Player)
	local KillStreak = Leaderstats:FindFirstChild("Kill Streak")
	if KillStreak and KillStreak:IsA("IntValue") then
		return KillStreak
	end

	KillStreak = Instance.new("IntValue")
	KillStreak.Name = "Kill Streak"
	KillStreak.Parent = Leaderstats

	return KillStreak
end

function KillStreakService:SetKillStreak(Player: Player, Amount: number)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	Amount = math.max(0, Amount)
	PlayerData.KillStreak = Amount
	Player:SetAttribute("KillStreak", Amount)
	GetKillStreakValue(Player).Value = Amount
end

function KillStreakService:LoadPlayer(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	self:SetKillStreak(Player, PlayerData.KillStreak or 0)
end

function KillStreakService:Reset(Player: Player)
	self:SetKillStreak(Player, 0)
end

function KillStreakService:HandlePlayerKill(Attacker: Model, Character: Model)
	local AttackerPlayer = Players:GetPlayerFromCharacter(Attacker)
	local KilledPlayer = Players:GetPlayerFromCharacter(Character)

	if not AttackerPlayer or not KilledPlayer or AttackerPlayer == KilledPlayer then
		return
	end

	local PlayerData = DataService:GetData(AttackerPlayer)
	if not PlayerData then
		return
	end

	self:SetKillStreak(AttackerPlayer, (PlayerData.KillStreak or 0) + 1)
end

function KillStreakService:ResetIfLeavingPlayerCombat(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	if InCombatService:IsInCombatWithPlayer(Character) then
		self:Reset(Player)
	end
end

function KillStreakService.KnitInit()
	DataService = Knit.GetService("DataService")
	InCombatService = Knit.GetService("InCombatService")
end

return KillStreakService
