local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TeleportCharacter = require(game.ReplicatedStorage.Shared.Utils.TeleportCharacter)

local CombatTutorialService = Knit.CreateService({
	Name = "CombatTutorialService",
	Client = {},
})

local MISSION_NAME = "LearnTheBasics"
local DISPLAY_NAME = "BASIC TRAINING"
local TRAINER_CONFIG = "MikotoCombatTutorial"
local FALLBACK_TRAINER_MOB = "Bandit"
local DOJO_BOUNDARY_DISTANCE = 100
local DOJO_OFFSET = 256
local TRAINER_ACTIONS_FOLDER = "CombatTutorialActions"

local Phases = {
	{
		Key = "Attack",
		Button = "M1",
		Objective = "Light attack Mikoto",
		TargetAmount = 3,
		Mode = "PlayerHitTrainer",
		Action = "Attack",
	},
	{
		Key = "StrongAttack",
		Button = "R",
		Objective = "Heavy attack Mikoto",
		TargetAmount = 1,
		Mode = "PlayerHitTrainer",
		Action = "StrongAttack",
		Result = "Dodge",
	},
	{
		Key = "Block",
		Button = "F",
		Objective = "Block Mikoto's attack",
		TargetAmount = 1,
		Mode = "TrainerHitPlayer",
		Result = "Block",
		TrainerAttacks = true,
	},
	{
		Key = "Parry",
		Button = "F",
		Objective = "Parry Mikoto's attack",
		TargetAmount = 1,
		Mode = "TrainerHitPlayer",
		Result = "Deflect",
		TrainerAttacks = true,
	},
	{
		Key = "Dodge",
		Button = "Q",
		Objective = "Dodge Mikoto's attack",
		TargetAmount = 1,
		Mode = "TrainerHitPlayer",
		Result = "Dodge",
		TrainerAttacks = true,
	},
	{
		Key = "BreakPosture",
		Button = "M1/R",
		Objective = "Break Mikoto's posture",
		TargetAmount = 1,
		Mode = "TrainerPostureBreak",
		TrainerBlocks = true,
	},
	{
		Key = "Execute",
		Button = "R",
		Objective = "Execute downed Mikoto",
		TargetAmount = 1,
		Mode = "TrainerExecuted",
		TrainerDowned = true,
	},
}

local TutorialService
local QuestService
local ObjectiveService
local MobService
local AIService
local CharacterService
local WeaponService
local PostureService
local DebounceService
local AnimationService
local HitService
local ExecutionService

local Sessions = {}
local TrainingDojos = {}

local TrainingDojosFolder = workspace:FindFirstChild("CombatTutorialDojos") or Instance.new("Folder")
TrainingDojosFolder.Name = "CombatTutorialDojos"
TrainingDojosFolder.Parent = workspace

local function GetCharacter(Player: Player): Model?
	local Character = Player.Character
	if Character and Character.Parent then
		return Character
	end

	return nil
end

local function GetRootPart(Character: Model?): BasePart?
	if not Character then
		return nil
	end

	return Character:FindFirstChild("HumanoidRootPart")
end

local function GetPivotPosition(InstanceToRead: Instance?): Vector3?
	if not InstanceToRead then
		return nil
	end

	if InstanceToRead:IsA("BasePart") or InstanceToRead:IsA("Model") then
		return InstanceToRead:GetPivot().Position
	end

	return nil
end

local function LookAtFlat(Position: Vector3, Target: Vector3): CFrame
	local FlatTarget = Vector3.new(Target.X, Position.Y, Target.Z)
	if (FlatTarget - Position).Magnitude < 0.01 then
		return CFrame.new(Position)
	end

	return CFrame.lookAt(Position, FlatTarget)
end

local function GetMissionData(Player: Player)
	return TutorialService:GetMissionData(Player, MISSION_NAME, true)
end

local function GetPlayerMissionSave(Player: Player)
	local _, PlayerData = TutorialService:GetMissionData(Player, MISSION_NAME)
	return PlayerData
end

