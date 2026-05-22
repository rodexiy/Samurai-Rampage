local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local WisdomWorldService = Knit.CreateService({
	Name = "WisdomWorldService",
	Client = {},
})

local AIService
local MobService
local WisdomService

local CharacterShared = require(game.ReplicatedStorage.Shared.CharacterShared)
local TeleportCharacter = require(game.ReplicatedStorage.Shared.Utils.TeleportCharacter)

local WORLD_RADIUS = 512
local PLOT_SPACE = 4096
local FIRST_WAVE_COUNTDOWN = 10
local BETWEEN_WAVE_COUNTDOWN = 10
local SPAWN_MIN_RADIUS = 24
local SPAWN_MAX_RADIUS = 36
local MAX_ENEMIES_PER_WAVE = 3
local HEALTH_INCREASE_PER_WAVE = 0.08
local RUN_SPEED_INCREASE_INTERVAL = 5
local MAX_RUN_SPEED_INCREASE = 6
local ACTION_CHANCE_INCREASE_PER_WAVE = 1
local DEFLECT_CHANCE_INCREASE_INTERVAL = 2
local AI_CONFIGS = script.Parent:WaitForChild("AIService"):WaitForChild("Configs")
local WISDOM_REWARDS = {
	Undead = 0.25,
	Bandit = 0.65,
	Hanzo = 3,
}

local Terrain: Terrain = Workspace:WaitForChild("Terrain")
local WorldsFolder
local ActiveWorlds = {}

local function GetTemplate(): Instance?
	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	return Assets and Assets:FindFirstChild("WisdomWorldTemplate")
end

local function DisconnectAll(Connections: { RBXScriptConnection })
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	table.clear(Connections)
end

local function ClearSessionMobs(Session)
	for _, Connection in Session.MobConnections or {} do
		Connection:Disconnect()
	end
	table.clear(Session.MobConnections)

	for _, Mob in Session.Mobs or {} do
		if Mob and Mob.Parent then
			Mob:Destroy()
		end
	end
	table.clear(Session.Mobs)
end

local function CashOutSessionWisdom(Player: Player, Session)
	if Session.WisdomCashedOut then
		return
	end

	Session.WisdomCashedOut = true

	local EarnedWisdom = math.floor(Player:GetAttribute("WisdomWorldWisdom") or 0)
	if EarnedWisdom <= 0 then
		return
	end

	WisdomService:AddWisdom(Player, EarnedWisdom)
end

local function GetAvailablePosition(): Vector3
	local UsedOffsets = {}

	for _, Session in ActiveWorlds do
		if Session.PlotOffset then
			UsedOffsets[Session.PlotOffset] = true
		end
	end

	for PlotOffset = 1, 50 do
		if not UsedOffsets[PlotOffset] then
			return Vector3.new(-PlotOffset * PLOT_SPACE, 0, PlotOffset * PLOT_SPACE), PlotOffset
		end
	end

	return Vector3.new(-PLOT_SPACE, 0, PLOT_SPACE), 1
end

local function CreateWorldModel(Player: Player): Model?
	local Template = GetTemplate()
	if not Template then
		return nil
	end

	local TemplateClone = Template:Clone()
	local World
	if TemplateClone:IsA("Model") then
		World = TemplateClone
	else
		World = Instance.new("Model")
		for _, Child in TemplateClone:GetChildren() do
			Child.Parent = World
		end
		TemplateClone:Destroy()
	end

	World.Name = "WisdomWorld_" .. Player.UserId
	World:SetAttribute("OwnerId", Player.UserId)
	World:SetAttribute("IsWisdomWorld", true)

	local AvailablePosition, PlotOffset = GetAvailablePosition()
	World:PivotTo(CFrame.new(AvailablePosition))
	World:SetAttribute("PlotOffset", PlotOffset)

	return World
end

