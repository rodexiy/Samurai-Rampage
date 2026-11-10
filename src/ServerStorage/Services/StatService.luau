local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Progression = require(ReplicatedStorage.Shared.StatProgression)

local StatService = Knit.CreateService({
	Name = "StatService",
	Client = {
		ProgressUpdated = Knit.CreateSignal(),
		SetMeditating = Knit.CreateSignal(),
	},
})

local DataService
local ValuesService
local HitService
local RenderService
local LoadedPlayers: { [Player]: boolean } = {}
local LastPositions: { [Player]: Vector3 } = {}
local MeditationPositions: { [Player]: Vector3 } = {}

local function GetPlayer(Subject: Player | Model): Player?
	return if Subject:IsA("Player") then Subject else Players:GetPlayerFromCharacter(Subject)
end

function StatService:GetLevel(Subject: Player | Model, Name: string): number
	local Player = GetPlayer(Subject)
	local Data = Player and DataService:GetData(Player)
	return if Data and Data.Stats and Data.Stats[Name] then Data.Stats[Name].Level else 0
end

function StatService:GetProgress(Player: Player): { [string]: any }
	local Data = DataService:GetData(Player)
	local Result = {}
	if not Data or not Data.Stats then
		return Result
	end

	for _, Name in Progression.Names do
		local Stat = Data.Stats[Name] or { Level = 0, XP = 0 }
		Result[Name] = {
			Level = Stat.Level,
			XP = Stat.XP,
			XPRequired = Progression.GetXPRequired(Name, Stat.Level),
		}
	end

	return Result
end

function StatService.Client:GetProgress(Player: Player): { [string]: any }
	return self.Server:GetProgress(Player)
end

function StatService:Publish(Player: Player)
	local Progress = self:GetProgress(Player)
	for Name, Stat in Progress do
		Player:SetAttribute(Name .. "Level", Stat.Level)
		Player:SetAttribute(Name .. "XP", Stat.XP)
		Player:SetAttribute(Name .. "XPRequired", Stat.XPRequired)
	end

	self.Client.ProgressUpdated:Fire(Player, Progress)
end