local function CreateTrainingDojo(): Model?
	local ServerAssets = ServerStorage:FindFirstChild("ServerAssets")
	local DojoTemplate = ServerAssets and ServerAssets:FindFirstChild("Dojo")
	if not DojoTemplate or not DojoTemplate:IsA("Model") then
		warn("[CombatTutorialService] Missing ServerStorage.ServerAssets.Dojo.")
		return nil
	end

	local Dojo = DojoTemplate:Clone()
	table.insert(TrainingDojos, Dojo)

	local Offset = DOJO_OFFSET * #TrainingDojos
	Dojo:PivotTo(CFrame.new(5000 + Offset, 1000 + Offset, 1000 + Offset))
	Dojo.Parent = TrainingDojosFolder

	return Dojo
end

local function DestroyTrainingDojo(Dojo: Model?)
	if not Dojo then
		return
	end

	local Index = table.find(TrainingDojos, Dojo)
	if Index then
		table.remove(TrainingDojos, Index)
	end

	Dojo:Destroy()
end

local function GetPhase(MissionData)
	local PhaseIndex = MissionData.CombatTutorialPhase
	if typeof(PhaseIndex) ~= "number" then
		PhaseIndex = 1
	end

	return Phases[math.clamp(PhaseIndex, 1, #Phases)], PhaseIndex
end

local function AddConnection(Session, Connection: RBXScriptConnection)
	table.insert(Session.Connections, Connection)
	return Connection
end

local function DisconnectSession(Session)
	for _, Connection in Session.Connections do
		Connection:Disconnect()
	end

	table.clear(Session.Connections)
end

local function GetTrainerAction(Trainer: Model, ActionName: string)
	local ServerAssets = ServerStorage:FindFirstChild("ServerAssets")
	local MobActions = ServerAssets and ServerAssets:FindFirstChild("MobActions")
	local ActionTemplate = MobActions and MobActions:FindFirstChild(ActionName)
	if not ActionTemplate or not ActionTemplate:IsA("ModuleScript") then
		warn(`[CombatTutorialService] Missing ServerStorage.ServerAssets.MobActions.{ActionName}.`)
		return nil
	end

	local ActionsFolder = Trainer:FindFirstChild(TRAINER_ACTIONS_FOLDER)
	if not ActionsFolder then
		ActionsFolder = Instance.new("Folder")
		ActionsFolder.Name = TRAINER_ACTIONS_FOLDER
		ActionsFolder.Parent = Trainer
	end

	local ActionModule = ActionsFolder:FindFirstChild(ActionName)
	if not ActionModule then
		ActionModule = ActionTemplate:Clone()
		ActionModule.Parent = ActionsFolder
	end

	if not ActionModule:IsA("ModuleScript") then
		return nil
	end

	return require(ActionModule)
end

local function GetPhaseObjective(Phase): string
	if Phase.Button then
		return `[{Phase.Button}] {Phase.Objective}`
	end

	return Phase.Objective
end

function CombatTutorialService:ShowPhaseObjective(Player: Player)
	local MissionData = GetMissionData(Player)
	if not MissionData then
		return false
	end

	local Phase = GetPhase(MissionData)
	if not Phase then
		return false
	end

	ObjectiveService:AddObjective(Player, MISSION_NAME, {
		{
			Name = GetPhaseObjective(Phase),
			TargetAmount = Phase.TargetAmount,
			CurrentAmount = MissionData.CombatTutorialProgress or 0,
		},
	}, DISPLAY_NAME, false)

	return true
end

function CombatTutorialService:ResetTrainerDebounces(Trainer: Model)
	DebounceService:RemoveCharacterDebounces(Trainer)
	for _, Attribute in { "Blocking", "Rolling", "RollIFrame", "DeflectTime", "Attack", "Attacking", "StrongAttack" } do
		Trainer:SetAttribute(Attribute, false)
	end
end

function CombatTutorialService:StopTrainerBlock(Trainer: Model)
	if not Trainer or not Trainer.Parent then
		return
	end

	PostureService:Block(Trainer, false)
	Trainer:SetAttribute("Blocking", false)
	AnimationService:StopAnimationFind(Trainer, "Block")
end

function CombatTutorialService:TrainerBlock(Trainer: Model, CanDeflect: boolean, Duration: number?)
	if not Trainer or not Trainer.Parent then
		return
	end

	Trainer:SetAttribute("Rolling", false)
	DebounceService:RemoveDebounce(Trainer, "RollIFrame")

	if CanDeflect then
		PostureService:Block(Trainer, true)
	else
		DebounceService:RemoveDebounce(Trainer, "DeflectTime")
		Trainer:SetAttribute("Blocking", true)

		local CombatAnimations = WeaponService:GetCombatAnimationFolder(Trainer)
		if CombatAnimations and CombatAnimations:FindFirstChild("Block") then
			AnimationService:PlayAnimation(Trainer, CombatAnimations.Block)
		end
	end

	if Duration then
		task.delay(Duration, function()
			self:StopTrainerBlock(Trainer)
		end)
	end
end

function CombatTutorialService:TrainerDodge(Trainer: Model)
	if not Trainer or not Trainer.Parent then
		return
	end

	self:StopTrainerBlock(Trainer)
	DebounceService:RemoveDebounce(Trainer, "RollDebounce")

	local RollAction = GetTrainerAction(Trainer, "Roll")
	if RollAction then
		RollAction:Roll("Backward")
	end
end

function CombatTutorialService:FaceCombatants(PlayerCharacter: Model, Trainer: Model)
	local PlayerRoot = GetRootPart(PlayerCharacter)
	local TrainerRoot = GetRootPart(Trainer)
	if not PlayerRoot or not TrainerRoot then
		return
	end

	local PlayerPosition = PlayerRoot.Position
	local TrainerPosition = TrainerRoot.Position

	PlayerCharacter:PivotTo(LookAtFlat(PlayerPosition, TrainerPosition))
	Trainer:PivotTo(LookAtFlat(TrainerPosition, PlayerPosition))
end

function CombatTutorialService:KeepTrainerInRange(Session)
	local PlayerCharacter = GetCharacter(Session.Player)
	local Trainer = Session.Trainer
	local PlayerRoot = GetRootPart(PlayerCharacter)
	local TrainerRoot = GetRootPart(Trainer)
	if not PlayerCharacter or not Trainer or not PlayerRoot or not TrainerRoot then
		return
	end

	local Distance = (PlayerRoot.Position - TrainerRoot.Position).Magnitude
	if Distance > 8 then
		local TrainerPosition = (PlayerRoot.CFrame * CFrame.new(0, 0, -5)).Position
		TeleportCharacter(Trainer, LookAtFlat(TrainerPosition, PlayerRoot.Position))
	end

	self:FaceCombatants(PlayerCharacter, Trainer)
end

function CombatTutorialService:ConfigureTrainerForCurrentPhase(Session)
	local MissionData = GetMissionData(Session.Player)
	local Trainer = Session.Trainer
	if not MissionData or not Trainer or not Trainer.Parent then
		return
	end

	local Phase = GetPhase(MissionData)
	if not Phase then
		return
	end

	self:ResetTrainerDebounces(Trainer)
	Trainer:SetAttribute("Health", Trainer:GetAttribute("MaxHealth") or 250)
	Trainer:SetAttribute("Posture", 0)
	Trainer:SetAttribute("Downed", false)
	Trainer:SetAttribute("Died", false)
	Trainer:SetAttribute("Regeneration", 0)
	Trainer:SetAttribute("Stamina", math.huge)
	Trainer:SetAttribute("MaxStamina", math.huge)

	if not Trainer:GetAttribute("WeaponEquipped") then
		WeaponService:Equip(Trainer, true, 0)
	end

	if Phase.TrainerBlocks then
		Trainer:SetAttribute("MaxPosture", 30)
		self:TrainerBlock(Trainer, false)
	else
		Trainer:SetAttribute("MaxPosture", 100)
	end

	if Phase.TrainerDowned then
		Trainer:SetAttribute("Health", 1)
		Trainer:SetAttribute("Downed", true)
	end
end

function CombatTutorialService:RestorePlayerForTraining(Player: Player)
	local Character = GetCharacter(Player)
	if not Character then
		return false
	end

	CharacterService:EnableForceField(Character, false)
	Character:SetAttribute("Health", Character:GetAttribute("MaxHealth") or 100)
	Character:SetAttribute("Stamina", Character:GetAttribute("MaxStamina") or 100)
	Character:SetAttribute("Posture", 0)
	Character:SetAttribute("Blocking", false)
	Character:SetAttribute("Running", false)

	if not Character:GetAttribute("Weapon") then
		Character:SetAttribute("Weapon", "BasicKatana")
	end

	if not Character:GetAttribute("WeaponEquipped") then
		WeaponService:LoadWeapon(Character, Character:GetAttribute("Weapon"))
		WeaponService:Equip(Character, true, 0)
	end

	return true
end

function CombatTutorialService:GetTrainerMobName(): string
	local ServerAssets = ServerStorage:FindFirstChild("ServerAssets")
	local Mobs = ServerAssets and ServerAssets:FindFirstChild("Mobs")
	if Mobs and Mobs:FindFirstChild("Mikoto") then
		return "Mikoto"
	end

	return FALLBACK_TRAINER_MOB
end

function CombatTutorialService:SpawnTrainer(Player: Player, TrainerCFrame: CFrame): Model?
	local Trainer = MobService:CreateMob(self:GetTrainerMobName(), TRAINER_CONFIG)
	if not Trainer then
		warn("[CombatTutorialService] Could not create Mikoto combat tutorial trainer. Check ServerStorage.ServerAssets.Mobs.")
		return nil
	end

	Trainer.Name = "Mikoto"
	Trainer:SetAttribute("NoRewards", true)
	Trainer:SetAttribute("TutorialDojoTrainer", true)
	Trainer:SetAttribute("TutorialOwnerUserId", Player.UserId)
	Trainer:SetAttribute("WanderingNpc", true)
	Trainer:SetAttribute("Stunless", true)
	Trainer:SetAttribute("Regeneration", 0)

	if not Trainer:FindFirstChild("HitboxDetected") then
		AIService:PrepareMob(Trainer)
	end

	Trainer:PivotTo(TrainerCFrame)
	Trainer.Parent = workspace.Entity

	return Trainer
end

function CombatTutorialService:DefendAgainstPlayer(Session, Attacker: Model, Data: { any })
	local PlayerCharacter = GetCharacter(Session.Player)
	local Trainer = Session.Trainer
	if not PlayerCharacter or Attacker ~= PlayerCharacter or not Trainer or not Trainer.Parent then
		return
	end

	local MissionData = GetMissionData(Session.Player)
	local Phase = MissionData and GetPhase(MissionData)
	if not Phase or Phase.Mode ~= "PlayerHitTrainer" and not Phase.TrainerBlocks then
		return
	end

	if Phase.Action and Data.Action ~= Phase.Action then
		return
	end

	self:KeepTrainerInRange(Session)

	if Phase.TrainerBlocks then
		self:TrainerBlock(Trainer, false)
		return
	end

	if Phase.Key == "StrongAttack" then
		self:TrainerDodge(Trainer)
		return
	end

	local Progress = MissionData.CombatTutorialProgress or 0
	if Progress % 3 == 0 then
		self:TrainerBlock(Trainer, false, 0.55)
	elseif Progress % 3 == 1 then
		self:TrainerBlock(Trainer, true, 0.35)
	else
		self:TrainerDodge(Trainer)
	end
end

function CombatTutorialService:ProgressPhase(Player: Player, Amount: number?)
	local Session = Sessions[Player]
	local MissionData = GetMissionData(Player)
	if not Session or not MissionData or Session.Advancing then
		return false
	end

	local Phase, PhaseIndex = GetPhase(MissionData)
	if not Phase then
		return false
	end

	MissionData.CombatTutorialProgress =
		math.clamp((MissionData.CombatTutorialProgress or 0) + (Amount or 1), 0, Phase.TargetAmount)
	ObjectiveService:UpdateProgress(Player, MISSION_NAME, 1, Amount or 1)

	if MissionData.CombatTutorialProgress < Phase.TargetAmount then
		return true
	end

	Session.Advancing = true
	task.delay(0.65, function()
		if Sessions[Player] ~= Session then
			return
		end

		MissionData.CombatTutorialPhase = PhaseIndex + 1
		MissionData.CombatTutorialProgress = 0
		Session.Advancing = false

		if MissionData.CombatTutorialPhase > #Phases then
			QuestService:CallQuestFunction(Player, "FinishPractice")
			return
		end

		self:ConfigureTrainerForCurrentPhase(Session)
		self:ShowPhaseObjective(Player)
	end)

	return true
end

function CombatTutorialService:OnHitResolved(Session, Character: Model, Attacker: Model, Result: string, Data: { any })
	local Player = Session.Player
	local PlayerCharacter = GetCharacter(Player)
	local Trainer = Session.Trainer
	if not PlayerCharacter or not Trainer or not Trainer.Parent then
		return
	end

	local MissionData = GetMissionData(Player)
	local Phase = MissionData and GetPhase(MissionData)
	if not Phase then
		return
	end

	if Character == PlayerCharacter and Attacker == Trainer then
		PlayerCharacter:SetAttribute("Health", PlayerCharacter:GetAttribute("MaxHealth") or 100)
		PlayerCharacter:SetAttribute("Posture", 0)

		if Phase.Mode == "TrainerHitPlayer" and Result == Phase.Result then
			self:ProgressPhase(Player)
		end
		return
	end

	if Character ~= Trainer or Attacker ~= PlayerCharacter then
		return
	end

	if Phase.Mode ~= "PlayerHitTrainer" then
		return
	end

	if Phase.Action and Data.Action ~= Phase.Action then
		return
	end

	if Phase.Result and Result ~= Phase.Result then
		return
	end

	self:ProgressPhase(Player)
end

function CombatTutorialService:StartTrainerAttackLoop(Session)
	task.spawn(function()
		while Sessions[Session.Player] == Session and Session.Trainer and Session.Trainer.Parent do
			local MissionData = GetMissionData(Session.Player)
			local Phase = MissionData and GetPhase(MissionData)

			if Phase and Phase.TrainerAttacks and not Session.Advancing then
				self:KeepTrainerInRange(Session)
				task.wait(0.45)

				if Sessions[Session.Player] == Session and Session.Trainer and Session.Trainer.Parent then
					WeaponService:WeaponInput(Session.Trainer, "Attack", {
						RootCFrame = Session.Trainer:GetPivot(),
						Server = {
							AttackAdjustSpeed = 0.7,
						},
					})
				end

				task.wait(2.2)
			else
				task.wait(0.2)
			end
		end
	end)
end

function CombatTutorialService:BindSession(Session)
	local Trainer = Session.Trainer
	local PlayerCharacter = GetCharacter(Session.Player)
	local HitboxDetected = Trainer and Trainer:FindFirstChild("HitboxDetected")
	if HitboxDetected and HitboxDetected:IsA("BindableEvent") then
		AddConnection(Session, HitboxDetected.Event:Connect(function(Attacker: Model, Data: { any })
			self:DefendAgainstPlayer(Session, Attacker, Data or {})
		end))
	end

	AddConnection(Session, HitService.HitResolved.Event:Connect(function(Character, Attacker, Result, Data)
		self:OnHitResolved(Session, Character, Attacker, Result, Data or {})
	end))

	AddConnection(Session, ExecutionService.Executed.Event:Connect(function(Attacker: Model, Victim: Model)
		local PlayerCharacter = GetCharacter(Session.Player)
		if PlayerCharacter and Attacker == PlayerCharacter and Victim == Session.Trainer then
			local MissionData = GetMissionData(Session.Player)
			local Phase = MissionData and GetPhase(MissionData)
			if Phase and Phase.Mode == "TrainerExecuted" then
				self:ProgressPhase(Session.Player)
			end
		end
	end))

	AddConnection(Session, Trainer:GetAttributeChangedSignal("PostureBreak"):Connect(function()
		if not Trainer:GetAttribute("PostureBreak") then
			return
		end

		local MissionData = GetMissionData(Session.Player)
		local Phase = MissionData and GetPhase(MissionData)
		if Phase and Phase.Mode == "TrainerPostureBreak" then
			self:ProgressPhase(Session.Player)
		end
	end))

	if PlayerCharacter then
		AddConnection(Session, PlayerCharacter:GetAttributeChangedSignal("Died"):Connect(function()
			if PlayerCharacter:GetAttribute("Died") then
				task.delay(15, function()
					self:EndTraining(Session.Player, false)
				end)
			end
		end))

		AddConnection(Session, PlayerCharacter:GetPropertyChangedSignal("Parent"):Connect(function()
			if not PlayerCharacter.Parent then
				self:EndTraining(Session.Player, false)
			end
		end))
	end

	AddConnection(Session, RunService.Heartbeat:Connect(function()
		local Character = GetCharacter(Session.Player)
		local PlayerSpawn = Session.PlayerSpawn
		local RootPart = GetRootPart(Character)
		local SpawnPosition = GetPivotPosition(PlayerSpawn)
		if not Character or not RootPart or not SpawnPosition then
			return
		end

		local DistanceFromDojo = (RootPart.Position - SpawnPosition).Magnitude
		if DistanceFromDojo > DOJO_BOUNDARY_DISTANCE then
			TeleportCharacter(Character, Session.PlayerCFrame)
		end
	end))
end

function CombatTutorialService:EndTraining(Player: Player, TeleportBack: boolean?)
	local Session = Sessions[Player]
	if not Session then
		return true
	end

	Sessions[Player] = nil
	DisconnectSession(Session)

	if Session.Trainer and Session.Trainer.Parent then
		Session.Trainer:Destroy()
	end

	DestroyTrainingDojo(Session.Dojo)
	Player:SetAttribute("InDojo", false)
	Player:SetAttribute("InCombat", false)

	if TeleportBack then
		local Character = GetCharacter(Player)
		if Character and Session.ReturnCFrame then
			local RootPart = GetRootPart(Character)
			if RootPart then
				RootPart.Anchored = true
			end

			Player:RequestStreamAroundAsync(Session.ReturnCFrame.Position, 5)
			TeleportCharacter(Character, Session.ReturnCFrame)

			if RootPart then
				task.delay(2 / 60, function()
					if RootPart.Parent then
						RootPart.Anchored = false
					end
				end)
			end
		end
	end

	return true
end

function CombatTutorialService:StartTraining(Player: Player, ResetProgress: boolean?)
	local MissionData = GetMissionData(Player)
	local Character = GetCharacter(Player)
	if not MissionData or not Character then
		return false
	end

	local ExistingSession = Sessions[Player]
	if Player:GetAttribute("InDojo") and not ExistingSession then
		return false
	end

	local ReturnCFrame = ExistingSession and ExistingSession.ReturnCFrame or Character:GetPivot()
	self:EndTraining(Player, false)

	if ResetProgress or typeof(MissionData.CombatTutorialPhase) ~= "number" then
		MissionData.CombatTutorialPhase = 1
		MissionData.CombatTutorialProgress = 0
	elseif MissionData.CombatTutorialPhase > #Phases then
		QuestService:CallQuestFunction(Player, "FinishPractice")
		return true
	end

	local Dojo = CreateTrainingDojo()
	if not Dojo then
		return false
	end

	local Spawns = Dojo:FindFirstChild("Spawns")
	local PlayerSpawn = Spawns and Spawns:FindFirstChild("Player")
	local TrainerSpawn = Spawns and Spawns:FindFirstChild("Mob")
	if not PlayerSpawn or not TrainerSpawn then
		warn("[CombatTutorialService] Dojo is missing Spawns.Player or Spawns.Mob.")
		DestroyTrainingDojo(Dojo)
		return false
	end

	local PlayerSpawnPosition = GetPivotPosition(PlayerSpawn)
	if not PlayerSpawnPosition or not GetPivotPosition(TrainerSpawn) then
		warn("[CombatTutorialService] Dojo spawns must be BaseParts or Models.")
		DestroyTrainingDojo(Dojo)
		return false
	end

	local PlayerCFrame = PlayerSpawn:GetPivot() * CFrame.Angles(0, math.rad(90), 0)
	local TrainerCFrame = TrainerSpawn:GetPivot() * CFrame.Angles(0, math.rad(-90), 0)
	local Trainer = self:SpawnTrainer(Player, TrainerCFrame)
	if not Trainer then
		DestroyTrainingDojo(Dojo)
		return false
	end

	if not self:RestorePlayerForTraining(Player) then
		Trainer:Destroy()
		DestroyTrainingDojo(Dojo)
		return false
	end

	Player:SetAttribute("InDojo", true)
	local RootPart = GetRootPart(Character)
	if RootPart then
		RootPart.Anchored = true
	end
	if PlayerSpawnPosition then
		Player:RequestStreamAroundAsync(PlayerSpawnPosition, 5)
	end
	TeleportCharacter(Character, PlayerCFrame)
	if RootPart then
		task.delay(2 / 60, function()
			if RootPart.Parent then
				RootPart.Anchored = false
			end
		end)
	end

	local Session = {
		Player = Player,
		Trainer = Trainer,
		Dojo = Dojo,
		PlayerSpawn = PlayerSpawn,
		PlayerCFrame = PlayerCFrame,
		Connections = {},
		ReturnCFrame = ReturnCFrame,
		Advancing = false,
	}

	Sessions[Player] = Session
	self:BindSession(Session)
	self:ConfigureTrainerForCurrentPhase(Session)
	QuestService:RemoveTarget(Player, "Mikoto")
	self:ShowPhaseObjective(Player)
	self:StartTrainerAttackLoop(Session)
	self:KeepTrainerInRange(Session)

	return true
end

function CombatTutorialService:ResetMissionOnQuit(Player: Player)
	local Session = Sessions[Player]
	if not Session then
		return false
	end

	local PlayerData = GetPlayerMissionSave(Player)
	if not PlayerData then
		return false
	end

	PlayerData.Story = PlayerData.Story or {}
	PlayerData.Story[MISSION_NAME] = nil

	if PlayerData.Quest and PlayerData.Quest.Name == MISSION_NAME then
		QuestService:RemoveQuest(Player)
	end

	ObjectiveService:ClearObjective(Player, MISSION_NAME)
	QuestService:RemoveTarget(Player, "Mikoto")

	return true
end

function CombatTutorialService:HandlePlayerLeaving(Player: Player)
	self:ResetMissionOnQuit(Player)
	self:EndTraining(Player, false)
end

function CombatTutorialService.KnitInit()
	TutorialService = Knit.GetService("TutorialService")
	QuestService = Knit.GetService("QuestService")
	ObjectiveService = Knit.GetService("ObjectiveService")
	MobService = Knit.GetService("MobService")
	AIService = Knit.GetService("AIService")
	CharacterService = Knit.GetService("CharacterService")
	WeaponService = Knit.GetService("WeaponService")
	PostureService = Knit.GetService("PostureService")
	DebounceService = Knit.GetService("DebounceService")
	AnimationService = Knit.GetService("AnimationService")
	HitService = Knit.GetService("HitService")
	ExecutionService = Knit.GetService("ExecutionService")
end

function CombatTutorialService.KnitStart()
	Players.PlayerRemoving:Connect(function(Player)
		CombatTutorialService:HandlePlayerLeaving(Player)
	end)
end

return CombatTutorialService
