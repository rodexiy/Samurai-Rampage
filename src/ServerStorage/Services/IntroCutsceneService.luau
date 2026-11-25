local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local IntroCutsceneConfig = require(ReplicatedStorage.Shared.IntroCutsceneConfig)
local TeleportCharacter = require(ReplicatedStorage.Shared.Utils.TeleportCharacter)

local IntroCutsceneService = Knit.CreateService({
	Name = "IntroCutsceneService",
	Client = {
		OpeningStarted = Knit.CreateSignal(),
		RequestOpening = Knit.CreateSignal(),
		OpeningFinished = Knit.CreateSignal(),
		DrawSword = Knit.CreateSignal(),
		CombatStarted = Knit.CreateSignal(),
		TsunamiParry = Knit.CreateSignal(),
		TsunamiStarted = Knit.CreateSignal(),
		TsunamiRevealed = Knit.CreateSignal(),
		TsunamiFinished = Knit.CreateSignal(),
		WakeUpStarted = Knit.CreateSignal(),
		WakeUpFinished = Knit.CreateSignal(),
	},
})

type Session = {
	Ship: Model,
	Spawn: BasePart,
	Slot: number,
	Radius: number,
	Character: Model?,
	Boss: Model?,
	Token: string?,
	Phase: string?,
	EarliestFinish: number?,
	PreviousCantAttack: any,
	PreviousWakeUpForceField: boolean?,
	HealthConnections: { RBXScriptConnection }?,
}

local DataService
local PlaceService
local MobService
local AIService
local WeaponService
local InCombatService
local CharacterService
local InventoryService
local ItemService
local SkillService
local RagdollService
local DebounceService
local BuffService
local IntroCombatTutorialService
local Sessions: { [Player]: Session } = {}
local ForcedReplays: { [Player]: boolean } = {}
local OccupiedSlots: { [number]: boolean } = {}
local ShipsFolder: Folder
local OceanOrigin: Vector3?

local function StopCombatTriggers(Session: Session)
	for _, Connection in Session.HealthConnections or {} do
		Connection:Disconnect()
	end
	Session.HealthConnections = nil
	for _, Actor in { Session.Character, Session.Boss } do
		if Actor and Actor.Parent then
			Actor:SetAttribute("IntroHealthFloor", nil)
		end
	end
end

local function ClearBoss(Session: Session)
	local Boss = Session.Boss
	Session.Boss = nil
	if Boss then
		Boss:SetAttribute("IntroOpening", true)
		local Runner = Boss:FindFirstChild("Runner")
		if Runner then
			Runner:SetAttribute("Enabled", false)
		end
		Boss:Destroy()
	end
end

local function SetOpeningLock(Character: Model, Locked: boolean)
	Character:SetAttribute("IntroOpening", Locked)
	Character:SetAttribute("CameraCutscene", Locked)
	Character:SetAttribute("SkillLockMovement", Locked)
	Character:SetAttribute("Running", false)

	local Root = Character.PrimaryPart
	if Root then
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
		Root.Anchored = Locked
	end
end

local function ApplyParryRecoil(Actor: Model, Opponent: Model, Duration: number)
	local Root = Actor.PrimaryPart
	if not Root then
		return
	end

	Root.Anchored = false
	local Away = (Root.Position - Opponent:GetPivot().Position) * Vector3.new(1, 0, 1)
	Away = if Away.Magnitude > 0.001 then Away.Unit else -Root.CFrame.LookVector
	local Recoil = Instance.new("BodyVelocity")
	Recoil.Name = "IntroHeavyParryKnockback"
	Recoil.MaxForce = Vector3.new(1, 0, 1) * 5000 * Root.AssemblyMass
	Recoil.Velocity = Away * 25
	Recoil.P = 850
	Recoil.Parent = Root
	Debris:AddItem(Recoil, math.min(0.5, Duration))
end

local function FindPath(Root: Instance, Path: { string }): Instance?
	local Current: Instance? = Root
	for _, Name in Path do
		Current = Current and Current:FindFirstChild(Name)
	end

	return Current
end