function StatService:LoadPlayer(Player: Player)
	local Data = DataService:GetData(Player)
	if not Data then
		return
	end

	Data.Stats = Data.Stats or {}
	Data.FreePoints = Data.FreePoints or 0
	Data.LegacySkillPointCredits = Data.LegacySkillPointCredits or 0
	for _, Name in Progression.Names do
		Data.Stats[Name] = Data.Stats[Name] or { Level = 0, XP = 0 }
	end

	if not Data.StatProgressionVersion or Data.StatProgressionVersion < 1 then
		if Data.Level ~= nil then
			local TotalXP = math.max(0, Data.Exp or 0)
			for Level = 1, math.clamp(math.floor(Data.Level), 1, 75) - 1 do
				TotalXP += 100 * Level ^ 1.3
			end

			Data.LegacyProgression = { Level = Data.Level, XP = Data.Exp, FreePoints = Data.FreePoints, TotalXP = TotalXP, MigrateSkills = true }
			for _, Name in Progression.Names do
				Progression.Advance(Data.Stats[Name], Name, TotalXP / #Progression.Names)
			end
		end

		Data.StatProgressionVersion = 1
	end

	Data.Level = nil
	Data.Exp = nil
	for _, Name in Progression.Names do
		Progression.Advance(Data.Stats[Name], Name, 0)
	end

	LoadedPlayers[Player] = true
	LastPositions[Player] = nil
	MeditationPositions[Player] = nil
	self:Publish(Player)
end

function StatService:UnloadPlayer(Player: Player)
	LoadedPlayers[Player] = nil
	LastPositions[Player] = nil
	MeditationPositions[Player] = nil
end

function StatService:GetEarnedSkillPoints(Player: Player): number
	local Data = DataService:GetData(Player)
	if not Data or not Data.Stats then
		return 0
	end

	local Points = Data.LegacySkillPointCredits or 0
	for _, Stat in Data.Stats do
		Points += Stat.Level * Progression.PointsPerLevel
	end

	return Points
end

function StatService:GiveXP(Player: Player, Name: string, Amount: number): number
	if not Progression.IsStat(Name) or typeof(Amount) ~= "number" or Amount ~= Amount or Amount <= 0 or Amount == math.huge then
		return 0
	end

	local Data = DataService:GetData(Player)
	if not LoadedPlayers[Player] or not Data or Data.Stats[Name].Level >= Progression.MaxLevel then
		return 0
	end

	local Levels = Progression.Advance(Data.Stats[Name], Name, Amount)
	Data.FreePoints += Levels * Progression.PointsPerLevel
	Player:SetAttribute("FreePoints", Data.FreePoints)
	self:Publish(Player)
	if Levels > 0 and Player.Character and Player.Character:GetAttribute("Loaded") then
		ValuesService:UpdateAll(Player.Character, false)
		RenderService:RenderForAllPlayers("Misc", "LevelUp", { Character = Player.Character })
	end

	return Levels
end

function StatService:GiveRewardXP(Player: Player, Amount: number, Kind: string)
	local Weights = Progression.RewardWeights[Kind]
	if not Weights or typeof(Amount) ~= "number" or Amount <= 0 or Amount ~= Amount or Amount == math.huge then
		return
	end

	local Total = 0
	for _, Weight in Weights do
		Total += Weight
	end

	for Name, Weight in Weights do
		local XP = Amount * Progression.Rewards.Multiplier * Weight / Total
		self:GiveXP(Player, Name, math.min(XP, Progression.Rewards.MaxXPPerStat))
	end
end

function StatService:RecordDamage(Character: Model, Attacker: Model?, Damage: number)
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player and Attacker and Attacker ~= Character and Damage > 0 then
		self:GiveXP(Player, "Vitality", Damage * Progression.Training.DamageTaken)
	end
end

function StatService:RecordHit(Character: Model, Attacker: Model, Result: string, Data: { [string]: any }, Damage: number)
	if Character == Attacker or typeof(Damage) ~= "number" or Damage ~= Damage or Damage <= 0 or Damage == math.huge
		or Character:GetAttribute("Died") or Attacker:GetAttribute("Died") then
		return
	end

	local Defender = Players:GetPlayerFromCharacter(Character)
	local AttackingPlayer = Players:GetPlayerFromCharacter(Attacker)
	if Result == "Hit" and AttackingPlayer and Data.By == "Weapon" then
		self:GiveXP(AttackingPlayer, "Strength", Progression.Training.MeleeHit)
	elseif Defender then
		if Result == "Block" then
			self:GiveXP(Defender, "Resistance", Progression.Training.Block)
		elseif Result == "Deflect" then
			self:GiveXP(Defender, "Dexterity", Progression.Training.Parry)
		elseif Result == "Dodge" then
			self:GiveXP(Defender, "Agility", Progression.Training.Dodge)
		end
	end
end

local function CanMeditate(Player: Player, Character: Model): boolean
	local Root = Character.PrimaryPart
	if not Root or Character:GetAttribute("Died") or Character:GetAttribute("Downed") or Player:GetAttribute("InCombat")
		or Character:GetAttribute("InCombat") or Player:GetAttribute("InWisdomWorld") then
		return false
	end

	if Player:GetAttribute("MeditateAnywhere") then
		return true
	end

	local Rugs = workspace:FindFirstChild("Rugs")
	if Rugs then
		for _, Rug in Rugs:GetChildren() do
			local Part = Rug:FindFirstChild("Rug")
			local Position = if Part and Part:IsA("BasePart") then Part.Position
				elseif Rug:IsA("Model") or Rug:IsA("BasePart") then Rug:GetPivot().Position else nil
			if Position and (Position - Root.Position).Magnitude <= 10 then
				return true
			end
		end
	end

	return false
end

function StatService:SetMeditating(Player: Player, Enabled: boolean)
	local Character = Player.Character
	if typeof(Enabled) ~= "boolean" or not Character then
		return
	end

	local Active = Enabled and Character:GetAttribute("Loaded") and CanMeditate(Player, Character)
	MeditationPositions[Player] = if Active then Character.PrimaryPart.Position else nil
	Character:SetAttribute("Meditating", Active == true)
end

function StatService:SampleTraining(Elapsed: number)
	for Player in LoadedPlayers do
		local Character = Player.Character
		local Root = Character and Character.PrimaryPart
		if not Root or not Character:GetAttribute("Loaded") or Character:GetAttribute("Died") or Character:GetAttribute("Downed") then
			LastPositions[Player] = nil
			MeditationPositions[Player] = nil
			continue
		end

		local Previous = LastPositions[Player]
		LastPositions[Player] = Root.Position
		if Previous and Character:GetAttribute("Running") then
			local Delta = Root.Position - Previous
			local Distance = Vector3.new(Delta.X, 0, Delta.Z).Magnitude
			if Distance > 1 and Distance <= Progression.Training.MaxRunDistancePerSecond * Elapsed then
				self:GiveXP(Player, "Agility", Distance * Progression.Training.RunDistance)
			end
		end

		local MeditationPosition = MeditationPositions[Player]
		if MeditationPosition then
			if Character:GetAttribute("Meditating") and CanMeditate(Player, Character) and (Root.Position - MeditationPosition).Magnitude <= 2 then
				self:GiveXP(Player, "Spirit", Progression.Training.Meditation * Elapsed)
			else
				MeditationPositions[Player] = nil
				Character:SetAttribute("Meditating", false)
			end
		end
	end
end

function StatService.KnitInit()
	DataService = Knit.GetService("DataService")
	ValuesService = Knit.GetService("ValuesService")
	HitService = Knit.GetService("HitService")
	RenderService = Knit.GetService("RenderService")
end

function StatService.KnitStart()
	StatService.Client.SetMeditating:Connect(function(Player: Player, Enabled: boolean)
		StatService:SetMeditating(Player, Enabled)
	end)
	HitService.HitResolved.Event:Connect(function(Character: Model, Attacker: Model, Result: string, Data: { [string]: any }, Damage: number)
		StatService:RecordHit(Character, Attacker, Result, Data, Damage)
	end)
	Players.PlayerRemoving:Connect(function(Player: Player)
		StatService:UnloadPlayer(Player)
	end)

	local Accumulated = 0
	RunService.Heartbeat:Connect(function(DeltaTime: number)
		Accumulated += DeltaTime
		if Accumulated >= Progression.Training.SampleInterval then
			local Elapsed = math.min(Accumulated, Progression.Training.SampleInterval * 2)
			Accumulated = 0
			StatService:SampleTraining(Elapsed)
		end
	end)
end

return StatService
