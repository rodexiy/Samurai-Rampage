return function(Sources: { [string]: string }): string
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
	Vector.__unm = function(A: any): any
		return V(-A.X, -A.Y, -A.Z)
	end
	Vector.__mul = function(A: any, B: any): any
		return if type(B) == "number" then V(A.X * B, A.Y * B, A.Z * B) else V(A.X * B.X, A.Y * B.Y, A.Z * B.Z)
	end
	function Vector.Dot(A: any, B: any): number
		return A.X * B.X + A.Y * B.Y + A.Z * B.Z
	end
	Vector.__index = function(A: any, Name: string): any
		if Name == "Dot" then
			return Vector.Dot
		end
		local Magnitude = math.sqrt(A.X ^ 2 + A.Y ^ 2 + A.Z ^ 2)
		return if Name == "Magnitude" then Magnitude else V(A.X / Magnitude, A.Y / Magnitude, A.Z / Magnitude)
	end

	local function Signal(): any
		local Result = { Calls = {}, Listeners = {} }
		function Result:Connect(Callback: (...any) -> ()): any
			local Connection = { Connected = true }
			function Connection.Disconnect(Current: any)
				Current.Connected = false
			end
			table.insert(self.Listeners, { Callback, Connection })
			return Connection
		end
		function Result:Fire(...: any)
			table.insert(self.Calls, { ... })
			for _, Listener in table.clone(self.Listeners) do
				if Listener[2].Connected then
					Listener[1](...)
				end
			end
		end
		return Result
	end

	local function Object(Attributes: { [string]: any }?): any
		local Values, Signals = Attributes or {}, {}
		local Result = { Parent = true }
		function Result:GetAttribute(Name: string): any
			return Values[Name]
		end
		function Result:SetAttribute(Name: string, Value: any)
			if Values[Name] == Value then
				return
			end
			Values[Name] = Value
			if Signals[Name] then
				Signals[Name]:Fire()
			end
		end
		function Result:GetAttributeChangedSignal(Name: string): any
			Signals[Name] = Signals[Name] or Signal()
			return Signals[Name]
		end
		function Result:FindFirstChild(Name: string): any
			return self[Name]
		end
		function Result:Destroy()
			self.Parent = nil
		end
		function Result:IsA(Class: string): boolean
			return self.ClassName == Class
		end
		return Result
	end

	local function Fixture(): any
		local Now, Jobs, Created, Services = 0, {}, {}, {}
		local Space = { NPCs = {}, Entity = {} }
		function Space:FindFirstChild(Name: string): any
			return self[Name]
		end
		Space.Important = Object()
		Space.Important.BeachSpawn = Object()
		Space.Important.BeachSpawn.ClassName = "BasePart"
		Space.Important.BeachSpawn.CFrame = 100
		local function Delay(Duration: number, Callback: () -> ())
			table.insert(Jobs, { At = Now + Duration, Callback = Callback })
		end
		local function Actor(Position: number, Health: number, Floor: number?): any
			local Model = Object({ Health = Health, MaxHealth = 120, IntroHealthFloor = Floor, Lifes = 2 })
			Model.Parent = Space.Entity
			Model.PrimaryPart = Object()
			Model.PrimaryPart.Position = V(Position, 0, 0)
			Model.PrimaryPart.CFrame = { LookVector = V(1, 0, 0) }
			Model.PrimaryPart.AssemblyMass = 10
			Model.PrimaryPart.Anchored = false
			function Model:GetPivot(): any
				return {
					Position = self.PrimaryPart.Position,
					LookVector = V(if Position <= 0 then 1 else -1, 0, 0),
					ToOrientation = function(): (number, number, number)
						return 0, 0, 0
					end,
				}
			end
			function Model:IsDescendantOf(Ancestor: any): boolean
				return Ancestor == Space and self.Parent == Space.Entity
			end
			function Model:PivotTo(Frame: any)
				self.Pivot = Frame
			end
			return Model
		end
		local Character, Boss = Actor(0, 100, 40), Actor(10, 700, 500)
		Character:SetAttribute("MaxStamina", 100)
		Boss:SetAttribute("IntroOwnerUserId", 7)
		Boss:SetAttribute("IsAI", true)
		Boss.Runner = Object({ Enabled = true })
		Boss.PrimaryPart.LookPlayer = { Enabled = true }
		local Player = Object()
		Player.UserId, Player.Character = 7, Character
		local PlayerByCharacter = { [Character] = Player }
		local Players = {}
		Players.PlayerRemoving = Signal()
		Player.Parent = Players
		function Players:GetPlayerFromCharacter(Model: any): any
			return PlayerByCharacter[Model]
		end
		function Players:GetPlayerByUserId(Id: number): any
			return if Id == 7 then Player else nil
		end
		local Knit = {}
		function Knit.CreateService(Definition: any): any
			Services[Definition.Name] = Definition
			return Definition
		end
		Knit.CreateController = Knit.CreateService
		Knit.GetController = function(Name: string): any
			return Services[Name]
		end
		function Knit.CreateSignal(): any
			return Signal()
		end
		function Knit.GetService(Name: string): any
			Services[Name] = Services[Name] or {}
			return Services[Name]
		end
		local Effects = { Blood = 0, Damage = 0, Buffs = 0, Animations = 0, Teleports = 0, Checkpoints = 0, Loads = 0 }
		local PlayerData = { IntroCutsceneCompleted = false }
		Services.DataService = {
			GetData = function(): any return PlayerData end,
			IsDataLoaded = function(): boolean return true end,
			Checkpoint = function(): boolean
				Effects.Checkpoints += 1
				return true
			end,
		}
		Services.PlaceService = {
			IsTrading = function(): boolean return false end,
			IsHub = function(): boolean return false end,
			IsArena = function(): boolean return false end,
		}
		Services.CharacterService = {
			GetGroundedCFrame = function(_: any, _: any, Frame: any): any
				return Frame
			end,
			EnableForceField = function(_: any, Model: any, Enabled: boolean)
				Model:SetAttribute("ForceField", Enabled)
			end,
			LoadCharacter = function()
				Effects.Loads += 1
			end,
		}
		Services.IntroCombatTutorialService = { Cancel = function() end }
		Services.SkillService = { ClearSkillData = function() end, TryCancelSkillData = function() end }
		Services.BuffService = {
			RemoveBuffsByType = function(_: any, Model: any)
				Model:SetAttribute("BurnDamage", 0)
			end,
			AddBuff = function()
				Effects.Buffs += 1
			end,
		}
		Services.DebounceService = {
			RemoveCharacterDebounces = function() end,
			AddDebounce = function(_: any, Model: any, Name: string)
				Model:SetAttribute(Name, true)
			end,
		}
		Services.PartyService = {
			GetPlayerParty = function()
				return nil
			end,
		}
		Services.LagCompensationService = { GetCompensation = function(_: any, Target: any): number
			return Target:GetAttribute("Ping") or 0
		end }
		Services.StatService = {
			RecordDamage = function()
				Effects.Damage += 1
			end,
		}
		Services.InCombatService = { SetInCombat = function(_: any, Model: any, Enabled: boolean)
			Model:SetAttribute("InCombat", Enabled)
			if Model == Character then
				Player:SetAttribute("InCombat", Enabled)
			end
		end }
		Services.WeaponService = { SetEquippedState = function(_: any, Model: any, Equipped: boolean)
			Model:SetAttribute("WeaponEquipped", Equipped)
		end }
		Services.AnimationService = {
			StopAnimationFind = function() end,
			StopAttackAnimations = function() end,
			PlayRandomAnimationFromFolder = function()
				Effects.Animations += 1
			end,
		}
		Services.BloodService = {
			HasBloodOnBlade = function()
				return false
			end,
			ApplyBloodOnBlade = function() end,
		}
		Services.RenderService = {
			RenderForAllPlayers = function(_: any, _: any, Effect: string)
				if Effect == "Blood" then
					Effects.Blood += 1
				end
			end,
		}
		local Config = {
			Enabled = true,
			WakeUp = {
				SpawnPath = { "Important", "BeachSpawn" }, SpawnOffset = 1,
				BlackoutTime = 5, FadeTime = 1.25, AnimationDuration = 5, TransitionTime = 2,
				AnimationId = "wake-up",
			},
			Tsunami = {
				ApproachTime = 5,
				HeavyParryTime = 0.85,
				WarningTime = 3,
				Umibozu = { RiseTime = 3, HoldTime = 2 },
				CameraShake = {
					Enabled = true, WarningStrength = 0.35, Frequency = 12,
					PositionAmplitude = 0.45, RotationDegrees = 2.5, RampPower = 2,
				},
			},
			ShipsFolderName = "Ships",
		}
		local Replicated = {
			Packages = { Knit = "Knit" },
			Shared = {
				IntroCutsceneConfig = "Config",
				Utils = { TeleportCharacter = "Teleport", GetModelMass = "Mass" },
				StatProgression = "Progression",
				SkillTreeConfig = "TalentConfig",
			},
			Assets = { Animations = { Combat = { Hit = {} } } },
		}
		local Instance = {
			new = function(Class: string): any
				local New = Object()
				New.ClassName = Class
				if Class == "NumberValue" then
					New.Value = 0
				end
				if Class == "BindableEvent" then
					New.Event = Signal()
					function New:Fire(...: any)
						self.Event:Fire(...)
					end
				end
				table.insert(Created, New)
				return New
			end,
		}
		local RobloxServices = {
			Players = Players,
			ReplicatedStorage = Replicated,
			RunService = { Heartbeat = Signal() },
			HttpService = {},
			Debris = {
				AddItem = function(_: any, Item: any, Duration: number)
					Delay(Duration, function()
						Item:Destroy()
					end)
				end,
			},
		}
		local Env = setmetatable({
			game = {
				GetService = function(_: any, Name: string): any
					return RobloxServices[Name]
				end,
			},
			workspace = Space,
			Instance = Instance,
			Enum = { AnimationPriority = { Action = { Value = 2 }, Action4 = { Value = 5 } } },
			Vector3 = { new = V, zero = V(0, 0, 0) },
			CFrame = {
				new = function(): any
					return {}
				end,
				Angles = function(): any
					return {}
				end,
				lookAt = function(): any
					return {}
				end,
			},
			math = setmetatable({ noise = function() return 0.25 end }, { __index = math }),
			os = setmetatable({ clock = function(): number return Now end }, { __index = os }),
			task = {
				delay = Delay,
				defer = function(Callback: () -> ())
					Delay(0, Callback)
				end,
			},
			require = function(Module: string): any
				if Module == "Knit" then
					return Knit
				elseif Module == "Config" then
					return Config
				elseif Module == "Teleport" then
					return function(Model: any, Frame: any)
						Effects.Teleports += 1
						Model.Pivot = Frame
					end
				elseif Module == "TalentConfig" then
					return { Effects = {} }
				elseif Module == "Mass" then
					return function(Model: any): number
						return Model.PrimaryPart.AssemblyMass
					end
				end
				return {}
			end,
		}, { __index = getfenv() })
		local function Load(Source: string): any
			local Chunk = assert(loadstring(Source))
			setfenv(Chunk, Env)
			return Chunk()
		end
		local Intro = Load(
			(
				Sources.Intro:gsub(
					"return IntroCutsceneService%s*$",
					"IntroCutsceneService.TestSessions = Sessions\nreturn IntroCutsceneService"
				)
			)
		)
		local Posture, Hit, Damage = Load(Sources.Posture), Load(Sources.Hit), Load(Sources.Damage)
		Intro.KnitInit()
		Hit.KnitInit()
		Damage.KnitInit()
		Posture.KnitInit()
		Services.TalentService.RecordDamage = function() end
		local Ship = Object()
		Ship.Name = "Ship"
		function Ship:GetPivot(): any
			return { RightVector = V(1, 0, 0) }
		end
		local Session =
			{ Character = Character, Boss = Boss, Phase = "Combat", Token = "token", Ship = Ship, Slot = 1 }
		Intro.TestSessions[Player] = Session
		local F = {
			Intro = Intro,
			Hit = Hit,
			Damage = Damage,
			Player = Player,
			Character = Character,
			Boss = Boss,
			Session = Session,
			Effects = Effects,
			Created = Created,
			PlayerData = PlayerData,
		}
		function F:EnableMeleeClashes(Allied: boolean?)
			for _, Model in { Character, Boss } do
				Model:SetAttribute("IntroHealthFloor", nil)
				Model:SetAttribute("Health", 100)
			end
			if Allied then
				local OtherPlayer = Object()
				OtherPlayer.Character = Boss
				PlayerByCharacter[Boss] = OtherPlayer
				Services.PartyService.GetPlayerParty = function(): any
					return { Members = { Player, OtherPlayer } }
				end
			end

			local HeavyAnimation = {}
			Replicated.Assets.Animations.Combat.HeavyDeflect = HeavyAnimation
			self.MeleeRenders, self.StoppedAttacks, self.MeleeAnimations = {}, {}, {}
			Services.RenderService.RenderForAllPlayers = function(_: any, _: any, Effect: string, Data: any)
				if Effect == "HeavyDeflect" then
					table.insert(self.MeleeRenders, Data)
				end
			end
			Services.AnimationService.PlayAnimation = function(_: any, Model: any, Animation: any)
				if Animation == HeavyAnimation then
					table.insert(self.MeleeAnimations, Model)
				end
			end
			Services.AnimationService.StopAttackAnimations = function(_: any, Model: any)
				table.insert(self.StoppedAttacks, Model)
			end
			Services.TalentService.Has = function(): boolean
				return false
			end
			Posture.Deflected = function(): string
				return "Deflect"
			end
			Posture.Dodged = function(): string
				return "Dodge"
			end
		end
		function F:AddFighter(Position: number): any
			return Actor(Position, 100, nil)
		end
		function F:LoadClient(): any
			Players.LocalPlayer = Player
			Replicated.Assets.Animations.Combat.HeavyDeflect = {}
			local Animations, Renders = {}, {}
			for _, Model in { Character, Boss } do
				local Animator = {
					GetPlayingAnimationTracks = function()
						return {}
					end,
				}
				local Humanoid = {
					FindFirstChildWhichIsA = function()
						return Animator
					end,
				}
				Model.FindFirstChildWhichIsA = function()
					return Humanoid
				end
			end
			Services.AnimationController = {
				PlayAnimation = function(_: any, Model: any): any
					local Track = { Actor = Model, Speed = 1 }
					function Track.Stop(Current: any)
						Current.Stopped = true
					end
					function Track.Destroy(Current: any)
						Current.Destroyed = true
					end
					table.insert(Animations, Track)
					return Track
				end,
			}
			Services.RenderController = {
				Render = function(Data: any)
					table.insert(Renders, Data)
				end,
			}
			Services.CombatMusicController = { FadeOut = function() end }
			Services.CutsceneUIController = { Prepare = function(_: any, Blackout: boolean?)
				self.Blackout = Blackout
			end }
			Services.CutsceneController = { Begin = function(_: any, _: any, Transform: any)
				self.CameraTransform = Transform
			end }
			Services.IntroCutsceneController = { ApplyCameraSway = function(_: any, Frame: any): any
				return Frame
			end }
			local Client = Load(Sources.Client)
			Client.KnitInit()
			self.ClientAnimations, self.ClientRenders = Animations, Renders
			return Client
		end
		function F:Advance(Duration: number)
			local Finish = Now + Duration
			table.sort(Jobs, function(A: any, B: any): boolean
				return A.At < B.At
			end)
			while Jobs[1] and Jobs[1].At <= Finish do
				local Job = table.remove(Jobs, 1)
				Now = Job.At
				Job.Callback()
				table.sort(Jobs, function(A: any, B: any): boolean
					return A.At < B.At
				end)
			end
			Now = Finish
		end
		return F
	end

	for _, TargetIsPlayer in { true, false } do
		for _, HugeHit in { false, true } do
			local F = Fixture()
			local Target, Attacker =
				if TargetIsPlayer then F.Character else F.Boss, if TargetIsPlayer then F.Boss else F.Character
			local Health = Target:GetAttribute("Health")
			local Damage = if HugeHit then 100000 else Health - Target:GetAttribute("IntroHealthFloor")
			Check(
				F.Hit:NormalHit(Target, Attacker, Damage, { By = "Weapon" }) == "HeavyParry",
				"Boundary hit becomes a heavy parry"
			)
			Check(Target:GetAttribute("Health") == Health, "Intercepted hit does not change health")
			Check(F.Boss:GetAttribute("Lifes") == 2, "Boss phase is preserved")
			Check(
				F.Effects.Blood == 0 and F.Effects.Buffs == 0 and F.Effects.Damage == 0 and F.Effects.Animations == 0,
				"Intercepted hit has no normal blood, burn, damage rewards or hit animation"
			)
			Check(
				F.Character:GetAttribute("HeavyDeflect") and F.Boss:GetAttribute("HeavyDeflect"),
				"Both actors receive heavy parry"
			)
			Check(
				F.Boss.Runner:GetAttribute("Enabled") == false and F.Boss:GetAttribute("WanderingNpc"),
				"Boss AI stops immediately"
			)
			Check(
				#F.Intro.Client.TsunamiParry.Calls == 1 and #F.Intro.Client.TsunamiStarted.Calls == 0,
				"Parry precedes tsunami"
			)
			local Velocities = {}
			for _, Created in F.Created do
				if Created.ClassName == "BodyVelocity" then
					table.insert(Velocities, Created.Velocity.X)
				end
			end
			Check(#Velocities == 2 and Velocities[1] * Velocities[2] < 0, "Actors recoil away from one another")
			F.Hit:Hit(Target, Attacker, Damage, {})
			Check(#F.Intro.Client.TsunamiParry.Calls == 1, "Duplicate hit cannot repeat the transition")
			F:Advance(0.84)
			Check(#F.Intro.Client.TsunamiStarted.Calls == 0, "Reaction stays visible for its configured duration")
			F:Advance(0.02)
			Check(
				#F.Intro.Client.TsunamiStarted.Calls == 1
					and not F.Character.PrimaryPart.Anchored
					and not F.Boss.PrimaryPart.Anchored,
				"Camera warning starts after the reaction while both actors remain unanchored"
			)
			F:Advance(2.98)
			Check(#F.Intro.Client.TsunamiRevealed.Calls == 0 and not F.Character.PrimaryPart.Anchored
				and not F.Boss.PrimaryPart.Anchored, "The warning lasts three seconds before the actors freeze")
			F:Advance(0.02)
			Check(#F.Intro.Client.TsunamiRevealed.Calls == 1 and F.Character.PrimaryPart.Anchored
				and F.Boss.PrimaryPart.Anchored, "Both actors freeze in place when the tsunami camera is revealed")
			F.Intro:StageTsunami(F.Player, "token")
			Check(#F.Intro.Client.TsunamiRevealed.Calls == 1, "Duplicate staging cannot repeat the reveal")
		end
	end

	for _, FirstPing in { 0, 0.16 } do
		local F = Fixture()
		F:EnableMeleeClashes()
		F.Boss:SetAttribute("Ping", FirstPing)
		F.Character:SetAttribute("Ping", if FirstPing == 0 then 0.14 else 0)
		local Results = {}
		local function Record(Result: string?)
			table.insert(Results, Result)
		end
		F.Hit:MeleeHit(F.Boss, F.Character, 10, { By = "Weapon", Action = "Attack" }, Record)
		F:Advance(0.049)
		Check(#Results == 0 and F.Boss:GetAttribute("Health") == 100, "The first contact waits for its reciprocal hit")
		F.Hit:MeleeHit(F.Character, F.Boss, 20, { By = "Weapon", Action = "StrongAttack" }, Record)
		Check(#Results == 2 and Results[1] == "HeavyParry" and Results[2] == "HeavyParry", "A reciprocal contact clashes before individual lag compensation")
		Check(F.Boss:GetAttribute("HeavyDeflect") and F.Character:GetAttribute("HeavyDeflect")
			and F.Boss:GetAttribute("Clashed") and F.Character:GetAttribute("Clashed"), "Both fighters receive the same heavy reaction")
		Check(#F.StoppedAttacks == 2 and #F.MeleeAnimations == 2 and #F.MeleeRenders == 2, "Both swings stop and both fighters play the heavy reaction")
		Check(F.MeleeRenders[1].PlaySound and not F.MeleeRenders[2].PlaySound, "A clash emits only one impact sound")
		local Recoils = {}
		for _, Created in F.Created do
			if Created.ClassName == "BodyVelocity" then
				Recoils[Created.Parent] = Created.Velocity.X
			end
		end
		Check(Recoils[F.Character.PrimaryPart] < 0 and Recoils[F.Boss.PrimaryPart] > 0, "The fighters recoil away from their opponent")
		F:Advance(0.2)
		Check(F.Character:GetAttribute("Health") == 100 and F.Boss:GetAttribute("Health") == 100
			and F.Effects.Damage == 0 and #F.Hit.HitResolved.Event.Calls == 2, "Neither clashed hit may apply damage when its old timer elapses")
	end

	for _, FirstPing in { 0, 0.16 } do
		local Outside = Fixture()
		Outside:EnableMeleeClashes()
		Outside.Boss:SetAttribute("Ping", FirstPing)
		Outside.Hit:MeleeHit(Outside.Boss, Outside.Character, 10, { By = "Weapon" })
		Outside:Advance(0.051)
		Check(Outside.Boss:GetAttribute("Health") == (if FirstPing == 0 then 90 else 100), "An uncontested hit respects the later of compensation and the clash window")
		Outside.Hit:MeleeHit(Outside.Character, Outside.Boss, 20, { By = "Weapon" })
		Outside:Advance(0.16)
		Check(Outside.Character:GetAttribute("Health") == 80 and Outside.Boss:GetAttribute("Health") == 90
			and #Outside.MeleeAnimations == 0, "A reverse contact outside the window cannot clash even if the first hit is pending")
	end

	local ThirdParty = Fixture()
	ThirdParty:EnableMeleeClashes()
	local Third = ThirdParty:AddFighter(5)
	ThirdParty.Hit:MeleeHit(ThirdParty.Boss, ThirdParty.Character, 10, { By = "Weapon" })
	ThirdParty:Advance(0.01)
	ThirdParty.Hit:MeleeHit(Third, ThirdParty.Boss, 10, { By = "Weapon" })
	ThirdParty.Hit:MeleeHit(ThirdParty.Boss, ThirdParty.Character, 10, { By = "Weapon" })
	ThirdParty:Advance(0.06)
	Check(Third:GetAttribute("Health") == 90 and ThirdParty.Boss:GetAttribute("Health") == 80
		and #ThirdParty.MeleeAnimations == 0, "Hits in the same direction and hits on third parties cannot match")

	for _, Defense in { "DeflectTime", "RollIFrame" } do
		local F = Fixture()
		F:EnableMeleeClashes()
		F.Boss:SetAttribute("Ping", 0.02)
		F.Hit:MeleeHit(F.Boss, F.Character, 10, { By = "Weapon" })
		F:Advance(0.01)
		F.Boss:SetAttribute(Defense, true)
		F:Advance(0.011)
		local Result = F.Hit.HitResolved.Event.Calls[1]
		Check(Result and Result[3] == (if Defense == "DeflectTime" then "Deflect" else "Dodge"), "Manual defenses resolve at the original compensated time")
		F.Boss:SetAttribute(Defense, false)
		F.Hit:MeleeHit(F.Character, F.Boss, 10, { By = "Weapon" })
		F:Advance(0.06)
		Check(#F.MeleeAnimations == 0, "A defended contact cannot later become a reciprocal clash")
	end

	local Allies = Fixture()
	Allies:EnableMeleeClashes(true)
	Allies.Hit:MeleeHit(Allies.Boss, Allies.Character, 10, { By = "Weapon" })
	Allies.Hit:MeleeHit(Allies.Character, Allies.Boss, 10, { By = "Weapon" })
	Allies:Advance(0.06)
	Check(#Allies.MeleeAnimations == 0, "Party allies cannot start a mutual Heavy Parry")

	local WakeUp = Fixture()
	WakeUp.Intro.KnitStart()
	WakeUp.Player:SetAttribute("InIntroStorm", true)
	WakeUp.Character:SetAttribute("Loaded", true)
	WakeUp.Character:SetAttribute("Health", 20)
	WakeUp.Character:SetAttribute("Stamina", 15)
	WakeUp.Character:SetAttribute("Posture", 70)
	WakeUp.Character:SetAttribute("WeaponEquipped", true)
	WakeUp.Character:SetAttribute("InCombat", true)
	WakeUp.Player:SetAttribute("InCombat", true)
	WakeUp.Intro:StartTsunami(WakeUp.Player, "test")
	WakeUp:Advance(3.85)
	WakeUp.Intro.Client.TsunamiFinished:Fire(WakeUp.Player, "token")
	Check(WakeUp.Session.Phase == "TsunamiReveal", "The client cannot skip the tsunami approach")
	WakeUp:Advance(10)
	WakeUp.Intro.Client.TsunamiFinished:Fire(WakeUp.Player, "wrong-token")
	Check(WakeUp.Session.Phase == "TsunamiReveal", "A stale token cannot start the blackout")
	WakeUp.Intro.Client.TsunamiFinished:Fire(WakeUp.Player, "token")
	Check(WakeUp.Session.Phase == "Blackout", "Tsunami impact starts the blackout")
	Check(WakeUp.Character:GetAttribute("Health") == 120 and WakeUp.Character:GetAttribute("Stamina") == 100
		and WakeUp.Character:GetAttribute("Posture") == 0, "The blackout restores health, stamina and posture")
	Check(not WakeUp.Character:GetAttribute("InCombat") and not WakeUp.Player:GetAttribute("InCombat"),
		"The blackout clears the player's combat state")
	Check(WakeUp.Character:GetAttribute("WeaponEquipped") == false, "The sword is sheathed before waking up")
	Check(WakeUp.Character:GetAttribute("IntroWakeUp") and WakeUp.Character:GetAttribute("ForceField")
		and WakeUp.Character.PrimaryPart.Anchored and WakeUp.Player:GetAttribute("CantAttack"),
		"The player remains protected, anchored and unable to attack throughout the blackout")
	WakeUp.Damage:DealDamage(WakeUp.Character, 10000, WakeUp.Boss)
	Check(WakeUp.Character:GetAttribute("Health") == 120, "Damage cannot hurt the player during wake-up")
	Check(WakeUp.Player:GetAttribute("InIntroStorm") == false,
		"The intro storm ends behind the black screen before the beach is revealed")
	WakeUp:Advance(4.99)
	Check(WakeUp.Effects.Teleports == 0, "The player stays behind the black screen for five seconds")
	WakeUp:Advance(0.02)
	Check(WakeUp.Effects.Teleports == 1 and WakeUp.Character.Pivot == 100, "The server moves the player to BeachSpawn")
	Check(WakeUp.Character.PrimaryPart.Anchored and WakeUp.Character:GetAttribute("SkillLockMovement"),
		"Movement stays locked during the wake-up")
	Check(#WakeUp.Intro.Client.WakeUpStarted.Calls == 1 and WakeUp.Session.Boss == nil,
		"Wake-up starts once and removes the ship's boss")
	Check(not WakeUp.PlayerData.IntroCutsceneCompleted and WakeUp.Effects.Checkpoints == 0,
		"Reaching the beach alone does not complete the intro")
	WakeUp.Intro.Client.WakeUpFinished:Fire(WakeUp.Player, "wrong-token")
	Check(WakeUp.Session.Phase == "WakingUp", "A stale token cannot finish waking up")
	WakeUp.Intro.Client.WakeUpFinished:Fire(WakeUp.Player, "token")
	WakeUp:Advance(8.23)
	Check(not WakeUp.PlayerData.IntroCutsceneCompleted, "Completion waits for the fade, animation and camera transition")
	WakeUp:Advance(0.02)
	Check(WakeUp.PlayerData.IntroCutsceneCompleted and WakeUp.Effects.Checkpoints == 1,
		"Finishing saves the intro checkpoint once")
	Check(not WakeUp.Character.PrimaryPart.Anchored and not WakeUp.Player:GetAttribute("InIntroCutscene"),
		"Gameplay controls return after the camera transition")
	Check(not WakeUp.Character:GetAttribute("IntroWakeUp") and not WakeUp.Character:GetAttribute("ForceField"),
		"Wake-up protection is released when the cutscene completes")
	Check(not WakeUp.Intro:ShouldPlay(WakeUp.Player), "Completed profiles skip the initial cutscene")
	Check(WakeUp.Intro:Replay(WakeUp.Player) and WakeUp.Effects.Loads == 1,
		"The test command can start a fresh intro character")
	Check(WakeUp.Intro:ShouldPlay(WakeUp.Player) and WakeUp.PlayerData.IntroCutsceneCompleted,
		"Testing forces the intro without clearing saved completion")
	WakeUp.Intro:Cleanup(WakeUp.Player)
	Check(not WakeUp.Intro:ShouldPlay(WakeUp.Player), "Replay overrides are cleared with the session")

	local Ordinary = Fixture()
	Check(Ordinary.Hit:NormalHit(Ordinary.Character, Ordinary.Boss, 10, {}) == "Hit", "Ordinary hit is preserved")
	Check(
		Ordinary.Character:GetAttribute("Health") == 90 and Ordinary.Effects.Damage == 1,
		"Ordinary damage is recorded"
	)
	Check(
		Ordinary.Effects.Blood == 1 and #Ordinary.Intro.Client.TsunamiParry.Calls == 0,
		"Ordinary combat keeps its effects"
	)

	local Direct = Fixture()
	Direct.Damage:DealDamage(Direct.Boss, 300, Direct.Character)
	Check(
		Direct.Boss:GetAttribute("Health") == 700 and #Direct.Intro.Client.TsunamiParry.Calls == 1,
		"Direct damage is intercepted too"
	)
	local Burn = Fixture()
	Burn.Character:SetAttribute("BurnDamage", 2)
	Burn.Damage:DealDamage(Burn.Character, 60)
	Check(
		Burn.Character:GetAttribute("BurnDamage") == 0 and Burn.Character:GetAttribute("Health") == 100,
		"Burn trigger is cleared without a final damage tick"
	)

	local Stale = Fixture()
	Stale.Intro:TryInterceptHit(Stale.Boss, 300, Stale.Character)
	Stale.Intro.TestSessions[Stale.Player] = nil
	Stale:Advance(1)
	Check(#Stale.Intro.Client.TsunamiStarted.Calls == 0, "Removed session cannot start a stale cutscene")
	local StaleWarning = Fixture()
	StaleWarning.Intro:TryInterceptHit(StaleWarning.Boss, 300, StaleWarning.Character)
	StaleWarning:Advance(1)
	StaleWarning.Intro.TestSessions[StaleWarning.Player] = nil
	StaleWarning:Advance(3)
	Check(#StaleWarning.Intro.Client.TsunamiRevealed.Calls == 0, "Removed session cannot reveal after the warning delay")

	local Invalid = Fixture()
	for _, Amount in { -1, 0, math.huge, 0 / 0 } do
		Check(
			not Invalid.Intro:TryInterceptHit(Invalid.Character, Amount, Invalid.Boss),
			"Invalid damage does not start a transition"
		)
	end
	Check(
		not Invalid.Intro:TryInterceptHit(Invalid.Character, 100, Object()),
		"Unrelated attacker cannot trigger another player's intro"
	)

	local Visual = Fixture()
	local Client = Visual:LoadClient()
	Client:PlayHeavyParry("token", Visual.Character, Visual.Boss)
	Check(#Visual.ClientAnimations == 2, "Client plays two heavy-parry reactions")
	Check(
		Visual.ClientAnimations[1].Actor == Visual.Character and Visual.ClientAnimations[2].Actor == Visual.Boss,
		"Each actor gets their own reaction track"
	)
	for _, Track in Visual.ClientAnimations do
		Check(
			Track.Priority.Value == 5 and Track.Name == "IntroHeavyParry" and not Track.Looped,
			"Reaction overrides combat animation without looping"
		)
	end
	Check(#Visual.ClientRenders == 3, "Both heavy effects share one parry clash")
	Client:PlayHeavyParry("token", Visual.Character, Visual.Boss)
	Check(#Visual.ClientAnimations == 2, "Duplicate signal does not restart reactions")
	Client:Begin("token", Visual.Character, Visual.Boss)
	Check(Visual.Blackout == false, "The tsunami transition keeps the scene visible without a fade")
	local FrameType = {}
	FrameType.__mul = function(): any
		return setmetatable({ Shaken = true }, FrameType)
	end
	local Frame = setmetatable({}, FrameType)
	local Shaken = Visual.CameraTransform(Frame, 1 / 60)
	Check(Shaken ~= Frame, "Camera shakes during the warning before the wave is created")
	Visual.Player:SetAttribute("CameraShake", false)
	Check(Visual.CameraTransform(Frame, 1 / 60) == Frame, "Warning shake respects the player's camera shake setting")
	for _, Track in Visual.ClientAnimations do
		Check(Track.Stopped and Track.Destroyed, "Reaction tracks are cleaned before the tsunami camera starts")
	end
	return string.format("HeavyParry: %d checks passed", Checks)
end
