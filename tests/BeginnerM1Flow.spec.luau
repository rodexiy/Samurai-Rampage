return function(Sources: { [string]: string }): string
	local function Signal(): any
		local Listeners = {}
		local Event = {}

		function Event:Connect(Callback: (...any) -> ())
			local Connection = { Connected = true, Callback = Callback }
			function Connection.Disconnect()
				Connection.Connected = false
			end
			table.insert(Listeners, Connection)
			return Connection
		end

		function Event:Once(Callback: (...any) -> ())
			local Connection
			Connection = self:Connect(function(...)
				Connection:Disconnect()
				Callback(...)
			end)
			return Connection
		end

		function Event:Fire(...: any)
			for _, Connection in table.clone(Listeners) do
				if Connection.Connected then
					Connection.Callback(...)
				end
			end
		end

		return Event
	end

	local function Fixture(InitialCombo: number?, InIntro: boolean?): any
		local Now = 0
		local Timers = {}
		local function Delay(Seconds: number, Callback: () -> ())
			table.insert(Timers, { At = Now + Seconds, Callback = Callback })
		end

		local function Advance(To: number)
			while true do
				local Index, NextTimer
				for CandidateIndex, Candidate in Timers do
					if Candidate.At <= To and (not NextTimer or Candidate.At < NextTimer.At) then
						Index, NextTimer = CandidateIndex, Candidate
					end
				end
				if not NextTimer then
					break
				end
				table.remove(Timers, Index)
				Now = NextTimer.At
				NextTimer.Callback()
			end
			Now = To
		end

		local function Noop() end
		local function Clock(): number
			return Now
		end

		local Attributes = {
			ComboCounter = InitialCombo or 0,
			DefaultWalkSpeed = 12,
			Stamina = 100,
			SwordStaminaCost = 5,
			Stance = "Beginner",
			Weapon = "Katana",
			WeaponEquipped = true,
		}
		local Humanoid = { WalkSpeed = 12, MoveDirection = { Magnitude = 1 } }
		local AttributeSignals = {}
		local Character = { AttributeChanged = Signal() }
		function Character:GetAttribute(Name: string): any
			return Attributes[Name]
		end
		function Character:GetAttributeChangedSignal(Name: string): any
			if not AttributeSignals[Name] then
				AttributeSignals[Name] = Signal()
			end
			return AttributeSignals[Name]
		end
		function Character:SetAttribute(Name: string, Value: any)
			if Attributes[Name] ~= Value then
				Attributes[Name] = Value
				self:GetAttributeChangedSignal(Name):Fire()
				self.AttributeChanged:Fire(Name)
			end
		end
		function Character:FindFirstChildWhichIsA(ClassName: string): any
			return if ClassName == "Humanoid" then Humanoid else nil
		end
		function Character:IsDescendantOf(): boolean
			return true
		end
		function Character:WaitForChild(Name: string): any
			return self:FindFirstChildWhichIsA(Name)
		end

		local Player = { GetAttribute = function(_: any, Name: string): boolean?
			return if Name == "InIntroCutscene" then InIntro else nil
		end }
		local Players = { GetPlayerFromCharacter = function(): any
			return Player
		end }
		local RenderStep = Signal()
		local Stance = assert(loadstring(Sources.Beginner))()
		local Played = {}
		local Track
		local Services = {}
		local Knit = {
			CreateService = function(Service: any): any
				return Service
			end,
			GetService = function(Name: string): any
				return Services[Name] or {}
			end,
		}
		local Modules = {
			Knit = Knit,
			Stances = { Beginner = Stance },
			KickConfig = {},
			EgoConfig = { BlockedActions = {} },
			BowConfig = { DrawWalkSpeed = 6 },
			CrouchConfig = { WalkSpeed = 6 },
			SkillTreeConfig = { Effects = {} },
		}
		local Storage = {
			Assets = { Weapons = {}, Animations = {} },
			Packages = { Knit = "Knit" },
			Shared = setmetatable({ Index = { Stances = "Stances" }, Utils = {} }, {
				__index = function(_: any, Name: string): string
					return Name
				end,
			}),
		}
		local MockCFrame = setmetatable({}, { __mul = Noop })
		local function MakeCFrame(): any
			return MockCFrame
		end
		local function Load(Name: string): any
			local Chunk = assert(loadstring(Sources[Name], Name))
			setfenv(Chunk, setmetatable({
				game = {
					ReplicatedStorage = Storage,
					Players = Players,
					GetService = function(_: any, Service: string): any
						return ({ ReplicatedStorage = Storage, Players = Players, RunService = { RenderStepped = RenderStep } })[Service]
					end,
				},
				require = function(Module: string): any
					return Modules[Module]
				end,
				script = { Parent = { Parent = Character }, GetDescendants = function(): { any }
					return {}
				end },
				task = { delay = Delay },
				CFrame = { new = MakeCFrame, Angles = MakeCFrame },
				workspace = {},
				tick = Clock,
				os = { clock = Clock },
			}, { __index = getfenv() }))
			return Chunk()
		end

		local Animation = { GetAttribute = Noop }
		local function Stop()
			if Track and Track.IsPlaying then
				Track.IsPlaying = false
				Track.Stopped:Fire()
			end
		end

		Services.AnimationService = {
			StopAttackAnimations = Stop,
			StopAnimationFind = Noop,
			GetAnimationFind = function(): any
				return Track.IsPlaying and Track or nil
			end,
		}
		local Debounce = Load("Debounce")
		Services.DebounceService = Debounce
		Modules.Validate = Load("Validate")
		Modules.CharacterShared = Load("Movement")
		local WeaponService = Load("WeaponService")
		WeaponService.KnitInit()
		WeaponService.GetStanceAnimationFolder = function(): any
			return { M1 = { GetChildren = function(): any
				return Stance.M1
			end } }
		end
		WeaponService.PlayM1Animation = function(): (any, any)
			table.insert(Played, Attributes.ComboCounter)
			local ActiveTrack = { IsPlaying = true, Length = 1, Stopped = Signal(), AdjustSpeed = Noop }
			Track = ActiveTrack
			Delay(1, function()
				if Track == ActiveTrack then
					Stop()
				end
			end)
			return Track, Animation
		end
		WeaponService.DidCancel = function(): boolean
			return Attributes.BeenHitted == true or Attributes.Rolling == true
		end
		WeaponService.ShowSlash = Noop
		WeaponService.SwordTrailsEnabled = Noop
		Services.WeaponService = WeaponService
		Services.SoundEffectService = { CustomSwordWoosh = Noop, AddPitchEffect = Noop }
		Services.StaminaService = { RemoveStamina = function(_: any, _: any, Amount: number)
			Character:SetAttribute("Stamina", Attributes.Stamina - Amount)
		end }
		Services.ValuesService = { GetWeaponStaminaCost = function(): number
			return 5
		end }
		Services.TalentService = {
			GetAttackSpeed = function(): number
				return 1
			end,
			BeginAttack = Noop,
			ActivateAttack = function(): boolean
				return true
			end,
		}
		Services.ClothService = { StartSwing = Noop }
		Services.HitboxService = { CharacterRaycastHitbox = Noop }

		local Weapons = Load("Weapons")
		Load("Acceleration")
		for _, Name in { "Attack", "Attacking", "M1WalkSpeedMultiplier", "BeenHitted", "StrongAttack" } do
			Character:GetAttributeChangedSignal(Name):Connect(function()
				Modules.CharacterShared:UpdateWalkspeed(Character)
			end)
		end

		return {
			Attributes = Attributes,
			Character = Character,
			Debounce = Debounce,
			Played = Played,
			Advance = Advance,
			Press = function()
				Weapons.Attack(Character, { Server = {} })
			end,
			Step = function(): number
				RenderStep:Fire(1 / 60)
				return Humanoid.WalkSpeed
			end,
		}
	end

	local Movement = Fixture()
	Movement.Press()
	assert(math.abs(Movement.Attributes.TargetWalkSpeed - 9.6) < 0.001, "Windup should preserve most movement")
	assert(Movement.Step() == 11, "The windup should ease from the current speed")
	Movement.Advance(0.38)
	assert(Movement.Attributes.TargetWalkSpeed == 6 and Movement.Step() == 10, "The blade swing should ease towards its reduced speed")
	Movement.Advance(0.5)
	assert(Movement.Attributes.TargetWalkSpeed == 12 and Movement.Step() > 10, "Recovery should return movement progressively")
	Movement.Character:SetAttribute("BeenHitted", true)
	assert(Movement.Step() == 4, "Hitstun should take priority immediately")

	local Early = Fixture()
	Early.Press()
	Early.Advance(0.74)
	Early.Press()
	Early.Advance(0.91)
	assert(#Early.Played == 1, "Input outside the buffer should expire")

	local Combo = Fixture()
	Combo.Press()
	Combo.Advance(0.78)
	Combo.Press()
	Combo.Press()
	assert(#Combo.Played == 1 and Combo.Attributes.Stamina == 95, "The buffered input must wait to consume stamina")
	Combo.Advance(0.91)
	assert(#Combo.Played == 2 and Combo.Played[2] == 2 and Combo.Attributes.Stamina == 90, "Consume exactly one buffered attack")
	Combo.Advance(1.16)
	assert(Combo.Attributes.M1WalkSpeedMultiplier == 0.8, "The previous swing must not clear the new movement phase")
	Combo.Advance(1.81)
	assert(#Combo.Played == 2, "A repeated input inside one buffer window must not queue a third attack")

	for _, Interruption in { "Rolling", "WeaponEquipped" } do
		local Interrupted = Fixture()
		Interrupted.Press()
		Interrupted.Advance(0.78)
		Interrupted.Press()
		local Before = Interrupted.Attributes[Interruption]
		Interrupted.Character:SetAttribute(Interruption, not Before)
		Interrupted.Character:SetAttribute(Interruption, Before)
		Interrupted.Advance(0.91)
		assert(#Interrupted.Played == 1, "A brief interruption must discard the queued attack")
	end

	local Finisher = Fixture(4)
	Finisher.Press()
	Finisher.Advance(0.8)
	Finisher.Press()
	Finisher.Advance(1.84)
	assert(#Finisher.Played == 1 and Finisher.Played[1] == 5 and Finisher.Attributes.AttackDebounce, "The finisher owns its recovery as soon as it starts")
	Finisher.Advance(1.86)
	Finisher.Press()
	assert(#Finisher.Played == 2 and Finisher.Played[2] == 1, "The first valid press after recovery starts a fresh combo")

	local Intro = Fixture(nil, true)
	Intro.Press()
	assert(Intro.Attributes.M1WalkSpeedMultiplier == nil and Intro.Attributes.TargetWalkSpeed == 6, "The intro should retain its attack movement")
	Intro.Advance(0.78)
	Intro.Press()
	Intro.Advance(0.91)
	assert(#Intro.Played == 1, "The intro should retain its existing input timing")

	local Renewed = Fixture()
	Renewed.Debounce:AddDebounce(Renewed.Character, "AttackDebounce", 0.5)
	Renewed.Debounce:RemoveDebounce(Renewed.Character, "AttackDebounce")
	Renewed.Debounce:AddDebounce(Renewed.Character, "AttackDebounce", 1)
	Renewed.Advance(0.51)
	assert(Renewed.Attributes.AttackDebounce, "A manually removed timer must not expire its replacement")
	Renewed.Advance(1.01)
	assert(not Renewed.Attributes.AttackDebounce, "The replacement expires on its own deadline")

	return "Beginner M1: movement, buffering, interruptions, finisher, intro and replacement debounces passed"
end
