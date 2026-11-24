local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local IntroCutsceneConfig = require(ReplicatedStorage.Shared.IntroCutsceneConfig)
local Config = IntroCutsceneConfig.CombatTutorial
local IntroCombatTutorialService = Knit.CreateService({
	Name = "IntroCombatTutorialService",
	Client = {
		StateChanged = Knit.CreateSignal(),
		Ended = Knit.CreateSignal(),
	},
})

type Session = {
	Player: Player,
	Character: Model,
	Boss: Model,
	Ship: Model,
	Token: string,
	Step: number,
	Attempt: number,
	Stage: string,
	Activated: boolean,
	PlayerFrame: CFrame,
	BossFrame: CFrame,
	PreviousCantAttack: any,
	PreviousForceField: any,
	PreviousWandering: any,
	PreviousRunner: any,
	PreviousProtection: { [Model]: any },
	Connections: { RBXScriptConnection },
	LastBlock: number?,
	LastDodge: number?,
	DodgeDirection: string?,
	FinishingDodge: boolean?,
	FinishingKick: boolean?,
	Track: AnimationTrack?,
	Animation: Animation?,
	FreezeTime: number?,
	HitTime: number?,
	HitDelay: number?,
	SwingSpeed: number?,
	Complete: () -> (),
}

local Sessions: { [Player]: Session } = {}
local Actors: { [Model]: Session } = {}
local PostureService
local CharacterService
local BuffService
local WeaponService

local function IsActive(Session: Session): boolean
	return Sessions[Session.Player] == Session
		and Session.Player.Character == Session.Character
		and Session.Character.Parent ~= nil
		and Session.Boss.Parent ~= nil
end

local function SetLock(Actor: Model, Locked: boolean)
	Actor:SetAttribute("IntroOpening", Locked)
	Actor:SetAttribute("SkillLockMovement", Locked)
	Actor:SetAttribute("Running", false)
	local Root = Actor.PrimaryPart
	if Root then
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
		Root.Anchored = Locked
	end
end

local function StopSwing(Session: Session)
	if Session.Track then
		Session.Track:Stop(0.1)
		Session.Track:Destroy()
		Session.Track = nil
	end
end

local function Publish(Session: Session, Stage: string, Success: boolean?)
	Session.Stage = Stage
	IntroCombatTutorialService.Client.StateChanged:Fire(
		Session.Player,
		Session.Token,
		Session.Attempt,
		Session.Step,
		Stage,
		Session.Character,
		Session.Boss,
		Session.Ship.Name,
		Success,
		Session.Animation,
		Session.FreezeTime
	)
end

local function AllowLessonAction(Session: Session)
	SetLock(Session.Character, false)
	Session.Character:SetAttribute("SkillLockMovement", Session.Step ~= 4)
	Session.Character:SetAttribute("IntroTutorialAction", ({ "Parry", "Attack", "Dodge", "Kick" })[Session.Step])
	Session.Player:SetAttribute("CantAttack", Session.Step ~= 2 and Session.Step ~= 4)
end

function IntroCombatTutorialService:Cancel(Player: Player)
	local Session = Sessions[Player]
	if not Session then
		return
	end
	Sessions[Player] = nil
	for _, Connection in Session.Connections do
		Connection:Disconnect()
	end
	StopSwing(Session)
	for _, Actor in { Session.Character, Session.Boss } do
		Actors[Actor] = nil
		if Actor.Parent then
			Actor:SetAttribute("IntroTutorialProtected", Session.PreviousProtection[Actor])
			if Session.Activated then
				SetLock(Actor, false)
			end
		end
	end
	if Session.Boss.Parent then
		Session.Boss:SetAttribute("IntroTutorialArmed", nil)
		Session.Boss:SetAttribute("IntroTutorialActive", nil)
		if Session.Activated then
			Session.Boss:SetAttribute("WanderingNpc", Session.PreviousWandering)
			local Runner = Session.Boss:FindFirstChild("Runner")
			if Runner then
				Runner:SetAttribute("Enabled", Session.PreviousRunner)
			end
		end
	end
	if Player.Character == Session.Character and Session.Character.Parent then
		Session.Character:SetAttribute("IntroTutorialAction", nil)
		Player:SetAttribute("CantAttack", Session.PreviousCantAttack)
		CharacterService:EnableForceField(Session.Character, Session.PreviousForceField == true)
	end
	self.Client.Ended:Fire(Player, Session.Token)
end

function IntroCombatTutorialService:CompleteDodge(Session: Session)
	if not IsActive(Session) or not Session.FinishingDodge or Session.Character:GetAttribute("Rolling") then
		return
	end

	Session.FinishingDodge = nil
	Session.Step = 4
	Session.PlayerFrame, Session.BossFrame = Session.Character:GetPivot(), Session.Boss:GetPivot()
	self:BeginAttempt(Session)
