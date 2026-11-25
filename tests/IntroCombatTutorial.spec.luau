return function(Source: string, DamageSource: string, ValidateSource: string): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local Vector = {}
	local function V(X: number, Y: number, Z: number): any
		return setmetatable({ X = X, Y = Y, Z = Z }, Vector)
	end
	Vector.__sub = function(A: any, B: any): any
		return V(A.X - B.X, A.Y - B.Y, A.Z - B.Z)
	end
	Vector.__add = function(A: any, B: any): any
		return V(A.X + B.X, A.Y + B.Y, A.Z + B.Z)
	end
	Vector.__mul = function(A: any, B: any): any
		return if type(B) == "number" then V(A.X * B, A.Y * B, A.Z * B) else V(A.X * B.X, A.Y * B.Y, A.Z * B.Z)
	end
	Vector.__index = function(A: any, Key: string): any
		local M = math.sqrt(A.X ^ 2 + A.Y ^ 2 + A.Z ^ 2)
		return if Key == "Magnitude" then M else V(A.X / M, A.Y / M, A.Z / M)
	end
	local function Signal(): any
		local S = { Calls = {}, Listeners = {} }
		function S:Connect(Callback: (...any) -> ()): any
			local C = { Connected = true }
			function C.Disconnect(Current: any)
				Current.Connected = false
			end
			table.insert(self.Listeners, { Callback, C })
			return C
		end
		function S:Fire(...: any)
			table.insert(self.Calls, { ... })
			for _, L in table.clone(self.Listeners) do
				if L[2].Connected then
					L[1](...)
				end
			end
		end
		return S
	end
	local function Object(): any
		local Attributes, Signals = {}, {}
		local O = { Parent = true, Destroying = Signal() }
		function O:GetAttribute(Name: string): any
			return Attributes[Name]
		end
		function O:SetAttribute(Name: string, Value: any)
			if Attributes[Name] == Value then
				return
			end
			Attributes[Name] = Value
			if Signals[Name] then
				Signals[Name]:Fire()
			end
		end
		function O:GetAttributeChangedSignal(Name: string): any
			Signals[Name] = Signals[Name] or Signal()
			return Signals[Name]
		end
		function O:FindFirstChild(Name: string): any
			return self[Name]
		end
		function O:FindFirstChildWhichIsA(Class: string): any
			return if Class == "Humanoid" then self.Humanoid else nil
		end
		return O
	end
	local function Fixture(): any
		local Now, Jobs = 0, {}
		local Config = {
			Enabled = true,
			PauseBeforeHit = 0.06,
			ParryRecoveryTime = 0.5,
			EnemyParryRecovery = 0.85,
			CounterattackTimeout = 10,
			RecoveryTime = 1.85,
			ReactionReleaseTime = 0.12,
			ParryWindow = 0.65,
			DodgeWindow = 0.65,
			MaximumDistance = 24,
		}
		local function Model(X: number): any
			local O = Object()
			O.PrimaryPart = { Anchored = false }
			O.Humanoid = { Health = 120 }
			O.Frame = { Position = V(X, 10, 0), LookVector = V(1, 0, 0) }
			O:SetAttribute("Health", 120)
			O:SetAttribute("MaxStamina", 100)
			function O:GetPivot(): any
				return self.Frame
			end
			function O:PivotTo(Frame: any)
				self.Frame = Frame
			end
			return O
		end
		local Player = Object()
		Player.Character, Player.CharacterRemoving = Model(0), Signal()
		local Boss = Model(6)
		Boss.Runner = Object()
		Boss.Runner:SetAttribute("Enabled", true)
		Boss:SetAttribute("WanderingNpc", false)
		local Players = { PlayerAdded = Signal(), PlayerRemoving = Signal() }
		function Players:GetPlayers(): any
			return { Player }
		end
		function Players:GetPlayerFromCharacter(Character: any): any
			return if Character == Player.Character then Player else nil
		end
		local Feedback = { Parry = 0, Dodge = 0, Completed = 0, Defenders = {} }
		local function Swing(): (any, any)
			local Track = { Speed = 1, TimePosition = 0.38, Length = 1.2, IsPlaying = true }
			Feedback.LastSwing = Track
			function Track:AdjustSpeed(Speed: number)
				self.Speed = Speed
			end
			function Track:Stop()
				self.Stopped = true
				self.IsPlaying = false
			end
			function Track:Destroy()
				self.Destroyed = true
			end
			local Animation = {
				GetAttribute = function()
					return 0.5
				end,
			}
			return Track, Animation
		end
		local Services = {
			PostureService = {
				Block = function(_: any, Character: any, State: boolean)
					Character:SetAttribute("Blocking", State)
				end,
				Deflected = function(_: any, Defender: any, _: any, Damage: number)
					assert(Damage == 0, "Tutorial feedback must never deal damage")
					Feedback.Parry += 1
					table.insert(Feedback.Defenders, Defender)
				end,
				Dodged = function()
					Feedback.Dodge += 1
				end,
			},
			CharacterService = {
				EnableForceField = function(_: any, Character: any, State: boolean)
					Character:SetAttribute("ForceField", State)
				end,
			},
			BuffService = { RemoveBuffsByType = function() end },
			WeaponService = { PlayM1Animation = Swing },
		}
		local Knit = {
			CreateSignal = Signal,
			CreateService = function(Definition: any): any
				return Definition
			end,
			GetService = function(Name: string): any
				return Services[Name]
			end,
		}
		local Env = setmetatable({
			game = {
				Players = Players,
				GetService = function(_: any, Name: string): any
					return if Name == "Players"
						then Players
						else {
							Packages = { Knit = "Knit" },
							Shared = { IntroCutsceneConfig = "Config", StatProgression = "Progression", KickConfig = "KickConfig" },
						}
				end,
			},
			require = function(Name: string): any
				return if Name == "Knit" then Knit elseif Name == "KickConfig" then { StaminaCost = 10 } else { CombatTutorial = Config }
			end,
			Vector3 = { new = V, zero = V(0, 0, 0) },
			CFrame = {
				lookAt = function(Position: any, Target: any): any
					return { Position = Position, LookVector = (Target - Position).Unit }
				end,
			},
			os = {
				clock = function(): number
					return Now
				end,
			},
			task = {
				delay = function(Time: number, Callback: () -> ())
					table.insert(Jobs, { At = Now + Time, Callback = Callback })
				end,
			},
		}, { __index = getfenv() })
		local function Load(Text: string): any
			local Chunk = assert(loadstring(Text))
			setfenv(Chunk, Env)
			return Chunk()
		end
		local Service, Damage = Load(Source), Load(DamageSource)
		Service.KnitInit()
		Service.KnitStart()
		local F = {
			Player = Player,
			Character = Player.Character,
			Boss = Boss,
			Config = Config,
			Service = Service,
			Feedback = Feedback,
			Damage = Damage,
			Validate = Load(ValidateSource),
			Model = Model,
		}
		function F:Advance(Time: number)
			local Finish = Now + Time
			repeat
				table.sort(Jobs, function(A: any, B: any): boolean
					return A.At < B.At
				end)
				if not Jobs[1] or Jobs[1].At > Finish then
					break
				end
				local Job = table.remove(Jobs, 1)
				Now = Job.At
				Job.Callback()
			until false
			Now = Finish
		end
		function F:Start(): boolean
			return Service:Arm(Player, self.Character, Boss, { Name = "Ship" }, "token", function()
				Feedback.Completed += 1
			end)
		end
		function F:Capture(HitDelay: number?, Speed: number?): any
			local Track, Animation = Swing()
			Track.Speed = Speed or 1
			Check(
				Service:CaptureSwordAttack(Boss, Track, Animation, HitDelay or 0.5),
				"Armed boss sword swing is intercepted"
			)
			return Track
		end
		function F:State(): any
			return Service.Client.StateChanged.Calls[#Service.Client.StateChanged.Calls]
		end
		function F:Explain()
			if self:State()[5] == "Incoming" then
				self:Advance(0.5 - self.Config.PauseBeforeHit + 0.01)
			end
		end

		return F
	end

	local F = Fixture()
	Check(F:Start(), "Tutorial arms during live combat")
	Check(
		#F.Service.Client.StateChanged.Calls == 0 and not F.Character.PrimaryPart.Anchored,
		"Arming does not show a lesson or move the player"
	)
	Check(F.Service.Client.Continue == nil and F.Service.Client.Ready == nil, "No Continue or Ready action is required")
	F:Advance(100)
	Check(#F.Service.Client.StateChanged.Calls == 0, "Tutorial waits for the real first sword swing")
	Check(
		not F.Damage:CanDamage(F.Character) and F.Damage:CanDamage(F.Model(200)),
		"Damage protection stays scoped to lesson actors"
	)
	local Track = F:Capture()
	Check(F:State()[5] == "Incoming" and Track.Speed == 1, "Sword starts normally before the pause")
	F:Advance(0.5 - F.Config.PauseBeforeHit - 0.01)
	Check(F:State()[5] == "Incoming", "Sword does not freeze at its start")
	F:Advance(0.02)
	Check(F:State()[5] == "Explain" and Track.Speed == 0, "Attack pauses before contact")
	Check(
		F.Character:GetAttribute("IntroTutorialAction") == "Parry" and not F.Character.PrimaryPart.Anchored,
		"The native parry can execute directly from the prompt"
	)
	Check(
		F.Character:GetAttribute("CameraCutscene") == nil and F.Boss:GetPivot().Position.X == 6,
		"Explanation does not change camera mode or reposition the boss"
	)
	Check(F.Character:GetAttribute("SkillLockMovement") == true, "Player cannot walk or jump while waiting for parry")
	F:Advance(100)
	Check(F:State()[5] == "Explain", "No hit deadline runs while waiting for input")
	F.Character:SetAttribute("Blocking", true)
	Check(F:State()[5] == "Practice" and Track.Speed > 0, "Pressing real block releases the paused swing")
	Check(F.Character:GetAttribute("SkillLockMovement") == false, "Parry input releases the movement pause")
	F.Character:SetAttribute("Blocking", false)
	F:Advance(0.13)
	Check(
		F:State()[9] == true and F.Feedback.Defenders[1] == F.Character,
		"The same button press performs a successful parry"
	)
	F:Advance(F.Config.ParryRecoveryTime)
	Check(
		F:State()[4] == 2 and F:State()[5] == "Explain" and F.Player:GetAttribute("CantAttack") == false,
		"Counterattack prompt immediately accepts actual attack input"
	)
	Check(F.Character:GetAttribute("SkillLockMovement") == true, "Player stays in place while waiting for attack")
	F:Advance(100)
	Check(F:State()[5] == "Explain", "Counterattack also waits for the action instead of a continue button")
	F.Character:SetAttribute("Attack", true)
	Check(F:State()[5] == "Practice", "Native sword action resumes the scene")
	Check(F.Character:GetAttribute("SkillLockMovement") == false, "Attack input releases movement for the real strike")
	Check(
		F.Service:ResolveHit(F.Boss, F.Character, { By = "Weapon", Action = "Attack" }) == "Deflect",
		"Enemy parries the actual counterattack"
	)
	Check(F.Feedback.Defenders[2] == F.Boss and F:State()[5] == "EnemyParry", "Enemy parry appears before its reply")
	F.Service:ResolveHit(F.Boss, F.Character, { By = "Weapon", Action = "Attack" })
	Check(F.Feedback.Parry == 2, "Duplicate hit callbacks do not repeat the reaction")
	F.Character:SetAttribute("Attack", false)
	F:Advance(F.Config.EnemyParryRecovery)
	Check(F:State()[4] == 3 and F:State()[5] == "Incoming", "Enemy immediately prepares the reply")
	F:Explain()
	Check(F.Character:GetAttribute("IntroTutorialAction") == "Dodge", "Reply pauses to request dodge")
	Check(F.Character:GetAttribute("SkillLockMovement") == true, "Player cannot walk away while waiting for dodge")
	F.Character:SetAttribute("RollDirection", "Forward")
	F.Character:SetAttribute("RollIFrame", true)
	Check(F:State()[5] == "Practice", "Accepted dodge releases the enemy attack")
	Check(
		F.Character:GetAttribute("SkillLockMovement") == false,
		"Dodge input releases movement without anchoring the dash"
	)
	F:Advance(0.13)
	Check(F:State()[9] == false and F.Character:GetAttribute("Health") == 120, "Wrong direction retries without damage")
	Check(
		F.Feedback.LastSwing.IsPlaying and not F.Feedback.LastSwing.Destroyed,
		"A missed dodge still lets the enemy finish the attack"
	)
	Check(not F.Character.PrimaryPart.Anchored, "The dodge is not cut short by anchoring the player")
	F:Advance(F.Config.RecoveryTime + 0.5 - F.Config.PauseBeforeHit + 0.01)
	F.Character:SetAttribute("RollIFrame", false)
	F.Character:SetAttribute("RollDirection", "Right")
	F.Feedback.LastSwing.Length = 3
	F.Character:SetAttribute("Rolling", true)
	F.Character:SetAttribute("RollIFrame", true)
	F:Advance(0.13)
	Check(F:State()[9] == true and F.Feedback.Dodge == 1, "The actual sideways dodge completes the lesson")
	Check(
		F.Feedback.LastSwing.IsPlaying and F.Feedback.LastSwing.Speed == 1 and not F.Feedback.LastSwing.Destroyed,
		"Successful dodge preserves the enemy follow-through at normal speed"
	)
	Check(F.Feedback.Completed == 0, "Combat stays paused until the successful dash ends")
	F:Advance(0.3)
	Check(F.Feedback.Completed == 0, "The lesson does not interrupt a dash still in progress")
	F.Character:SetAttribute("Rolling", false)
	Check(F.Feedback.Completed == 0 and not F.Boss.Runner:GetAttribute("Enabled"), "Dash completion keeps the boss in the tutorial for kick practice")
	Check(F.Feedback.LastSwing.Destroyed, "Starting the kick lesson releases the old tutorial animation")
	Check(F:State()[4] == 4 and F:State()[5] == "Explain" and F.Character:GetAttribute("IntroTutorialAction") == "Kick",
		"Kick is taught immediately after the successful dodge ends")
	Check(F.Validate:CanKick(F.Character) and not F.Validate:CanAttack(F.Character) and not F.Validate:CanRoll(F.Character),
		"The kick prompt enables the real kick and rejects other combat actions")
	Check(not F.Character:GetAttribute("SkillLockMovement"), "The player can approach the opponent before kicking")
	F:Advance(100)
	Check(F:State()[5] == "Explain", "The kick prompt waits for the player's actual input")
	F.Character:SetAttribute("Kicking", true)
	Check(F:State()[5] == "Practice" and not F.Boss.PrimaryPart.Anchored,
		"Native kick input releases the opponent so the impact can push them away")
	F.Character:SetAttribute("Kicking", false)
	F:Advance(F.Config.CounterattackTimeout + 0.01)
	Check(F:State()[4] == 4 and F:State()[9] == false and F.Feedback.Completed == 0, "A kick that misses does not complete the tutorial")
	F:Advance(F.Config.RecoveryTime)
	Check(F.Character:GetAttribute("IntroTutorialAction") == "Kick", "A missed kick retries the kick lesson")
	F.Character:SetAttribute("Kicking", true)
	Check(F.Service:ResolveHit(F.Boss, Object(), { By = "Kick", Action = "Kick" }) == "TutorialBlocked",
		"Another player cannot complete the kick lesson")
	Check(F.Service:ResolveHit(F.Boss, F.Character, { By = "Weapon", Action = "Attack" }) == "TutorialBlocked",
		"A sword hit cannot substitute for the required kick")
	Check(F.Service:ResolveHit(F.Boss, F.Character, { By = "Kick", Action = "Kick" }) == "TutorialKick",
		"The owner's actual kick hit completes the practice without damage")
	Check(F.Service:ResolveHit(F.Boss, F.Character, { By = "Kick", Action = "Kick" }) == "TutorialBlocked",
		"Duplicate kick contacts cannot repeat the completion")
	Check(F.Feedback.Completed == 0, "The successful kick finishes its animation before normal combat resumes")
	F.Character:SetAttribute("Kicking", false)
	Check(F.Feedback.Completed == 1 and F.Boss.Runner:GetAttribute("Enabled"), "Completing the kick resumes boss AI exactly once")
	Check(not F.Player:GetAttribute("CantAttack"), "Player can attack as soon as the kick finishes")
	F.Character:SetAttribute("WeaponEquipped", true)
	F.Character:SetAttribute("Weapon", "BasicKatana")
	F.Character:SetAttribute("SwordStaminaCost", 1)
	Check(F.Validate:CanAttack(F.Character), "The native attack validator accepts the post-dash attack")
	Check(
		F.Character:GetAttribute("IntroTutorialAction") == nil
			and F.Character:GetAttribute("IntroTutorialProtected") == nil,
		"Completion restores normal input and damage"
	)
	Check(
		F.Boss:GetAttribute("IntroTutorialActive") == nil and not F.Boss.PrimaryPart.Anchored,
		"Boss is released without respawning"
	)
	F:Advance(100)
	Check(F.Feedback.Completed == 1, "Stale timers cannot complete twice")

	local EarlyHitbox = Fixture()
	EarlyHitbox:Start()
	local EarlyTrack = EarlyHitbox:Capture(0.2)
	EarlyHitbox:Advance(0.3)
	Check(EarlyHitbox:State()[5] == "Incoming" and EarlyTrack.Speed == 1,
		"A generic early hitbox delay does not show the parry prompt at the start of the animation")
	EarlyHitbox:Advance(0.15)
	Check(EarlyHitbox:State()[5] == "Explain" and EarlyTrack.Speed == 0,
		"The prompt waits until shortly before the animation's marked impact")
	EarlyHitbox.Service:Cancel(EarlyHitbox.Player)

	local FastSwing = Fixture()
	FastSwing:Start()
	FastSwing:Capture(0.2, 2)
	FastSwing:Advance(0.18)
	Check(FastSwing:State()[5] == "Incoming", "Prompt timing accounts for the animation's playback speed")
	FastSwing:Advance(0.02)
	Check(FastSwing:State()[5] == "Explain", "A faster swing still pauses before its animated impact")
	FastSwing.Service:Cancel(FastSwing.Player)

	local Timeout = Fixture()
	Timeout:Start()
	Timeout:Capture()
	Timeout:Explain()
	Timeout.Character:SetAttribute("Blocking", true)
	Timeout:Advance(0.13 + Timeout.Config.ParryRecoveryTime)
	Timeout.Character:SetAttribute("Attack", true)
	Timeout:Advance(Timeout.Config.CounterattackTimeout + 0.01)
	Check(Timeout:State()[4] == 2 and Timeout:State()[9] == false, "A missed real attack retries counterattack")
	Timeout:Advance(Timeout.Config.RecoveryTime)
	Check(
		Timeout:State()[5] == "Explain" and Timeout.Character:GetAttribute("IntroTutorialAction") == "Attack",
		"Retry is ready for another native attack"
	)
	Timeout.Service:Cancel(Timeout.Player)

	local Cancelled = Fixture()
	Cancelled:Start()
	local CancelTrack = Cancelled:Capture()
	Cancelled:Explain()
	Cancelled.Player.CharacterRemoving:Fire(Cancelled.Character)
	Cancelled:Advance(100)
	Check(Cancelled.Feedback.Completed == 0 and CancelTrack.Destroyed, "Respawn cancels animation and queued work")
	Check(
		Cancelled.Character:GetAttribute("IntroTutorialAction") == nil
			and Cancelled.Character:GetAttribute("IntroTutorialProtected") == nil,
		"Respawn removes lesson-specific input restrictions"
	)

	local Disabled = Fixture()
	Disabled.Config.Enabled = false
	Check(
		not Disabled:Start() and Disabled.Damage:CanDamage(Disabled.Character),
		"Disabled tutorial leaves normal combat untouched"
	)
	Check(
		not Disabled.Service:CaptureSwordAttack(Disabled.Boss, {}, {}, 0.5),
		"Unarmed attacks retain their ordinary hitboxes"
	)
	local Isolated = Fixture()
	Isolated:Start()
	Isolated:Capture()
	Isolated:Explain()
	Check(
		Isolated.Service:ResolveHit(Isolated.Boss, Object(), { By = "Weapon", Action = "Attack" }) == "TutorialBlocked",
		"Other players cannot complete the counterattack"
	)
	Check(Isolated:State()[5] == "Explain", "Unrelated input cannot advance the owner lesson")
	Check(
		Isolated.Service:ResolveHit(Isolated.Model(200), Isolated.Character, {}) == nil,
		"Other combat is not intercepted"
	)
	Isolated.Service:Cancel(Isolated.Player)
	local Inputs = Fixture()
	Inputs.Character:SetAttribute("WeaponEquipped", true)
	Inputs.Character:SetAttribute("Weapon", "BasicKatana")
	Inputs.Character:SetAttribute("SwordStaminaCost", 1)
	Inputs.Character:SetAttribute("Stamina", 100)
	Check(
		Inputs.Validate:CanAttack(Inputs.Character) and Inputs.Validate:CanRoll(Inputs.Character),
		"Normal input stays available outside the lesson"
	)
	Inputs.Player:SetAttribute("InIntroCutscene", true)
	for _, Action in { "Meditate", "Climb", "WallRun", "Vault", "Run", "StrongAttack", "Skill", "Tool", "Crouch", "Jump", "LockOn" } do
		Check(not Inputs.Validate:CanPerformIntroAction(Inputs.Character, Action), "Intro rejects unnecessary action: " .. Action)
	end
	Check(not Inputs.Validate:CanUseSkill(Inputs.Character, 0), "Intro blocks skill use before lesson prompts")
	Inputs.Character:SetAttribute("IntroOpening", true)
	Check(not Inputs.Validate:CanPerformIntroAction(Inputs.Character, "Attack"), "Opening blocks manual combat input")
	Inputs.Character:SetAttribute("IntroOpening", false)
	Inputs.Character:SetAttribute("IntroTutorialAction", "Parry")
	Check(
		Inputs.Validate:CanBlock(Inputs.Character)
			and not Inputs.Validate:CanAttack(Inputs.Character)
			and not Inputs.Validate:CanRoll(Inputs.Character),
		"Parry prompt accepts the native parry button only"
	)
	Inputs.Character:SetAttribute("IntroTutorialAction", "Attack")
	Check(
		Inputs.Validate:CanAttack(Inputs.Character)
			and not Inputs.Validate:CanBlock(Inputs.Character)
			and not Inputs.Validate:CanRoll(Inputs.Character),
		"Attack prompt accepts native light attack"
	)
	Inputs.Character:SetAttribute("IntroTutorialAction", "Dodge")
	Check(
		Inputs.Validate:CanRoll(Inputs.Character)
			and not Inputs.Validate:CanBlock(Inputs.Character)
			and not Inputs.Validate:CanAttack(Inputs.Character),
		"Dodge prompt accepts the native roll button"
	)
	Check(not Inputs.Validate:CanKick(Inputs.Character), "Dodge prompt cannot be skipped using kick")
	Inputs.Character:SetAttribute("IntroTutorialAction", "Kick")
	Check(Inputs.Validate:CanKick(Inputs.Character) and not Inputs.Validate:CanAttack(Inputs.Character)
		and not Inputs.Validate:CanBlock(Inputs.Character) and not Inputs.Validate:CanRoll(Inputs.Character),
		"Kick prompt accepts the native kick button only")
	Check(
		not Inputs.Validate:CanEquipWeapon(Inputs.Character) and not Inputs.Validate:CanStrongAttack(Inputs.Character),
		"Unrequested weapon changes cannot derail the lesson"
	)
	Inputs.Character:SetAttribute("IntroTutorialAction", "Wait")
	Check(not Inputs.Validate:CanAttack(Inputs.Character) and not Inputs.Validate:CanBlock(Inputs.Character)
		and not Inputs.Validate:CanRoll(Inputs.Character) and not Inputs.Validate:CanKick(Inputs.Character), "Result stages block input until the lesson advances")
	Inputs.Character:SetAttribute("IntroTutorialAction", nil)
	Inputs.Player:SetAttribute("InIntroCutscene", false)
	Check(
		Inputs.Validate:CanAttack(Inputs.Character)
			and Inputs.Validate:CanBlock(Inputs.Character)
			and Inputs.Validate:CanRoll(Inputs.Character),
		"Finishing restores all normal input"
	)
	Check(Inputs.Validate:CanPerformIntroAction(Inputs.Character, "Meditate"), "Finishing the introduction restores other actions")
	return string.format("IntroCombatTutorial: %d checks passed", Checks)
end