local function GetOceanOrigin(): Vector3
	if OceanOrigin then
		return OceanOrigin
	end

	local MinimumX = IntroCutsceneConfig.OceanOrigin.X
	for _, Name in IntroCutsceneConfig.MapRootNames do
		local Root = workspace:FindFirstChild(Name)
		if not Root then
			continue
		end

		for _, Instance in Root:QueryDescendants("BasePart") do
			local Part = Instance :: BasePart
			local HalfSize = Part.Size * 0.5
			local Rotation = Part.CFrame
			local ExtentX = math.abs(Rotation.XVector.X) * HalfSize.X
				+ math.abs(Rotation.YVector.X) * HalfSize.Y
				+ math.abs(Rotation.ZVector.X) * HalfSize.Z
			MinimumX = math.max(MinimumX, Part.Position.X + ExtentX + IntroCutsceneConfig.MinimumMapDistance)
		end
	end

	OceanOrigin = Vector3.new(MinimumX, IntroCutsceneConfig.ShipHeight, IntroCutsceneConfig.OceanOrigin.Z)
	return OceanOrigin
end

local function GetShipRadius(Ship: Model): number
	local Bounds, Size = Ship:GetBoundingBox()
	return (Bounds.Position - Ship:GetPivot().Position).Magnitude + Size.Magnitude * 0.5
end

local function GetAvailableSlot(): number
	local Slot = 0
	while OccupiedSlots[Slot] do
		Slot += 1
	end

	return Slot
end

local function GetShipCFrame(Slot: number, Radius: number): CFrame
	local Columns = math.max(1, math.floor(IntroCutsceneConfig.ShipsPerColumn))
	local Spacing = math.max(IntroCutsceneConfig.MinimumShipDistance, Radius * 2, IntroCutsceneConfig.ExclusionRadius * 2)
	local Position = GetOceanOrigin() + Vector3.new(
		Radius + math.floor(Slot / Columns) * Spacing,
		0,
		(Slot % Columns - (Columns - 1) * 0.5) * Spacing
	)

	return CFrame.new(Position) * CFrame.Angles(0, math.rad(IntroCutsceneConfig.ShipRotationDegrees), 0)
end

function IntroCutsceneService:ShouldPlay(Player: Player): boolean
	if (not IntroCutsceneConfig.Enabled and not ForcedReplays[Player])
		or PlaceService:IsTrading() or PlaceService:IsHub() or PlaceService:IsArena() then
		return false
	end

	local PlayerData = DataService:GetData(Player)
	return PlayerData ~= nil and (ForcedReplays[Player] == true or PlayerData.IntroCutsceneCompleted ~= true)
end

function IntroCutsceneService:Cleanup(Player: Player)
	ForcedReplays[Player] = nil
	IntroCombatTutorialService:Cancel(Player)
	local Session = Sessions[Player]
	if Session then
		Sessions[Player] = nil
		OccupiedSlots[Session.Slot] = nil
		StopCombatTriggers(Session)
		ClearBoss(Session)
		if Session.Character and Session.Character.Parent then
			Session.Character:SetAttribute("IntroWakeUp", false)
			SetOpeningLock(Session.Character, false)
			if Session.PreviousWakeUpForceField ~= nil then
				CharacterService:EnableForceField(Session.Character, Session.PreviousWakeUpForceField)
			end
		end
		if Session.Character then
			Player:SetAttribute("CantAttack", Session.PreviousCantAttack)
		end
		Session.Ship:Destroy()
	end

	Player:SetAttribute("InIntroCutscene", false)
	Player:SetAttribute("InIntroStorm", false)
end

function IntroCutsceneService:PrepareCharacter(Player: Player, Character: Model)
	local Session = Sessions[Player]
	if not Session then
		return
	end

	IntroCombatTutorialService:Cancel(Player)
	StopCombatTriggers(Session)
	ClearBoss(Session)
	if Session.Character then
		Player:SetAttribute("CantAttack", Session.PreviousCantAttack)
	end
	Session.Character = Character
	Session.Token = HttpService:GenerateGUID(false)
	Session.Phase = "Preparing"
	Session.EarliestFinish = nil
	Session.PreviousCantAttack = Player:GetAttribute("CantAttack")

	if Character:GetAttribute("WeaponType") ~= "Katana" then
		local Item = InventoryService:GetPlayerItemByName(Player, IntroCutsceneConfig.StarterWeapon)
		if not Item then
			InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem(IntroCutsceneConfig.StarterWeapon, 1))
			Item = InventoryService:GetPlayerItemByName(Player, IntroCutsceneConfig.StarterWeapon)
		end
		if Item then
			InventoryService:EquipUnequipItem(Player, Item.Id or Item.Name)
		end
	end

	Player:SetAttribute("CantAttack", true)
	SetOpeningLock(Character, true)