end

function IntroCombatTutorialService:CompleteKick(Session: Session)
	if not IsActive(Session) or not Session.FinishingKick or Session.Character:GetAttribute("Kicking") then
		return
	end

	local Complete = Session.Complete
	self:Cancel(Session.Player)
	Complete()
end

function IntroCombatTutorialService:BeginAttempt(Session: Session)
	if not IsActive(Session) then
		return
	end
	StopSwing(Session)
	Session.Animation, Session.FreezeTime, Session.HitTime = nil, nil, nil
	Session.LastBlock, Session.LastDodge, Session.DodgeDirection = nil, nil, nil
	PostureService:Block(Session.Character, false)
	Session.Character:SetAttribute("Stamina", Session.Character:GetAttribute("MaxStamina"))
	Session.Character:PivotTo(Session.PlayerFrame)
	Session.Boss:PivotTo(Session.BossFrame)
	for _, Actor in { Session.Character, Session.Boss } do
		SetLock(Actor, true)
	end
	Session.Player:SetAttribute("CantAttack", true)
	if Session.Step == 2 or Session.Step == 4 then
		Session.Attempt += 1
		AllowLessonAction(Session)
		Publish(Session, "Explain")
	else
		Session.Stage = "Preparing"
		Session.Boss:SetAttribute("ComboCounter", 1)
		local Track, Animation = WeaponService:PlayM1Animation(Session.Boss)
		self:CaptureSwordAttack(
			Session.Boss,
			Track,
			Animation,
			Session.HitDelay or Animation:GetAttribute("HitboxDelay") or 0.5
		)
	end
end

function IntroCombatTutorialService:FinishAttempt(Session: Session)
	if not IsActive(Session) or Session.Stage ~= "Practice" then
		return
	end
	local Character, Boss = Session.Character, Session.Boss
	local Now = os.clock()
	local CloseEnough = (Character:GetPivot().Position - Boss:GetPivot().Position).Magnitude <= Config.MaximumDistance
	local Success = false
	if Session.Step == 1 then
		Success = CloseEnough and Session.LastBlock ~= nil and Now - Session.LastBlock <= Config.ParryWindow
		if Success then
			PostureService:Deflected(Character, Boss, 0, { By = "Weapon", DontApplyForce = true })
		end
	elseif Session.Step == 3 then
		Success = CloseEnough
			and Session.LastDodge ~= nil
			and Now - Session.LastDodge <= Config.DodgeWindow
			and (Session.DodgeDirection == "Left" or Session.DodgeDirection == "Right")
		if Success then
			PostureService:Dodged(Character, Boss)
		end
	end

	-- A dodge avoids the hit; it does not cancel the enemy's follow-through.
	local FollowThrough = 0
	if Session.Step == 3 and Session.Track and Session.Track.IsPlaying then
		local Speed = Session.SwingSpeed or 1
		Session.Track:AdjustSpeed(Speed)
		FollowThrough = math.max(0, Session.Track.Length - Session.Track.TimePosition) / math.max(Speed, 0.01) + 0.1
	else
		StopSwing(Session)
	end
	PostureService:Block(Character, false)
	Character:SetAttribute("IntroTutorialAction", "Wait")
	if Session.Step ~= 3 then
		SetLock(Character, true)
	end
	Publish(Session, "Result", Success)
	if Session.Step == 3 and Success then
		Session.FinishingDodge = true
		self:CompleteDodge(Session)
		return
	end

	local Attempt = Session.Attempt
	local Delay = if Success and Session.Step == 1 then Config.ParryRecoveryTime else Config.RecoveryTime
	Delay = math.max(Delay, FollowThrough)
	task.delay(Delay, function()
		if not IsActive(Session) or Session.Attempt ~= Attempt or Session.Stage ~= "Result" then
			return
		end
		if Success then
			Session.Step += 1
		end
		if Session.Step > 4 then
			local Complete = Session.Complete
			self:Cancel(Session.Player)
			Complete()
		else
			self:BeginAttempt(Session)
		end
	end)
end

