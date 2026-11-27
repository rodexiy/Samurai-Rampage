return function(Sources: { [string]: string }): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Signal(): any
		local Listeners = {}
		local Event = {}
		function Event:Connect(Callback: (...any) -> ()): any
			local Connection = { Connected = true, Callback = Callback }
			function Connection.Disconnect(Current: any)
				Current.Connected = false
			end
			table.insert(Listeners, Connection)
			return Connection
		end
		function Event:Fire(...: any)
			for _, Connection in table.clone(Listeners) do
				if Connection.Connected then
					Connection.Callback(...)
				end
			end
		end
		Event.FireAll = Event.Fire
		return Event
	end

	local Vector = {}
	local VectorMeta = {}
	function Vector.new(X: number, Y: number, Z: number): any
		return setmetatable({ X = X, Y = Y, Z = Z }, VectorMeta)
	end
	function VectorMeta.__index(Value: any, Key: string): any
		if Key == "Magnitude" then
			return math.sqrt(Value.X ^ 2 + Value.Y ^ 2 + Value.Z ^ 2)
		end
		if Key == "Unit" then
			return Vector.new(Value.X / Value.Magnitude, Value.Y / Value.Magnitude, Value.Z / Value.Magnitude)
		end
		if Key == "Dot" then
			return function(A: any, B: any): number
				return A.X * B.X + A.Y * B.Y + A.Z * B.Z
			end
		end
		return nil
	end
	function VectorMeta.__add(A: any, B: any): any
		return Vector.new(A.X + B.X, A.Y + B.Y, A.Z + B.Z)
	end
	function VectorMeta.__sub(A: any, B: any): any
		return Vector.new(A.X - B.X, A.Y - B.Y, A.Z - B.Z)
	end
	function VectorMeta.__div(A: any, B: number): any
		return Vector.new(A.X / B, A.Y / B, A.Z / B)
	end
	function VectorMeta.__mul(A: any, B: number): any
		return Vector.new(A.X * B, A.Y * B, A.Z * B)
	end
	Vector.xAxis = Vector.new(1, 0, 0)
	Vector.zero = Vector.new(0, 0, 0)
	Vector.zAxis = Vector.new(0, 0, 1)
	local Frames = {}
	function Frames.new(X: number, Y: number, Z: number): any
		return setmetatable({ Position = Vector.new(X, Y, Z), LookVector = Vector.new(0, 0, -1) }, {
			__mul = function(A: any, B: any): any
				local P = A.Position + B.Position
				return Frames.new(P.X, P.Y, P.Z)
			end,
		})
	end

	local Now = 0
	local Jobs = {}
	local Created = {}
	local World: any = { NPCs = {}, Wall = false }
	function World:GetServerTimeNow(): number
		return Now
	end
	function World:Raycast(_Origin: any, _Direction: any, _Params: any): any
		return if self.Wall then {} else nil
	end
	local function Object(ClassName: string): any
		local Attributes, Changed = {}, {}
		local Value: any = {
			ClassName = ClassName,
			__instance = true,
			Parent = World,
			AttributeChanged = Signal(),
			Destroying = Signal(),
		}
		function Value:IsA(Name: string): boolean
			return self.ClassName == Name
		end
		function Value:Destroy()
			self.Destroying:Fire()
			self.Parent = nil
		end
		function Value:IsDescendantOf(Ancestor: any): boolean
			return self.Parent == Ancestor
		end
		function Value:GetAttribute(Name: string): any
			return Attributes[Name]
		end
		function Value:SetAttribute(Name: string, State: any)
			if Attributes[Name] == State then
				return
			end
			Attributes[Name] = State
			if Changed[Name] then
				Changed[Name]:Fire()
			end
			self.AttributeChanged:Fire(Name)
		end
		function Value:GetAttributeChangedSignal(Name: string): any
			Changed[Name] = Changed[Name] or Signal()
			return Changed[Name]
		end
		function Value:FindFirstChildWhichIsA(Name: string): any
			return if Name == "Humanoid" then self.Humanoid else nil
		end
		function Value:FindFirstChild(Name: string): any
			return self[Name]
		end
		function Value:GetPivot(): any
			return self.PrimaryPart.CFrame
		end
		function Value:QueryDescendants(_Selector: string): { any }
			return {}
		end
		if ClassName == "BindableEvent" then
			Value.Event = Signal()
			Value.Fire = function(_Self: any, ...: any)
				Value.Event:Fire(...)
			end
		end
		table.insert(Created, Value)
		return Value
	end
	local Players: any = { PlayerRemoving = Signal() }
	function Players:GetPlayerFromCharacter(Character: any): any
		return Character.Player
	end
	local Heartbeat = Signal()
	local Task = {}
	function Task.delay(Duration: number, Callback: () -> ())
		table.insert(Jobs, { At = Now + Duration, Callback = Callback })
	end
	function Task.spawn(Callback: () -> ())
		Callback()
	end
	local function Step(Duration: number)
		Now += Duration
		Heartbeat:Fire()
		for Index = #Jobs, 1, -1 do
			if Jobs[Index].At <= Now then
				local Job = table.remove(Jobs, Index)
				Job.Callback()
			end
		end
	end
	local function Character(Z: number): any
		local Result = Object("Model")
		Result.PrimaryPart = {
			Children = {},
			Position = Vector.new(0, 0, Z),
			CFrame = Frames.new(0, 0, Z),
			FindFirstChild = function(): any
				return nil
			end,
			GetChildren = function(Current: any): any
				local Children = {}
				for _, Child in Current.Children do
					if Child.Parent == Current then
						table.insert(Children, Child)
					end
				end
				return Children
			end,
		}
		Result.Humanoid = { Health = 100, WalkSpeed = 12, JumpPower = 40, MoveDirection = Vector.new(0, 0, 1) }
		for Name, Value in
			{
				Health = 100,
				MaxHealth = 100,
				Stamina = 100,
				SwordStaminaCost = 5,
				DefaultWalkSpeed = 12,
				DefaultJumpPower = 40,
				WeaponEquipped = true,
			}
		do
			Result:SetAttribute(Name, Value)
		end
		return Result
	end
	local Attacker, Target = Character(0), Character(-3)
	Target.Mass = 100
	-- Face the attacker so block and parry are valid.
	Target.PrimaryPart.CFrame.LookVector = Vector.new(0, 0, 1)
	local Player = Object("Player")
	Player.Character = Attacker
	Attacker.Player = Player
	local Services = {}
	local Knit = {
		CreateService = function(Value: any): any
			return Value
		end,
		CreateSignal = Signal,
		GetService = function(Name: string): any
			return Services[Name]
		end,
	}
	local Noop = setmetatable({}, {
		__index = function(): any
			return function() end
		end,
	})
	for _, Name in
		{
			"AnimationService",
			"BloodService",
			"BuffService",
			"SkillService",
			"InCombatService",
			"IntroCutsceneService",
			"IntroCombatTutorialService",
		}
	do
		Services[Name] = Noop
	end
	local Debounces = {}
	function Debounces:AddDebounce(Subject: any, Name: string, Duration: number)
		Subject:SetAttribute(Name, true)
		Task.delay(Duration, function()
			Subject:SetAttribute(Name, false)
		end)
	end
	Services.DebounceService = Debounces
	Services.RenderService = Noop
	local Damage = {}
	function Damage:CanDamage(Subject: any, _Attacker: any): boolean
		return not Subject:GetAttribute("ForceField") and not Subject:GetAttribute("Died")
			and not Subject:GetAttribute("IntroTutorialProtected")
	end
	function Damage:DealDamage(Subject: any, Amount: number, _Attacker: any)
		Subject:SetAttribute("Health", Subject:GetAttribute("Health") - Amount)
	end
	Services.DamageService = Damage
	Services.StaminaService = {
		RemoveStamina = function(_Self: any, Subject: any, Amount: number)
			Subject:SetAttribute("Stamina", Subject:GetAttribute("Stamina") - Amount)
		end,
	}
	Services.StatService = {
		GetLevel = function(): number
			return Attacker:GetAttribute("Strength") or 0
		end,
	}
	Services.PostureService = {
		Deflected = function(): string
			return "Deflect"
		end,
		Blocked = function(): string
			return "Block"
		end,
		Dodged = function(): string
			return "Dodge"
		end,
	}
	local Ragdolls = 0
	local LegacyForces = {}
	Services.RagdollService = {
		Ragdoll = function(_Self: any, Subject: any, Impulse: number, Direction: any, Duration: number)
			Ragdolls += 1
			Subject:SetAttribute("Ragdoll", true)
			Check(
				Impulse == 0 and Direction.Magnitude == 0 and Duration == 1,
				"Ragdoll creates the physical state without applying a competing legacy impulse"
			)
			local LegacyForce = Object("BodyVelocity")
			LegacyForce.Parent = Subject.PrimaryPart
			table.insert(Subject.PrimaryPart.Children, LegacyForce)
			table.insert(LegacyForces, LegacyForce)
		end,
	}
	local DoorChecks = 0
	local DoorBoxes = {}
	Services.HitboxService = {
		GetCharactersInBoxArea = function(): any
			return { Attacker, Target, Target }
		end,
	}
	Services.DoorService = {
		BreakInHitbox = function(_Self: any, Subject: any, Hitbox: any, Affected: any)
			DoorChecks += 1
			DoorBoxes[Hitbox] = true
			Check(
				Subject == Attacker and Hitbox.ClassName == "Part" and Hitbox.Size.Z == 6 and type(Affected) == "table",
				"Kick passes a dedicated physical door hitbox and deduplication state to the door service"
			)
		end,
	}
	local Modules: any = {
		Knit = Knit,
		SkillTreeConfig = { Effects = { GuardWalkSpeed = 10 } },
		BowConfig = { DrawWalkSpeed = 4 },
		CrouchConfig = { WalkSpeed = 5 },
		Mass = function(Subject: any): number
			return Subject.Mass or 10
		end,
	}
	local RS = {
		Packages = { Knit = "Knit" },
		Shared = {
			EgoConfig = "EgoConfig",
			KickConfig = "Config",
			Validate = "Validate",
			CharacterShared = "Movement",
			SkillTreeConfig = "SkillTreeConfig",
			BowConfig = "BowConfig",
			CrouchConfig = "CrouchConfig",
			Utils = { GetAssemblyMass = "Mass" },
		},
		Assets = { Animations = { Combat = { Hit = {} } } },
	}
	local Engine = {
		Players = Players,
		ReplicatedStorage = RS,
		RunService = { Heartbeat = Heartbeat },
		CollectionService = {
			GetTagged = function(): any
				return {}
			end,
		},
		Debris = {
			AddItem = function(_Self: any, Item: any, Duration: number)
				Item.Lifetime = Duration
			end,
		},
	}
	local Env = setmetatable({
		game = {
			Players = Players,
			GetService = function(_Self: any, Name: string): any
				return Engine[Name]
			end,
		},
		workspace = World,
		task = Task,
		Vector3 = Vector,
		Vector2 = {
			new = function(X: number, Y: number): any
				return setmetatable({ X = X, Y = Y }, {
					__mul = function(A: any, B: number): any
						return { X = A.X * B, Y = A.Y * B }
					end,
				})
			end,
		},
		CFrame = Frames,
		Instance = { new = Object },
		OverlapParams = {
			new = function(): any
				return {}
			end,
		},
		RaycastParams = {
			new = function(): any
				return {}
			end,
		},
		Enum = {
			RaycastFilterType = { Include = 1, Exclude = 2 },
			ActuatorRelativeTo = { World = 1 },
			VelocityConstraintMode = { Vector = 1 },
		},
		typeof = function(Value: any): string
			return if type(Value) == "table" and Value.__instance then "Instance" else type(Value)
		end,
		require = function(Name: string): any
			return assert(Modules[Name], Name)
		end,
	}, { __index = getfenv() })
	local function Load(Name: string): any
		local Chunk = assert(loadstring(Sources[Name], Name))
		setfenv(Chunk, Env)
		local Result = Chunk()
		Modules[Name] = Result
		return Result
	end
	Load("EgoConfig")
	local Config, Validate, Movement = Load("Config"), Load("Validate"), Load("Movement")
	-- Balance edits must not change the fixed reference values used by these scenarios.
	Config.KnockbackSpeed = 35
	local AssemblyMass = Load("AssemblyMass")
	local FirstAssembly = { Anchored = false, AssemblyMass = 12, Massless = true }
	local SecondAssembly = { Anchored = false, AssemblyMass = 3, Massless = true }
	local function MassOf(Parts: { any }): number
		return AssemblyMass({
			QueryDescendants = function(): { any }
				return Parts
			end,
		})
	end
	Check(MassOf({
		{ AssemblyRootPart = FirstAssembly, Massless = true },
		{ AssemblyRootPart = FirstAssembly, Massless = true },
	}) == 12, "A massless rig still has physical mass and a welded assembly is counted once")
	Check(
		MassOf({ { AssemblyRootPart = FirstAssembly }, { AssemblyRootPart = SecondAssembly } }) == 15,
		"Separate ragdoll assemblies contribute their effective masses"
	)
	Check(
		MassOf({ { AssemblyRootPart = { Anchored = true, AssemblyMass = math.huge } } }) == 0,
		"Anchored assemblies do not produce an infinite knockback"
	)
	Check(MassOf({ { Anchored = false, AssemblyMass = 4 } }) == 4, "A standalone part uses its own assembly mass")
	local Facing = Load("Facing")
	local Knockback = Load("Knockback")
	Services.KnockbackService = Knockback
	Knockback.KnitInit()
	local Hit = Load("Hit")
	Services.HitService = Hit
	local TutorialResult = "TutorialBlocked"
	Services.IntroCombatTutorialService = {
		ResolveHit = function(): string
			return TutorialResult
		end,
	}
	Hit.KnitInit()
	local Kick = Load("Kick")
	Kick.KnitInit()
	Kick.KnitStart()
	local Starts, Impacts = {}, 0
	local Stops = 0
	Kick.Client.Stopped:Connect(function()
		Stops += 1
	end)
	Kick.Client.Started:Connect(function(_Character: any, Side: string)
		table.insert(Starts, Side)
	end)
	Kick.Client.Impact:Connect(function()
		Impacts += 1
	end)
	local function Pushes(): number
		local Count = 0
		for _, Value in Created do
			if Value.ClassName == "LinearVelocity" then
				Count += 1
			end
		end
		return Count
	end

	Check(not Facing(Attacker), "Idle character keeps normal facing")
	Attacker:SetAttribute("WeaponEquipped", false)
	Attacker:SetAttribute("Kicking", true)
	Check(Facing(Attacker), "Unarmed kick faces the aim direction")
	Attacker:SetAttribute("WeaponEquipped", true)
	Check(Facing(Attacker), "Armed kick uses the same aim facing as attacks and blocking")
	Attacker:SetAttribute("Kicking", false)
	Check(not Facing(Attacker), "Ending kick releases aim facing")
	Check(Validate:CanKick(Attacker), "Healthy idle player can kick")
	for _, Attribute in
		{
			"Downed",
			"Mounted",
			"Died",
			"Ragdoll",
			"BeenHitted",
			"Blocking",
			"ClientBlocking",
			"Rolling",
			"Attacking",
			"ClientAttacking",
			"StrongAttack",
			"Climbing",
			"Vaulting",
			"WallRunning",
			"UsingSkillCantAttack",
			"RealmEditing",
			"KickDebounce",
		}
	do
		Attacker:SetAttribute(Attribute, true)
		Check(not Validate:CanKick(Attacker), "Reject kick during " .. Attribute)
		Attacker:SetAttribute(Attribute, false)
	end
	Player:SetAttribute("CantAttack", true)
	Check(not Validate:CanKick(Attacker), "Server attack restriction applies")
	Player:SetAttribute("CantAttack", false)
	Attacker:SetAttribute("Kicking", true)
	Check(
		not Validate:CanAttack(Attacker) and not Validate:CanRoll(Attacker) and not Validate:CanBlock(Attacker),
		"Kick excludes competing combat actions"
	)
	Attacker:SetAttribute("Stunless", true)
	Check(not Validate:CanUseSkill(Attacker, 0), "Stunless cannot bypass kick exclusion")
	Attacker:SetAttribute("Stunless", false)
	Movement:UpdateBoth(Attacker)
	Check(
		Attacker:GetAttribute("TargetWalkSpeed") == 8 and Attacker.Humanoid.JumpPower == 0,
		"Kick uses blocking speed and suppresses jumping"
	)
	Attacker:SetAttribute("TalentMobileGuard", true)
	Movement:UpdateBoth(Attacker)
	Check(Attacker:GetAttribute("TargetWalkSpeed") == 10, "Kick follows mobile guard blocking speed")
	Attacker:SetAttribute("TalentMobileGuard", false)
	Attacker:SetAttribute("Kicking", false)

	Attacker:SetAttribute("Stamina", Config.StaminaCost - 1)
	Kick:Kick(Attacker)
	Check(#Starts == 0 and not Attacker:GetAttribute("KickDebounce"), "Insufficient stamina rejects the kick without cooldown")
	Attacker:SetAttribute("Stamina", Config.StaminaCost)
	Check(Validate:CanKick(Attacker), "Exactly enough stamina permits a kick")
	Attacker:SetAttribute("Stamina", 100)
	local Notifications = 0
	Target:SetAttribute("IsAI", true)
	Target.HitboxDetected = Object("BindableEvent")
	Target.HitboxDetected.Event:Connect(function(Subject: any, Data: any)
		Notifications += 1
		Check(Subject == Attacker and Data.Action == "Kick" and Data.TimeUntilHit > 0,
			"AI is warned during windup with time left to defend")
	end)
	Kick.Client.Request:Fire(Player, Target)
	Kick.Client.Request:Fire(Player, "invalid")
	Check(#Starts == 0, "Reject forged character and malformed request")
	Kick.Client.Request:Fire(Player, Attacker)
	Check(#Starts == 1 and Attacker:GetAttribute("Kicking"), "Owned request starts kick")
	Check(Attacker:GetAttribute("Stamina") == 90, "Accepted kick spends stamina once at start")
	Kick:Kick(Attacker)
	Check(Attacker:GetAttribute("Stamina") == 90, "Duplicate requests do not spend stamina again")
	Step(0.05)
	Check(Target:GetAttribute("Health") == 100, "No damage before contact window")
	Check(Notifications == 1, "AI receives a single windup warning")
	Target:SetAttribute("IsAI", false)
	Step(Config.HitDelay - 0.051)
	Check(
		Target:GetAttribute("Health") == 100 and Attacker:GetAttribute("Kicking") and DoorChecks == 0,
		"Character and door hitboxes stay inactive until the configured contact time"
	)
	Step(0.002)
	Check(Target:GetAttribute("Health") == 96 and Ragdolls == 1, "Unblocked kick deals low damage with ragdoll")
	Check(
		Created[#Created].ClassName == "LinearVelocity" and Created[#Created].VectorVelocity.Z == -35,
		"The first hit applies Push after entering ragdoll"
	)
	Check(
		LegacyForces[#LegacyForces].Parent == nil,
		"The legacy ragdoll BodyVelocity is removed before applying the knockback"
	)
	Step(0.1)
	Check(Target:GetAttribute("Health") == 96 and Impacts == 1, "Each target is hit once per kick")
	Check(Attacker:GetAttribute("Kicking"), "Kick remains active during the 0.25 second hitbox window")
	Step(0.15)
	Check(not Attacker:GetAttribute("Kicking"), "Kick ends after windup plus 0.25 second hitbox window")
	for Hitbox in DoorBoxes do
		Check(Hitbox.Parent == nil, "The dedicated door hitbox is destroyed when the kick ends")
	end
	Check(Stops == 0, "Normal completion lets the animation finish naturally")
	Kick:Kick(Attacker)
	Check(#Starts == 1, "Cooldown prevents repeated kick")
	Step(1.3)
	Kick:Kick(Attacker)
	Check(#Starts == 2 and Starts[1] ~= Starts[2], "Cooldown expires and kicking legs alternate")
	Attacker:SetAttribute("BeenHitted", true)
	Check(not Attacker:GetAttribute("Kicking"), "Incoming hit cancels kick")
	Check(Attacker:GetAttribute("Stamina") == 80, "Cancelling a started kick does not refund stamina")
	Step(0.3)
	Check(Impacts == 1, "Cancelled kick cannot apply late hits")
	Attacker:SetAttribute("BeenHitted", false)

	for _, Case in
		{
			{ Attribute = "Blocking", Expected = "Block" },
			{ Attribute = "DeflectTime", Expected = "Deflect" },
			{ Attribute = "RollIFrame", Expected = "Dodge" },
		}
	do
		Step(2)
		Target:SetAttribute("Ragdoll", false)
		Target:SetAttribute(Case.Attribute, true)
		local Before, Count, ImpactCount = Target:GetAttribute("Health"), Pushes(), Impacts
		Kick:Kick(Attacker)
		Step(Config.HitDelay + 0.01)
		Check(
			Target:GetAttribute("Health") == Before and not Target:GetAttribute("Ragdoll"),
			Case.Expected .. " avoids damage and ragdoll"
		)
		Check(
			Pushes() == Count + (if Case.Expected == "Block" then 1 else 0),
			Case.Expected .. " has correct knockback"
		)
		if Case.Expected == "Block" then
			local Force = Created[#Created]
			Check(
				Force.ClassName == "LinearVelocity" and Force.VectorVelocity.Z == -35 * Config.BlockKnockbackMultiplier,
				Case.Expected .. " reduces the fixed kick velocity"
			)
			Check(
				Force.Parent.Lifetime == 0.2 and Force.ForceLimitsEnabled == false,
				Case.Expected .. " uses the combo's force duration without ragdoll"
			)
		end
		Check(
			Impacts == ImpactCount + (if Case.Expected == "Dodge" then 0 else 1),
			Case.Expected .. " has correct impact audio"
		)
		Target:SetAttribute(Case.Attribute, false)
	end
	Target:SetAttribute("RollIFrame", true)
	Target:SetAttribute("Blocking", true)
	Target:SetAttribute("DeflectTime", true)
	Check(
		Hit:NormalHit(Target, Attacker, 4, { By = "Kick" }) == "Dodge",
		"Dodge takes priority over overlapping defensive states"
	)
	for _, Attribute in { "RollIFrame", "Blocking", "DeflectTime", "BeenHitted" } do
		Target:SetAttribute(Attribute, false)
	end
	Step(2)
	Attacker:SetAttribute("Strength", 10)
	World.Wall = true
	local Before = Target:GetAttribute("Health")
	Kick:Kick(Attacker)
	Step(Config.HitDelay + 0.01)
	Check(Target:GetAttribute("Health") == Before, "Walls prevent kick damage")
	World.Wall = false
	Step(0.01)
	Check(Target:GetAttribute("Health") == Before - 10, "Kick damage scales with server Strength")
	Step(Config.Duration)
	Check(not Attacker:GetAttribute("Kicking"), "Movement restriction clears after kick")
	Target:SetAttribute("Ragdoll", true)
	Target.Mass = 10
	Knockback:Fling(Target, Attacker)
	local LightTargetVelocity = Created[#Created].VectorVelocity.Z
	local BeforePushes = Pushes()
	Target.Mass = 200
	Knockback:Fling(Target, Attacker)
	local DefaultVelocity = Created[#Created].VectorVelocity.Z
	Check(
		Pushes() == BeforePushes + 1 and DefaultVelocity < 0,
		"An already ragdolled target still receives the combo push"
	)
	Check(DefaultVelocity == LightTargetVelocity, "Heavy targets receive the same combo speed as light targets")
	Knockback:FlingInDirection(Target, Vector.new(1, 0, 0))
	Check(
		Created[#Created].VectorVelocity.X == -DefaultVelocity and Created[#Created].VectorVelocity.Z == 0,
		"Door impacts can use the kick direction instead of the direction from attacker to target"
	)
	local BeforeZeroDirection = Pushes()
	Knockback:FlingInDirection(Target, Vector.new(0, 0, 0))
	Check(Pushes() == BeforeZeroDirection, "Zero-length impact directions cannot create invalid forces")
	Config.KnockbackSpeed = 26
	Target:SetAttribute("Ragdoll", false)
	local BeforeRagdolls = Ragdolls
	Kick:HitTarget(Attacker, Target)
	Check(Ragdolls == BeforeRagdolls + 1, "KickConfig controls speed when entering ragdoll")
	Kick:HitTarget(Attacker, Target)
	Check(
		Created[#Created].VectorVelocity.Z == -26,
		"Kick speed stays fixed when target mass increases"
	)
	Config.KnockbackSpeed = 7
	Target:SetAttribute("Blocking", true)
	Kick:HitTarget(Attacker, Target)
	Check(Created[#Created].VectorVelocity.Z == -7 * Config.BlockKnockbackMultiplier, "Blocked kicks use reduced configured speed")
	Target:SetAttribute("Blocking", false)
	Target:SetAttribute("Ragdoll", false)
	Knockback:Fling(Target, Attacker)
	Check(Ragdolls == BeforeRagdolls + 2, "The combo retains its default speed after changing KickConfig")
	Check(
		Created[#Created].VectorVelocity.Z == DefaultVelocity,
		"Changing kick configuration does not change the default combo strength"
	)
	Target:SetAttribute("Ragdoll", false)
	Knockback:FlingWithVelocity(Target, Vector.new(35, 2, 0))
	Check(
		Target:GetAttribute("Ragdoll")
			and Created[#Created].VectorVelocity.X == 35
			and Created[#Created].VectorVelocity.Y == 2,
		"A moving door can transfer its velocity directly without scaling it by target mass"
	)
	Target:SetAttribute("IntroTutorialProtected", true)
	Target:SetAttribute("Ragdoll", false)
	local ProtectedHealth, ProtectedPushes = Target:GetAttribute("Health"), Pushes()
	Kick:HitTarget(Attacker, Target)
	Check(Pushes() == ProtectedPushes and Target:GetAttribute("Health") == ProtectedHealth,
		"A protected lesson actor is not pushed or damaged by an unrequested kick")
	TutorialResult = "TutorialKick"
	Kick:HitTarget(Attacker, Target)
	Check(Target:GetAttribute("Health") == ProtectedHealth and Target:GetAttribute("Ragdoll")
		and Pushes() == ProtectedPushes + 1,
		"A confirmed tutorial kick pushes and ragdolls the protected opponent without dealing damage")
	local Rolls, Blocks = 0, 0
	Services.MovementService = {
		Roll = function(_Self: any, Subject: any, Direction: string, StartCFrame: any)
			Check(Subject == Target and StartCFrame == Target.PrimaryPart.CFrame,
				"AI dodge supplies the start frame required by MovementService")
			Check(Direction == "Left" or Direction == "Right", "AI dodges sideways")
			Rolls += 1
			Subject:SetAttribute("RollIFrame", true)
			Subject:SetAttribute("Rolling", true)
		end,
	}
	Services.PostureService.Block = function(_Self: any, Subject: any, Enabled: boolean): boolean
		Subject:SetAttribute("Blocking", Enabled)
		if Enabled then
			Blocks += 1
			Subject:SetAttribute("DeflectTime", true)
			Task.delay(0.175, function()
				Subject:SetAttribute("DeflectTime", false)
			end)
		end
		return Enabled
	end
	local Reaction = Load("Reaction")
	Reaction.KnitInit()
	local RandomValues = {}
	Env.math = table.clone(math)
	Env.math.random = function(): number
		return table.remove(RandomValues, 1) or 1
	end
	local ReactionConfig = { ActionChance = 100, DeflectChance = 70, RollChance = 30, Actions = { "Roll" } }
	local function ResetReaction()
		Step(1)
		for _, Attribute in { "Ragdoll", "BeenHitted", "Blocking", "DeflectTime", "Rolling", "RollIFrame", "RollDebounce" } do
			Target:SetAttribute(Attribute, false)
		end
		Target:SetAttribute("IntroTutorialProtected", false)
		Target.PrimaryPart.CFrame.LookVector = Vector.new(0, 0, 1)
		Target.PrimaryPart.CFrame.RightVector = Vector.xAxis
		Attacker:SetAttribute("Kicking", true)
	end
	ResetReaction()
	RandomValues = { 1, 100, 1 }
	Reaction:ReactToKick(Target, Attacker, ReactionConfig, 0.27)
	Step(0.1)
	Check(not Target:GetAttribute("Blocking"), "Parry waits until close to contact")
	Step(0.1)
	Check(Target:GetAttribute("DeflectTime"), "Late guard opens a parry window")
	Step(0.07)
	Check(Target:GetAttribute("DeflectTime"), "Parry window overlaps the kick contact time")

	ResetReaction()
	RandomValues = { 1, 100, 100 }
	Reaction:ReactToKick(Target, Attacker, ReactionConfig, 0.27)
	Step(0)
	Check(Target:GetAttribute("Blocking"), "Failed parry choice still raises an early guard")
	Step(0.27)
	Check(Target:GetAttribute("Blocking") and not Target:GetAttribute("DeflectTime"),
		"Early guard resolves as a normal block at contact")
	Step(0.25)
	Check(not Target:GetAttribute("Blocking"), "Guard ends after the kick hit window")

	ResetReaction()
	RandomValues = { 1, 1, 1, 1 }
	Reaction:ReactToKick(Target, Attacker, ReactionConfig, 0.27)
	Step(0.2)
	Check(Rolls == 1 and Target:GetAttribute("RollIFrame"), "Configured dodge enters the authoritative roll state")
	Check(Created[#Created].VectorVelocity.X == -25, "AI dodge physically moves sideways at a bounded speed")

	ResetReaction()
	local BeforeBlocks, BeforeRolls = Blocks, Rolls
	RandomValues = { 1, 100, 1 }
	Reaction:ReactToKick(Target, Attacker, ReactionConfig, 0.27)
	Attacker:SetAttribute("Kicking", false)
	Step(0.2)
	Check(Blocks == BeforeBlocks and Rolls == BeforeRolls, "Cancelled kick cannot cause a delayed defense")

	ResetReaction()
	Target:SetAttribute("BeenHitted", true)
	Reaction:ReactToKick(Target, Attacker, ReactionConfig, 0)
	Step(0)
	Check(Blocks == BeforeBlocks and Rolls == BeforeRolls, "Stunned enemies cannot react to kicks")
	Target:SetAttribute("BeenHitted", false)
	Target.PrimaryPart.CFrame.LookVector = Vector.new(0, 0, -1)
	Reaction:ReactToKick(Target, Attacker, ReactionConfig, 0)
	Step(0)
	Check(Blocks == BeforeBlocks and Rolls == BeforeRolls, "Enemies do not defend against unseen kicks from behind")
	Target.PrimaryPart.CFrame.LookVector = Vector.new(0, 0, 1)
	Target:SetAttribute("IntroTutorialActive", true)
	Reaction:ReactToKick(Target, Attacker, ReactionConfig, 0)
	Step(0)
	Check(Blocks == BeforeBlocks and Rolls == BeforeRolls, "Scripted tutorial defense is preserved")
	Target:SetAttribute("IntroTutorialActive", false)
	ReactionConfig.ActionChance = 0
	Reaction:ReactToKick(Target, Attacker, ReactionConfig, 0)
	Step(0)
	Check(Blocks == BeforeBlocks and Rolls == BeforeRolls, "Reaction respects configured action chance")
	local KickInputs, ClimbInputs = 0, 0
	local CanEnterClimb = false
	local Mouse = {
		Button1Down = Signal(), Button1Up = Signal(),
		Button2Down = Signal(), Button2Up = Signal(),
	}
	function Player:GetMouse(): any
		return Mouse
	end
	Players.LocalPlayer = Player
	Engine.UserInputService = { InputBegan = Signal(), InputEnded = Signal() }
	Env.Enum.KeyCode = { G = { Name = "G" } }
	Env.Enum.UserInputState = { Begin = 1, End = 2, Cancel = 3 }
	Env.Enum.UserInputType = { MouseButton1 = {}, MouseButton2 = {} }
	Env.Enum.PreferredInput = { Gamepad = {} }
	Knit.GetController = function(Name: string): any
		Check(Name == "KickController", "Shared key routes to the kick controller")
		return { HandleInput = function()
			KickInputs += 1
		end }
	end
	Modules.ClimbAction = {
		keys = { Env.Enum.KeyCode.G },
		callback = function()
			ClimbInputs += 1
			Attacker:SetAttribute("Climbing", not Attacker:GetAttribute("Climbing") and CanEnterClimb)
		end,
	}
	Env.script = { Parent = { Actions = { GetChildren = function(): { any }
		return { { Name = "Climb", IsA = function(): boolean
			return true
		end } }
	end } } }
	local OriginalRequire = Env.require
	Env.require = function(Value: any): any
		return if type(Value) == "table" and Value.Name == "Climb" then Modules.ClimbAction else OriginalRequire(Value)
	end
	local Input = Load("Input")
	Input.Start()
	local Key = { Name = "InputObject", KeyCode = Env.Enum.KeyCode.G }
	local function PressG(Processed: boolean?)
		Engine.UserInputService.InputBegan:Fire(Key, Processed)
	end
	Attacker:SetAttribute("Climbing", true)
	PressG()
	Check(not Attacker:GetAttribute("Climbing") and KickInputs == 0,
		"G releases the wall without also triggering a kick")
	CanEnterClimb = true
	PressG()
	Check(Attacker:GetAttribute("Climbing") and KickInputs == 0,
		"G grabs a climbable wall without also triggering a kick")
	PressG()
	Check(not Attacker:GetAttribute("Climbing") and KickInputs == 0,
		"Repeated wall release still consumes the shared key")
	CanEnterClimb = false
	PressG()
	Check(KickInputs == 1, "G kicks normally when climbing does not consume the key")
	local BeforeClimbInputs = ClimbInputs
	PressG(true)
	Engine.UserInputService.InputEnded:Fire(Key, false)
	Check(KickInputs == 1 and ClimbInputs == BeforeClimbInputs,
		"Processed input and key release do not trigger either action")
	Attacker:SetAttribute("IntroTutorialAction", "Kick")
	Player:SetAttribute("InIntroCutscene", true)
	PressG()
	Check(KickInputs == 2 and ClimbInputs == BeforeClimbInputs,
		"Kick lesson still accepts G when climbing is unavailable")
	return "Kick: " .. Checks .. " checks passed"
end