end

function IntroCutsceneService:TryInterceptHit(Target: Model, Damage: number, Attacker: Model?): boolean
	local Floor = Target:GetAttribute("IntroHealthFloor")
	local Health = Target:GetAttribute("Health")
	if typeof(Floor) ~= "number" or typeof(Health) ~= "number" or typeof(Damage) ~= "number" or Damage ~= Damage
		or Damage <= 0 or Damage == math.huge or Health - Damage > Floor then
		return false
	end

	local Player = Players:GetPlayerFromCharacter(Target)
	local OwnerId = Target:GetAttribute("IntroOwnerUserId")
	if not Player and typeof(OwnerId) == "number" then
		Player = Players:GetPlayerByUserId(OwnerId)
	end
	local Session = Player and Sessions[Player]
	if not Player or not Session or Session.Phase ~= "Combat" then
		return false
	end

	local IsPlayer = Target == Session.Character
	if not IsPlayer and Target ~= Session.Boss then
		return false
	end
	local Opponent = if IsPlayer then Session.Boss else Session.Character
	if Attacker and Attacker ~= Opponent then
		return false
	end

	return self:StartTsunami(Player, if IsPlayer then "PlayerHealth" else "BossHealth")
end

function IntroCutsceneService:StartTsunami(Player: Player, Reason: string): boolean
	local Session = Sessions[Player]
	if not Session or Session.Phase ~= "Combat" then
		return false
	end
	local Character, Boss = Session.Character, Session.Boss
	if not Character or Player.Character ~= Character or not Character.Parent or not Boss or not Boss.Parent then
		return false
	end

	Session.Phase = "TsunamiParry"
	Character:SetAttribute("CameraCutscene", true)
	BuffService:RemoveBuffsByType(Character, "Burn")
	Player:SetAttribute("CantAttack", true)
	Boss:SetAttribute("WanderingNpc", true)
	for _, Actor in { Character, Boss } do
		Actor:SetAttribute("IntroOpening", true)
		if Actor:GetAttribute("Ragdoll") then
			RagdollService:Unragdoll(Actor)
		end
		SkillService:ClearSkillData(Actor)
		Actor:SetAttribute("SkillState", nil)
		Actor:SetAttribute("Blocking", false)
		Actor:SetAttribute("SkillLockMovement", true)
		Actor:SetAttribute("Running", false)
	end
	SetOpeningLock(Boss, true)
	local Runner = Boss:FindFirstChild("Runner")
	if Runner then
		Runner:SetAttribute("Enabled", false)
	end
	local Align = Boss.PrimaryPart and Boss.PrimaryPart:FindFirstChild("LookPlayer") :: AlignOrientation?
	if Align then
		Align.Enabled = false
	end
	StopCombatTriggers(Session)

	local Duration = IntroCutsceneConfig.Tsunami.HeavyParryTime
	for _, Actor in { Character, Boss } do
		DebounceService:AddDebounce(Actor, "HeavyDeflect", Duration)
		local Opponent = if Actor == Character then Boss else Character
		ApplyParryRecoil(Actor, Opponent, Duration)
	end
	self.Client.TsunamiParry:Fire(Player, Session.Token, Character, Boss)

	local Token = Session.Token
	task.delay(Duration, function()
		if Sessions[Player] ~= Session or Session.Token ~= Token or Session.Phase ~= "TsunamiParry"
			or Player.Character ~= Character or not Character.Parent or not Boss.Parent then
			return
		end

		Session.Phase = "Tsunami"
		self.Client.TsunamiStarted:Fire(Player, Token, Character, Boss, Session.Ship.Name, Reason)

		task.delay(IntroCutsceneConfig.Tsunami.WarningTime, function()
			if Sessions[Player] == Session and Session.Token == Token then
				IntroCutsceneService:StageTsunami(Player, Token)
			end
		end)
	end)
	return true
end