local function GetWorldSpawnCFrame(World: Model): CFrame
	local Spawn = World:FindFirstChild("Spawn", true)
		or World:FindFirstChild("PlayerSpawn", true)
		or World:FindFirstChild("SpawnLocation", true)

	if Spawn and Spawn:IsA("BasePart") then
		return Spawn.CFrame * CFrame.new(0, 3, 0)
	end

	local CFrameValue, Size = World:GetBoundingBox()
	return CFrame.new(CFrameValue.Position + Vector3.new(0, (Size.Y / 2) + 5, 0))
end

local function SetFullVitals(Character: Model)
	Character:SetAttribute("Health", Character:GetAttribute("MaxHealth") or 100)
	Character:SetAttribute("Stamina", Character:GetAttribute("MaxStamina") or 100)
end

local function DeepCopy(Value)
	if type(Value) ~= "table" then
		return Value
	end

	local Copy = {}
	for Key, ChildValue in Value do
		Copy[Key] = DeepCopy(ChildValue)
	end

	return Copy
end

local function ScaleLifeDataForWave(LifeData, Wave: number)
	local HealthMultiplier = 1 + (Wave * HEALTH_INCREASE_PER_WAVE)
	LifeData.Health = math.floor((LifeData.Health or 100) * HealthMultiplier)

	local RunSpeedIncrease = math.min(math.floor(Wave / RUN_SPEED_INCREASE_INTERVAL), MAX_RUN_SPEED_INCREASE)
	LifeData.RunSpeed = (LifeData.RunSpeed or 14) + RunSpeedIncrease

	if LifeData.ActionChance then
		LifeData.ActionChance = math.clamp(LifeData.ActionChance + (Wave * ACTION_CHANCE_INCREASE_PER_WAVE), 0, 95)
	end

	if LifeData.DeflectChance then
		LifeData.DeflectChance = math.clamp(
			LifeData.DeflectChance + math.floor(Wave / DEFLECT_CHANCE_INCREASE_INTERVAL),
			0,
			90
		)
	end

	if LifeData.SkillChance then
		LifeData.SkillChance = math.clamp(LifeData.SkillChance + math.floor(Wave / DEFLECT_CHANCE_INCREASE_INTERVAL), 0, 100)
	end
end

local function GetWisdomWorldAIConfig(ConfigName: string, Wave: number)
	local ConfigModule = AI_CONFIGS:WaitForChild(ConfigName)
	local Config = DeepCopy(require(ConfigModule))

	for _, LifeData in Config.Lifes or {} do
		LifeData.DetectionDistance = 10000
		LifeData.DetectionDistanceFromSpawn = 10000
		LifeData.MaintainDistance = 10000
		LifeData.MaxDistanceFromSpawn = 10000
		ScaleLifeDataForWave(LifeData, Wave)
	end

	return Config
end

local function GetEasyEnemyCount(Wave: number)
	if Wave <= 2 then
		return 1
	end

	if Wave <= 4 then
		return 2
	end

	if Wave == 5 then
		return MAX_ENEMIES_PER_WAVE
	end

	return MAX_ENEMIES_PER_WAVE
end

local function GetIncreasingEnemyCount(WaveInEnemySet: number)
	return math.min(MAX_ENEMIES_PER_WAVE, math.max(1, WaveInEnemySet))
end

local function GetWaveEnemies(Wave: number)
	if Wave == 10 then
		return {
			{
				MobName = "Hanzo",
				Runner = "Bandit",
				Config = "Hanzo",
				Equipment = "Hanzo",
			},
		}
	end

	local MobName = if Wave <= 5 then "Undead" else "Bandit"
	local WaveInEnemySet
	if Wave <= 5 then
		WaveInEnemySet = Wave
	elseif Wave <= 9 then
		WaveInEnemySet = Wave - 5
	else
		WaveInEnemySet = Wave - 10
	end

	local EnemyCount = if MobName == "Undead" then GetEasyEnemyCount(WaveInEnemySet) else GetIncreasingEnemyCount(WaveInEnemySet)
	local Enemies = {}

	for _ = 1, EnemyCount do
		table.insert(Enemies, {
			MobName = MobName,
			Runner = MobName,
			Config = MobName,
			Equipment = MobName,
		})
	end

	return Enemies