function IntroCombatTutorialService:CaptureSwordAttack(
	Boss: Model,
	Track: AnimationTrack,
	Animation: Animation,
	HitDelay: number
): boolean
	local Session = Actors[Boss]
	if
		not Session
		or not IsActive(Session)
		or Session.Boss ~= Boss
		or (Session.Stage ~= "Armed" and Session.Stage ~= "Preparing")
	then
		return false
	end
	if not Session.Activated then
		Session.Activated = true
		Session.PreviousWandering = Boss:GetAttribute("WanderingNpc")
		local Runner = Boss:FindFirstChild("Runner")
		Session.PreviousRunner = Runner and Runner:GetAttribute("Enabled")
		Boss:SetAttribute("IntroTutorialArmed", nil)
		Boss:SetAttribute("IntroTutorialActive", true)
		Boss:SetAttribute("WanderingNpc", true)
		if Runner then
			Runner:SetAttribute("Enabled", false)
		end
		for _, Actor in { Session.Character, Boss } do
			BuffService:RemoveBuffsByType(Actor, "Burn")
		end
	end
	Session.Attempt += 1
	local Speed = math.max(Track.Speed, 0.01)
	local AnimationHitDelay = Animation:GetAttribute("HitboxDelay")
	-- The live hitbox may use a generic delay; the lesson follows the animated strike.
	if typeof(AnimationHitDelay) == "number" and AnimationHitDelay > 0 and AnimationHitDelay < math.huge then
		HitDelay = AnimationHitDelay / Speed
	end
	Session.HitDelay = HitDelay
	Session.Track, Session.Animation, Session.FreezeTime, Session.HitTime = Track, Animation, nil, nil
	Session.Player:SetAttribute("CantAttack", true)
	SetLock(Boss, true)
	Publish(Session, "Incoming")
	local Attempt = Session.Attempt
	Session.SwingSpeed = Speed
	local Delay = math.max(0, HitDelay - Config.PauseBeforeHit)
	task.delay(Delay, function()
		if not IsActive(Session) or Session.Attempt ~= Attempt or Session.Stage ~= "Incoming" then
			return
		end
		Session.FreezeTime = Track.TimePosition
		Session.HitTime = Session.FreezeTime + Config.PauseBeforeHit * Speed
		Track:AdjustSpeed(0)
		PostureService:Block(Session.Character, false)
		SetLock(Session.Character, true)
		Session.PlayerFrame, Session.BossFrame = Session.Character:GetPivot(), Boss:GetPivot()
		AllowLessonAction(Session)
		Publish(Session, "Explain")
	end)
	return true
end

function IntroCombatTutorialService:ResolveHit(Target: Model, Attacker: Model, Data: { [string]: any }): string?
	local Session = Actors[Target]
	if not Session or not IsActive(Session) or not Session.Activated then
		return nil
	end
	if
		Target == Session.Boss
		and Attacker == Session.Character
		and Session.Step == 4
		and (Session.Stage == "Practice" or Session.Stage == "Explain")
		and Data.By == "Kick"
		and Data.Action == "Kick"
		and (Target:GetPivot().Position - Attacker:GetPivot().Position).Magnitude <= Config.MaximumDistance
	then
		Session.FinishingKick = true
		Session.Character:SetAttribute("IntroTutorialAction", "Wait")
		Session.Player:SetAttribute("CantAttack", true)
		Publish(Session, "Result", true)
		self:CompleteKick(Session)
		return "TutorialKick"
	end
	if
		Target == Session.Boss
		and Attacker == Session.Character
		and Session.Step == 2
		and (Session.Stage == "Practice" or Session.Stage == "Explain")
		and Data.By == "Weapon"
		and Data.Action == "Attack"
		and (Target:GetPivot().Position - Attacker:GetPivot().Position).Magnitude <= Config.MaximumDistance
	then
		Session.Player:SetAttribute("CantAttack", true)
		Session.Character:SetAttribute("IntroOpening", true)
		Session.Character:SetAttribute("SkillLockMovement", true)
		Session.Character:SetAttribute("IntroTutorialAction", nil)
		Publish(Session, "EnemyParry", true)
		PostureService:Deflected(Session.Boss, Session.Character, 0, { By = "Weapon", DontApplyForce = true })
		local Attempt = Session.Attempt
		task.delay(Config.EnemyParryRecovery, function()
			if not IsActive(Session) or Session.Attempt ~= Attempt or Session.Stage ~= "EnemyParry" then
				return
			end
			Session.Step = 3
			Session.PlayerFrame, Session.BossFrame = Session.Character:GetPivot(), Session.Boss:GetPivot()
			self:BeginAttempt(Session)
		end)
		return "Deflect"
	end
	return "TutorialBlocked"
end