function IntroCutsceneService:ArmCombatTriggers(Player: Player, Session: Session)
	StopCombatTriggers(Session)
	Session.HealthConnections = {}
	local Config = IntroCutsceneConfig.Tsunami

	local function WatchHealth(Actor: Model, Ratio: number, Reason: string)
		local function CheckHealth()
			if Sessions[Player] ~= Session or Session.Phase ~= "Combat" then
				return
			end

			local Maximum = Actor:GetAttribute("MaxHealth")
			local Health = Actor:GetAttribute("Health")
			if typeof(Maximum) ~= "number" or Maximum <= 0 or typeof(Health) ~= "number" then
				return
			end

			local Threshold = math.max(1, Maximum * Ratio)
			Actor:SetAttribute("IntroHealthFloor", Threshold)
			if Health <= Threshold then
				IntroCutsceneService:StartTsunami(Player, Reason)
			end
		end

		table.insert(Session.HealthConnections, Actor:GetAttributeChangedSignal("Health"):Connect(CheckHealth))
		table.insert(Session.HealthConnections, Actor:GetAttributeChangedSignal("MaxHealth"):Connect(CheckHealth))
		CheckHealth()
	end

	WatchHealth(assert(Session.Character, "Intro character is missing"), Config.PlayerHealthRatio, "PlayerHealth")
	if Session.Phase == "Combat" then
		WatchHealth(assert(Session.Boss, "Intro boss is missing"), Config.BossHealthRatio, "BossHealth")
	end
end

function IntroCutsceneService:StageTsunami(Player: Player, Token: string)
	local Session = Sessions[Player]
	if not Session or Session.Token ~= Token or Session.Phase ~= "Tsunami" then
		return
	end
	local Character, Boss = Session.Character, Session.Boss
	if not Character or Player.Character ~= Character or not Character.Parent or not Boss or not Boss.Parent then
		return
	end

	Session.Phase = "TsunamiReveal"

	for _, Actor in { Character, Boss } do
		DebounceService:RemoveCharacterDebounces(Actor)
		if Actor:GetAttribute("Ragdoll") then
			RagdollService:Unragdoll(Actor)
		end
		SetOpeningLock(Actor, true)
	end
	local Tsunami = IntroCutsceneConfig.Tsunami
	Session.EarliestFinish = os.clock() + Tsunami.Umibozu.RiseTime + Tsunami.Umibozu.HoldTime + Tsunami.ApproachTime
	self.Client.TsunamiRevealed:Fire(Player, Token, Character, Boss, Session.Ship.Name)
end

function IntroCutsceneService:SendOpening(Player: Player)
	local Session = Sessions[Player]
	if not Session or Session.Phase ~= "Opening" or not Session.Boss then
		return
	end

	if not Session.EarliestFinish then
		local Opening = IntroCutsceneConfig.Opening
		Session.EarliestFinish = os.clock() + Opening.FadeTime + Opening.EstablishTime
			+ Opening.BossLineTime + Opening.PlayerLineTime + Opening.TransitionTime
	end
	self.Client.OpeningStarted:Fire(Player, Session.Token, Session.Character, Session.Ship.Name, Session.Boss.Name)
end

function IntroCutsceneService:StartOpening(Player: Player, Character: Model)
	local Session = Sessions[Player]
	if not Session or Session.Character ~= Character then
		return
	end

	local EnemySpawn = FindPath(Session.Ship, IntroCutsceneConfig.EnemySpawnPath) :: BasePart?
	assert(EnemySpawn and EnemySpawn:IsA("BasePart"), "Intro ship requires Spawn.Enemy")
	local EnemyFrame = EnemySpawn.CFrame * IntroCutsceneConfig.EnemySpawnOffset
	local PlayerPosition = Character:GetPivot().Position
	local EnemyPosition = EnemyFrame.Position
	Character:PivotTo(CFrame.lookAt(PlayerPosition, Vector3.new(EnemyPosition.X, PlayerPosition.Y, EnemyPosition.Z)))
	EnemyFrame = CFrame.lookAt(EnemyPosition, Vector3.new(PlayerPosition.X, EnemyPosition.Y, PlayerPosition.Z))

	local Boss = MobService:CreateMob(IntroCutsceneConfig.BossName, IntroCutsceneConfig.BossConfig)
	assert(Boss and Boss.PrimaryPart, "Intro boss could not be created")
	Boss.Name = "IntroBoss_" .. Player.UserId
	Boss:SetAttribute("DisplayName", IntroCutsceneConfig.BossName)
	Boss:SetAttribute("IntroOwnerUserId", Player.UserId)
	Boss:SetAttribute("WanderingNpc", true)
	SetOpeningLock(Boss, true)
	Boss:PivotTo(EnemyFrame)
	Boss.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	Boss.Parent = workspace.Entity
	Boss:AddPersistentPlayer(Player)
	Session.Boss = Boss
	Session.Phase = "Opening"
	self:SendOpening(Player)