end

local function GetSpawnCFrameAroundCharacter(Character: Model, Session, Index: number, Amount: number)
	local CharacterPivot = Character:GetPivot()
	local Angle = ((math.pi * 2) / math.max(Amount, 1)) * Index + math.rad(math.random(-25, 25))
	local Radius = math.random(SPAWN_MIN_RADIUS, SPAWN_MAX_RADIUS)
	local Offset = Vector3.new(math.cos(Angle) * Radius, 0, math.sin(Angle) * Radius)
	local SpawnPosition = CharacterPivot.Position + Offset

	if (SpawnPosition - Session.CenterPosition).Magnitude > (WORLD_RADIUS - 24) then
		SpawnPosition = Session.CenterPosition + (SpawnPosition - Session.CenterPosition).Unit * (WORLD_RADIUS - 24)
	end

	local RaycastParameters = RaycastParams.new()
	RaycastParameters.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParameters.FilterDescendantsInstances = { Character, Workspace:WaitForChild("Entity") }

	local RaycastResult = Workspace:Raycast(SpawnPosition + Vector3.new(0, 100, 0), Vector3.new(0, -250, 0), RaycastParameters)
	if RaycastResult then
		SpawnPosition = RaycastResult.Position + Vector3.new(0, 3, 0)
	else
		SpawnPosition += Vector3.new(0, 3, 0)
	end

	return CFrame.new(SpawnPosition, CharacterPivot.Position)
end

local function FillWater(World: Model)
	local WaterBlocks = {}
	local WaterFolder = World:FindFirstChild("Water")
	local SearchRoot = WaterFolder or World

	for _, Water in SearchRoot:GetDescendants() do
		if not Water:IsA("BasePart") then
			continue
		end

		if not WaterFolder and Water.Name ~= "WATER" then
			continue
		end

		local FillCFrame = Water.CFrame * CFrame.new(0, 0.5, 0)
		local FillSize = Water.Size + Vector3.new(8, 0, 8)

		Terrain:FillBlock(FillCFrame, FillSize, Enum.Material.Water)
		table.insert(WaterBlocks, {
			CFrame = FillCFrame,
			Size = FillSize,
		})
	end

	return WaterBlocks
end

local function ClearWater(WaterBlocks)
	for _, WaterBlock in WaterBlocks or {} do
		Terrain:FillBlock(WaterBlock.CFrame, WaterBlock.Size, Enum.Material.Air)
	end
end

function WisdomWorldService:Cleanup(Player: Player, Reason: string?)
	local Session = ActiveWorlds[Player]
	if not Session then
		return
	end

	ActiveWorlds[Player] = nil
	Session.Active = false

	DisconnectAll(Session.Connections)
	CashOutSessionWisdom(Player, Session)
	ClearSessionMobs(Session)

	local Character = Player.Character
	if Character then
		Character:SetAttribute("InWisdomWorld", false)
		Character:SetAttribute("WisdomWorldId", nil)

		if Reason == "LeftArea" and Session.ReturnCFrame and not Character:GetAttribute("Died") then
			TeleportCharacter(Character, Session.ReturnCFrame)
		end
	end

	Player:SetAttribute("InWisdomWorld", false)
	Player:SetAttribute("WisdomWorldWisdom", nil)
	Player:SetAttribute("WisdomWorldWave", nil)
	Player:SetAttribute("WisdomWorldWaveCountdown", nil)
	Player:SetAttribute("WisdomWorldWaveState", nil)
	Player:SetAttribute("WisdomWorldEnemiesLeft", nil)

	ClearWater(Session.WaterBlocks)

	if Session.World then
		Session.World:Destroy()
	end
end