function IntroCombatTutorialService:Arm(
	Player: Player,
	Character: Model,
	Boss: Model,
	Ship: Model,
	Token: string,
	Complete: () -> ()
): boolean
	if not Config.Enabled or Player.Character ~= Character or not Character.PrimaryPart or not Boss.PrimaryPart then
		return false
	end
	self:Cancel(Player)
	local Session: Session = {
		Player = Player,
		Character = Character,
		Boss = Boss,
		Ship = Ship,
		Token = Token,
		Step = 1,
		Attempt = 0,
		Stage = "Armed",
		Activated = false,
		PlayerFrame = Character:GetPivot(),
		BossFrame = Boss:GetPivot(),
		PreviousCantAttack = Player:GetAttribute("CantAttack"),
		PreviousForceField = Character:GetAttribute("ForceField"),
		PreviousProtection = {},
		Connections = {},
		Complete = Complete,
	}
	Sessions[Player] = Session
	Boss:SetAttribute("IntroTutorialArmed", true)
	for _, Actor in { Character, Boss } do
		Actors[Actor] = Session
		Session.PreviousProtection[Actor] = Actor:GetAttribute("IntroTutorialProtected")
		Actor:SetAttribute("IntroTutorialProtected", true)
		table.insert(
			Session.Connections,
			Actor.Destroying:Connect(function()
				self:Cancel(Player)
			end)
		)
	end
	table.insert(
		Session.Connections,
		Character:GetAttributeChangedSignal("Blocking"):Connect(function()
			if
				IsActive(Session)
				and Session.Step == 1
				and (Session.Stage == "Explain" or Session.Stage == "Practice")
				and Character:GetAttribute("Blocking")
			then
				Session.LastBlock = os.clock()
				if Session.Stage == "Explain" then
					self:ReleaseAction(Session)
				end
			end
		end)
	)
	table.insert(
		Session.Connections,
		Character:GetAttributeChangedSignal("RollIFrame"):Connect(function()
			if
				IsActive(Session)
				and Session.Step == 3
				and (Session.Stage == "Explain" or Session.Stage == "Practice")
				and Character:GetAttribute("RollIFrame")
			then
				Session.LastDodge = os.clock()
				Session.DodgeDirection = Character:GetAttribute("RollDirection")
				if Session.Stage == "Explain" then
					self:ReleaseAction(Session)
				end
			end
		end)
	)
	table.insert(Session.Connections, Character:GetAttributeChangedSignal("Rolling"):Connect(function()
		self:CompleteDodge(Session)
	end))
	table.insert(Session.Connections, Character:GetAttributeChangedSignal("Kicking"):Connect(function()
		if IsActive(Session) and Session.Step == 4 and Session.Stage == "Explain" and Character:GetAttribute("Kicking") then
			self:ReleaseAction(Session)
		end
		self:CompleteKick(Session)
	end))
	table.insert(
		Session.Connections,
		Character:GetAttributeChangedSignal("Attack"):Connect(function()
			if
				IsActive(Session)
				and Session.Step == 2
				and Session.Stage == "Explain"
				and Character:GetAttribute("Attack")
			then
				self:ReleaseAction(Session)
			end
		end)
	)
	return true
end

function IntroCombatTutorialService:ReleaseAction(Session: Session)
	if not IsActive(Session) or Session.Stage ~= "Explain" then
		return
	end
	Session.Stage = "Practice"
	SetLock(Session.Character, false)
	Session.Player:SetAttribute("CantAttack", Session.Step ~= 2 and Session.Step ~= 4)
	if Session.Step == 4 then
		SetLock(Session.Boss, false)
	end
	if Session.Track and Session.FreezeTime and Session.HitTime then
		Session.Track:AdjustSpeed(math.max(0.01, (Session.HitTime - Session.FreezeTime) / Config.ReactionReleaseTime))
	end
	Publish(Session, "Practice")
	local Attempt = Session.Attempt
	task.delay(if Session.Step == 2 or Session.Step == 4 then Config.CounterattackTimeout else Config.ReactionReleaseTime, function()
		if IsActive(Session) and Session.Attempt == Attempt then
			self:FinishAttempt(Session)
		end
	end)
end

function IntroCombatTutorialService.KnitInit()
	PostureService = Knit.GetService("PostureService")
	CharacterService = Knit.GetService("CharacterService")
	BuffService = Knit.GetService("BuffService")
	WeaponService = Knit.GetService("WeaponService")
end

function IntroCombatTutorialService.KnitStart()
	Players.PlayerRemoving:Connect(function(Player: Player)
		IntroCombatTutorialService:Cancel(Player)
	end)
	local function WatchPlayer(Player: Player)
		Player.CharacterRemoving:Connect(function(Character: Model)
			local Session = Sessions[Player]
			if Session and Session.Character == Character then
				IntroCombatTutorialService:Cancel(Player)
			end
		end)
	end
	Players.PlayerAdded:Connect(WatchPlayer)
	for _, Player in Players:GetPlayers() do
		WatchPlayer(Player)
	end
end

return IntroCombatTutorialService