end

function IntroCutsceneService:FinishOpening(Player: Player, Token: string)
	local Session = Sessions[Player]
	if not Session or Session.Token ~= Token or Session.Phase ~= "Opening" or not Session.EarliestFinish then
		return
	end
	local Remaining = Session.EarliestFinish - os.clock()
	if Remaining > 0 then
		Session.Phase = "OpeningFinishPending"
		task.delay(Remaining, function()
			if Sessions[Player] ~= Session or Session.Token ~= Token or Session.Phase ~= "OpeningFinishPending" then
				return
			end

			Session.Phase = "Opening"
			self:FinishOpening(Player, Token)
		end)
		return
	end

	local Character, Boss = Session.Character, Session.Boss
	if not Character or Player.Character ~= Character or not Character.Parent or not Boss or not Boss.Parent then
		return
	end

	Session.Phase = "Drawing"
	for _, Actor in { Character, Boss } do
		Actor:SetAttribute("IntroOpening", false)
		WeaponService:Equip(Actor, true, 0)
		Actor:SetAttribute("IntroOpening", true)
	end

	InCombatService:SetInCombat(Character, true, Boss)
	self.Client.DrawSword:Fire(Player, Token, Character, Boss)

	task.delay(IntroCutsceneConfig.Opening.DrawTime, function()
		if Sessions[Player] ~= Session or Session.Token ~= Token or Player.Character ~= Character
			or not Character.Parent or not Boss.Parent then
			return
		end

		Session.Phase = "Tutorial"
		self:StartCombat(Player, Token)
	end)
end

function IntroCutsceneService:StartCombat(Player: Player, Token: string)
	local Session = Sessions[Player]
	if not Session or Session.Token ~= Token or Session.Phase ~= "Tutorial" then
		return
	end
	local Character, Boss = Session.Character, Session.Boss
	if not Character or Player.Character ~= Character or not Character.Parent or not Boss or not Boss.Parent then
		return
	end

	AIService:AddAI(Boss, IntroCutsceneConfig.BossRunner, IntroCutsceneConfig.BossConfig)
	InCombatService:SetInCombat(Character, true, Boss)
	Session.Phase = "Combat"
	SetOpeningLock(Character, false)
	SetOpeningLock(Boss, false)
	Player:SetAttribute("CantAttack", Session.PreviousCantAttack)
	CharacterService:EnableForceField(Character, false)
	MobService:SetNetworkOwner(Boss)
	Boss:SetAttribute("WanderingNpc", false)
	local Armed = IntroCombatTutorialService:Arm(Player, Character, Boss, Session.Ship, Token, function()
		if Sessions[Player] == Session and Session.Token == Token and Session.Phase == "Combat" then
			InCombatService:SetInCombat(Character, true, Boss)
			self:ArmCombatTriggers(Player, Session)
		end
	end)
	if not Armed then
		self:ArmCombatTriggers(Player, Session)
	end
	self.Client.CombatStarted:Fire(Player, Token, Character, Boss)
end

function IntroCutsceneService:GetSpawnCFrame(Player: Player): CFrame?
	if not self:ShouldPlay(Player) then
		return nil
	end

	local Session = Sessions[Player]
	if not Session then
		local Template = ReplicatedStorage.Assets.Models.TutorialCutscene:FindFirstChild(IntroCutsceneConfig.ShipName) :: Model?
		assert(Template and Template:IsA("Model"), "Intro cutscene ship template is missing")

		local Ship = Template:Clone()
		local Spawn = FindPath(Ship, IntroCutsceneConfig.PlayerSpawnPath) :: BasePart?
		if not Spawn or not Spawn:IsA("BasePart") then
			Ship:Destroy()
			error("Intro cutscene ship requires a Spawn.Player part")
		end

		local Slot = GetAvailableSlot()
		local Radius = GetShipRadius(Ship)
		Ship.Name = "Ship_" .. Player.UserId
		Ship:SetAttribute("OwnerUserId", Player.UserId)
		Ship.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer

		if IntroCutsceneConfig.AnchorShip then
			for _, Instance in Ship:QueryDescendants("BasePart") do
				local Part = Instance :: BasePart
				Part.Anchored = true
			end
		end

		-- Spawn markers position characters; they must never become automatic spawns.
		for _, Instance in Ship:QueryDescendants("SpawnLocation") do
			local SpawnLocation = Instance :: SpawnLocation
			SpawnLocation.Enabled = false
		end

		Ship:PivotTo(GetShipCFrame(Slot, Radius))
		Ship.Parent = ShipsFolder
		Ship:AddPersistentPlayer(Player)

		Session = { Ship = Ship, Spawn = Spawn, Slot = Slot, Radius = math.max(Radius, IntroCutsceneConfig.ExclusionRadius) }
		Sessions[Player] = Session
		OccupiedSlots[Slot] = true
	end

	Player:SetAttribute("InIntroStorm", true)
	Player:SetAttribute("InIntroCutscene", true)
	return Session.Spawn.CFrame * IntroCutsceneConfig.PlayerSpawnOffset