function WisdomWorldService:Monitor(Player: Player)
	local Session = ActiveWorlds[Player]
	if not Session then
		return
	end

	while Session.Active do
		local Character = Player.Character
		if not Character or not Character.Parent then
			WisdomWorldService:Cleanup(Player, "CharacterMissing")
			break
		end

		if (Character:GetPivot().Position - Session.CenterPosition).Magnitude > WORLD_RADIUS then
			WisdomWorldService:Cleanup(Player, "LeftArea")
			break
		end

		task.wait(1)
	end
end

function WisdomWorldService:Countdown(Player: Player, Session, Duration: number)
	Player:SetAttribute("WisdomWorldWaveState", "Countdown")

	for SecondsLeft = Duration, 1, -1 do
		if not Session.Active then
			return false
		end

		Player:SetAttribute("WisdomWorldWaveCountdown", SecondsLeft)
		task.wait(1)
	end

	Player:SetAttribute("WisdomWorldWaveCountdown", 0)
	return Session.Active
end

function WisdomWorldService:SpawnWave(Player: Player, Session)
	local Character = Player.Character
	if not Character or not Character.Parent or Character:GetAttribute("Died") then
		WisdomWorldService:Cleanup(Player, "CharacterMissing")
		return false
	end

	ClearSessionMobs(Session)

	local Wave = Session.Wave
	local Enemies = GetWaveEnemies(Wave)
	local EnemyCount = #Enemies
	Session.AliveMobs = EnemyCount
	Player:SetAttribute("WisdomWorldWave", Wave)
	Player:SetAttribute("WisdomWorldWaveState", "Active")
	Player:SetAttribute("WisdomWorldEnemiesLeft", EnemyCount)

	for Index, EnemyData in Enemies do
		local SpawnCFrame = GetSpawnCFrameAroundCharacter(Character, Session, Index, EnemyCount)
		local Mob = MobService:SpawnMob(EnemyData.MobName, SpawnCFrame, EnemyData.Equipment)
		if not Mob then
			Session.AliveMobs -= 1
			Player:SetAttribute("WisdomWorldEnemiesLeft", Session.AliveMobs)
			continue
		end

		Mob:SetAttribute("WisdomWorldMob", true)
		Mob:SetAttribute("WisdomWorldOwnerId", Player.UserId)
		Mob:SetAttribute("NoRewards", true)
		Mob:SetAttribute("WisdomReward", WISDOM_REWARDS[EnemyData.MobName] or 0)
		AIService:AddAI(Mob, EnemyData.Runner, GetWisdomWorldAIConfig(EnemyData.Config, Wave))

		table.insert(Session.Mobs, Mob)
		table.insert(Session.MobConnections, Mob:GetAttributeChangedSignal("Died"):Connect(function()
			if not Mob:GetAttribute("Died") or Mob:GetAttribute("WisdomWorldDeathCounted") then
				return
			end

			Mob:SetAttribute("WisdomWorldDeathCounted", true)
			Session.AliveMobs = math.max((Session.AliveMobs or 1) - 1, 0)
			Player:SetAttribute("WisdomWorldEnemiesLeft", Session.AliveMobs)
			Player:SetAttribute(
				"WisdomWorldWisdom",
				(Player:GetAttribute("WisdomWorldWisdom") or 0) + (Mob:GetAttribute("WisdomReward") or 0)
			)

			task.delay(5, function()
				if Mob.Parent then
					Mob:Destroy()
				end
			end)
		end))
	end

	return Session.Active
end

function WisdomWorldService:WaitForWaveClear(Player: Player, Session)
	while Session.Active do
		local AliveMobs = 0

		for _, Mob in Session.Mobs do
			if Mob.Parent and not Mob:GetAttribute("Died") then
				AliveMobs += 1
			end
		end

		Session.AliveMobs = AliveMobs
		Player:SetAttribute("WisdomWorldEnemiesLeft", AliveMobs)

		if AliveMobs <= 0 then
			return true
		end

		task.wait(1)
	end

	return false
end