end

function IntroCutsceneService:PrepareWakeUp(Player: Player, Session: Session)
	local Character = assert(Session.Character, "Intro wake-up requires a character")
	IntroCombatTutorialService:Cancel(Player)
	StopCombatTriggers(Session)
	SkillService:ClearSkillData(Character)
	DebounceService:RemoveCharacterDebounces(Character)
	BuffService:RemoveBuffsByType(Character, "Burn")

	Session.PreviousWakeUpForceField = Character:GetAttribute("ForceField") == true
	Character:SetAttribute("IntroWakeUp", true)
	Player:SetAttribute("CantAttack", true)
	SetOpeningLock(Character, true)
	CharacterService:EnableForceField(Character, true)
	InCombatService:SetInCombat(Character, false)
	WeaponService:SetEquippedState(Character, false)
	ClearBoss(Session)

	Character:SetAttribute("Health", Character:GetAttribute("MaxHealth"))
	Character:SetAttribute("Stamina", Character:GetAttribute("MaxStamina"))
	Character:SetAttribute("Posture", 0)
end

function IntroCutsceneService:StartWakeUp(Player: Player, Token: string)
	local Session = Sessions[Player]
	local Character = Player.Character
	if not Session or Session.Token ~= Token or Session.Phase ~= "Blackout"
		or not Character or Session.Character ~= Character or not Character.PrimaryPart then
		return
	end

	local Config = IntroCutsceneConfig.WakeUp
	local Marker = FindPath(workspace, Config.SpawnPath) :: BasePart?
	if not Marker or not Marker:IsA("BasePart") then
		warn("Intro wake-up requires workspace.Important.BeachSpawn")
		self:Cleanup(Player)
		return
	end

	Session.Phase = "Teleporting"
	SetOpeningLock(Character, true)
	local SpawnFrame = CharacterService:GetGroundedCFrame(Character, Marker.CFrame, { Marker })
	TeleportCharacter(Character, SpawnFrame)
	if Sessions[Player] ~= Session or Player.Character ~= Character or not Character.Parent then
		return
	end

	Session.Phase = "WakingUp"
	Session.EarliestFinish = os.clock() + Config.FadeTime + Config.AnimationDuration + Config.TransitionTime
	self.Client.WakeUpStarted:Fire(Player, Token, Character, Character:GetPivot())
end

-- Completion stays gated by the server's phase, character and cinematic deadline.
function IntroCutsceneService:Complete(Player: Player): boolean
	local Session = Sessions[Player]
	local PlayerData = DataService:GetData(Player)
	local Character = Player.Character
	if not Session or Session.Phase ~= "WakingUp" or not Session.EarliestFinish
		or os.clock() < Session.EarliestFinish or not PlayerData or not Character
		or Session.Character ~= Character or not Character.PrimaryPart or not Character:GetAttribute("Loaded") then
		return false
	end

	PlayerData.IntroCutsceneCompleted = true
	DataService:Checkpoint(Player)
	self:Cleanup(Player)
	return true
end

function IntroCutsceneService:FinishWakeUp(Player: Player, Token: string)
	local Session = Sessions[Player]
	if not Session or Session.Token ~= Token or Session.Phase ~= "WakingUp" or not Session.EarliestFinish then
		return
	end

	local Remaining = Session.EarliestFinish - os.clock()
	if Remaining > 0 then
		Session.Phase = "WakeUpFinishPending"
		task.delay(Remaining, function()
			if Sessions[Player] == Session and Session.Token == Token and Session.Phase == "WakeUpFinishPending" then
				Session.Phase = "WakingUp"
				self:Complete(Player)
			end
		end)
		return
	end

	self:Complete(Player)
end

function IntroCutsceneService:Replay(Player: Player): (boolean, string?)
	if not DataService:IsDataLoaded(Player) or Player.Parent ~= Players then
		return false, "Player data is not loaded."
	end
	if PlaceService:IsTrading() or PlaceService:IsHub() or PlaceService:IsArena() then
		return false, "The intro can only run in the main world."
	end

	self:Cleanup(Player)
	ForcedReplays[Player] = true
	local Success, Error = pcall(function()
		CharacterService:LoadCharacter(Player)
	end)
	if not Success then
		self:Cleanup(Player)
		warn("Unable to replay intro:", Error)
		return false, "Unable to prepare the intro character."
	end

	return true
end

function IntroCutsceneService:CheckIntruders()
	for _, Player in Players:GetPlayers() do
		local Character = Player.Character
		local Root = Character and Character.PrimaryPart
		if not Root then
			continue
		end

		for Owner, Session in Sessions do
			if Owner ~= Player and (Root.Position - Session.Ship:GetPivot().Position).Magnitude <= Session.Radius then
				Player:Kick(IntroCutsceneConfig.IntrusionKickMessage)
				break
			end
		end
	end
end

function IntroCutsceneService.KnitInit()
	DataService = Knit.GetService("DataService")
	PlaceService = Knit.GetService("PlaceService")
	MobService = Knit.GetService("MobService")
	AIService = Knit.GetService("AIService")
	WeaponService = Knit.GetService("WeaponService")
	InCombatService = Knit.GetService("InCombatService")
	CharacterService = Knit.GetService("CharacterService")
	InventoryService = Knit.GetService("InventoryService")
	ItemService = Knit.GetService("ItemService")
	SkillService = Knit.GetService("SkillService")
	RagdollService = Knit.GetService("RagdollService")
	DebounceService = Knit.GetService("DebounceService")
	BuffService = Knit.GetService("BuffService")
	IntroCombatTutorialService = Knit.GetService("IntroCombatTutorialService")

	ShipsFolder = Instance.new("Folder")
	ShipsFolder.Name = IntroCutsceneConfig.ShipsFolderName
	ShipsFolder.Parent = workspace
end

function IntroCutsceneService.KnitStart()
	IntroCutsceneService.Client.TsunamiFinished:Connect(function(Player: Player, Token: string)
		local Session = Sessions[Player]
		if Session and Session.Token == Token and Session.Phase == "TsunamiReveal"
			and Session.EarliestFinish and os.clock() >= Session.EarliestFinish then
			Session.Phase = "Blackout"
			Player:SetAttribute("InIntroStorm", false)
			local Direction = Session.Ship:GetPivot().RightVector * Vector3.new(1, 0, 1)
			for _, Actor in { Session.Character, Session.Boss } do
				if Actor and Actor.Parent then
					local Position = Actor:GetPivot().Position
					Actor:PivotTo(CFrame.lookAt(Position, Position + Direction))
				end
			end

			IntroCutsceneService:PrepareWakeUp(Player, Session)
			task.delay(IntroCutsceneConfig.WakeUp.BlackoutTime, function()
				IntroCutsceneService:StartWakeUp(Player, Token)
			end)
		end
	end)
	IntroCutsceneService.Client.WakeUpFinished:Connect(function(Player: Player, Token: string)
		if typeof(Token) == "string" then
			IntroCutsceneService:FinishWakeUp(Player, Token)
		end
	end)

	IntroCutsceneService.Client.RequestOpening:Connect(function(Player: Player, Character: Model)
		local Session = Sessions[Player]
		if Session and Character == Player.Character and Session.Character == Character then
			IntroCutsceneService:SendOpening(Player)
		end
	end)
	IntroCutsceneService.Client.OpeningFinished:Connect(function(Player: Player, Token: string)
		if typeof(Token) == "string" then
			IntroCutsceneService:FinishOpening(Player, Token)
		end
	end)

	Players.PlayerRemoving:Connect(function(Player: Player)
		IntroCutsceneService:Cleanup(Player)
	end)

	local Elapsed = 0
	RunService.Heartbeat:Connect(function(DeltaTime: number)
		if next(Sessions) == nil then
			return
		end

		Elapsed += DeltaTime
		if Elapsed < IntroCutsceneConfig.IntrusionCheckInterval then
			return
		end

		Elapsed = 0
		IntroCutsceneService:CheckIntruders()
	end)
end

return IntroCutsceneService