function WisdomWorldService:RunWaves(Player: Player)
	local Session = ActiveWorlds[Player]
	if not Session then
		return
	end

	while Session.Active do
		local CountdownDuration = if Session.Wave == 1 then FIRST_WAVE_COUNTDOWN else BETWEEN_WAVE_COUNTDOWN
		if not WisdomWorldService:Countdown(Player, Session, CountdownDuration) then
			break
		end

		if not WisdomWorldService:SpawnWave(Player, Session) then
			break
		end

		if not WisdomWorldService:WaitForWaveClear(Player, Session) then
			break
		end

		local Character = Player.Character
		if Character and Character.Parent and not Character:GetAttribute("Died") then
			SetFullVitals(Character)
		end

		Player:SetAttribute("WisdomWorldWaveState", "Cleared")
		Session.Wave += 1
		Player:SetAttribute("WisdomWorldWave", Session.Wave)
	end
end

function WisdomWorldService:Enter(Player: Player): (boolean, string?)
	if ActiveWorlds[Player] then
		return false, "You are already in the Wisdom World."
	end

	local Character = Player.Character
	if not Character or not Character.Parent then
		return false, "Character not found."
	end

	if Player:GetAttribute("InCombat") or Character:GetAttribute("InCombat") then
		return false, "Can't enter Wisdom World while in combat."
	end

	local World = CreateWorldModel(Player)
	if not World then
		return false, "Wisdom World template not found."
	end

	local SpawnCFrame = GetWorldSpawnCFrame(World)
	local CenterCFrame = World:GetBoundingBox()

	local Session = {
		Active = true,
		Connections = {},
		MobConnections = {},
		Mobs = {},
		World = World,
		Wave = 1,
		WisdomCashedOut = false,
		WaterBlocks = FillWater(World),
		ReturnCFrame = Character:GetPivot(),
		CenterPosition = CenterCFrame.Position,
		PlotOffset = World:GetAttribute("PlotOffset"),
	}
	ActiveWorlds[Player] = Session

	World.Parent = WorldsFolder

	table.insert(Session.Connections, Character:GetAttributeChangedSignal("Died"):Connect(function()
		if Character:GetAttribute("Died") then
			WisdomWorldService:Cleanup(Player, "Died")
		end
	end))

	table.insert(Session.Connections, Character.Destroying:Connect(function()
		WisdomWorldService:Cleanup(Player, "CharacterDestroying")
	end))

	Character:SetAttribute("Meditating", false)
	Character:SetAttribute("RealmTeleporting", false)
	Character:SetAttribute("InWisdomWorld", true)
	Character:SetAttribute("WisdomWorldId", Player.UserId)
	Player:SetAttribute("InWisdomWorld", true)
	Player:SetAttribute("WisdomWorldWisdom", 0)
	Player:SetAttribute("WisdomWorldWave", 1)
	Player:SetAttribute("WisdomWorldWaveCountdown", FIRST_WAVE_COUNTDOWN)
	Player:SetAttribute("WisdomWorldWaveState", "Countdown")
	Player:SetAttribute("WisdomWorldEnemiesLeft", 0)
	CharacterShared:UpdateBoth(Character)

	TeleportCharacter(Character, SpawnCFrame)
	SetFullVitals(Character)

	task.spawn(function()
		WisdomWorldService:Monitor(Player)
	end)

	task.spawn(function()
		WisdomWorldService:RunWaves(Player)
	end)

	return true
end

function WisdomWorldService.Client:Enter(Player: Player): (boolean, string?)
	return self.Server:Enter(Player)
end

function WisdomWorldService.KnitInit()
	WorldsFolder = Workspace:FindFirstChild("WisdomWorlds") or Instance.new("Folder")
	WorldsFolder.Name = "WisdomWorlds"
	WorldsFolder.Parent = Workspace

	AIService = Knit.GetService("AIService")
	MobService = Knit.GetService("MobService")
	WisdomService = Knit.GetService("WisdomService")
end

function WisdomWorldService.KnitStart()
	Players.PlayerRemoving:Connect(function(Player)
		WisdomWorldService:Cleanup(Player, "PlayerRemoving")
	end)
end

return WisdomWorldService
