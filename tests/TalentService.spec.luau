return function(Sources: { [string]: string }): string
	local Checks, Now, Consumed = 0, 100, 0
	local Jobs = {}
	local Services = {}
	local Player = {}
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local function Signal(): any
		local Listeners = {}
		return {
			Once = function(Self: any, Callback: any): any
				local Connection
				Connection = Self:Connect(function(...: any)
					Connection:Disconnect()
					Callback(...)
				end)
				return Connection
			end,
			Connect = function(_Self: any, Callback: any): any
				local Connection = { Callback = Callback, Connected = true }
				function Connection:Disconnect()
					self.Connected = false
				end
				table.insert(Listeners, Connection)
				return Connection
			end,
			Fire = function(_Self: any, ...: any)
				for _, Listener in table.clone(Listeners) do
					if Listener.Connected then
						Listener.Callback(...)
					end
				end
			end,
		}
	end
	local function Character(): any
		local Attributes = { Health = 50, MaxHealth = 100, Stamina = 100, WeaponEquipped = true, ComboCounter = 0 }
		local Signals = {}
		local Result = { Parent = true, Talents = {}, Destroying = Signal() }
		function Result:GetAttribute(Name: string): any
			return Attributes[Name]
		end
		function Result:AddTag(Name: string)
			Attributes["Tag" .. Name] = true
		end
		function Result:RemoveTag(Name: string)
			Attributes["Tag" .. Name] = nil
		end
		function Result:GetAttributeChangedSignal(Name: string): any
			Signals[Name] = Signals[Name] or Signal()
			return Signals[Name]
		end
		function Result:SetAttribute(Name: string, Value: any)
			local Before = Attributes[Name]
			Attributes[Name] = Value
			if Before ~= Value and Signals[Name] then
				Signals[Name]:Fire()
			end
		end
		return Result
	end
	local function Advance(Seconds: number)
		Now += Seconds
		local Pending = Jobs
		Jobs = {}
		for _, Job in Pending do
			if Job.At <= Now then
				Job.Run()
			else
				table.insert(Jobs, Job)
			end
		end
	end
	local Knit = {
		CreateService = function(Service: any): any
			Services[Service.Name] = Service
			return Service
		end,
		GetService = function(Name: string): any return assert(Services[Name], Name) end,
	}
	local ReplicatedStorage = { Packages = { Knit = Knit }, Shared = {} }
	local Players = { GetPlayerFromCharacter = function(_Self: any, Model: any): any
		return if Model == Player.Character then Player else nil
	end }
	local Environment = setmetatable({
		game = { GetService = function(_Self: any, Name: string): any
			return if Name == "Players" then Players else ReplicatedStorage
		end },
		require = function(Module: any): any return assert(Module, "Missing module") end,
		Color3 = { fromRGB = function(...: any): any return { ... } end },
		workspace = { GetServerTimeNow = function(): number return Now end },
		os = { clock = function(): number return Now end },
		Instance = { new = function(): any return Signal() end },
		task = { delay = function(Seconds: number, Callback: () -> ())
			table.insert(Jobs, { At = Now + Seconds, Run = Callback })
		end },
	}, { __index = getfenv() })
	local function Load(Source: string): any
		local Chunk = assert(loadstring(Source))
		setfenv(Chunk, Environment)
		return Chunk()
	end
	local Config = Load(Sources.Config)
	ReplicatedStorage.Shared.SkillTreeConfig = Config
	Services.SkillTreeService = { IsSkillUnlocked = function(_Self: any, Model: any, Name: string): boolean
		return Model.Talents[Name] == true
	end }
	Services.StaminaService = {
		RemoveStamina = function(_Self: any, Model: any, Cost: number) Model:SetAttribute("Stamina", Model:GetAttribute("Stamina") - Cost) end,
		AddStamina = function(_Self: any, Model: any, Amount: number) Model:SetAttribute("Stamina", Model:GetAttribute("Stamina") + Amount) end,
	}
	Services.DebounceService = {
		AddDebounce = function(_Self: any, Model: any, Name: string, Seconds: number)
			Model:SetAttribute(Name, true)
			table.insert(Jobs, { At = Now + Seconds, Run = function()
				Model:SetAttribute(Name, false)
			end })
		end,
		RemoveDebounce = function(_Self: any, Model: any, Name: string) Model:SetAttribute(Name, false) end,
	}
	Services.AnimationService = { StopAttackAnimations = function() end }
	Services.InventoryService = {
		GetPlayerItemByName = function(): any return { Stack = 10 - Consumed } end,
		ConsumeToolItem = function() Consumed += 1 end,
	}
	Services.AlertService = { AlertPlayer = function() end }
	Services.RenderService = { RenderForAllPlayers = function() end }
	Services.QuestService = { CallQuestFunction = function() end }
	Services.KillStreakService = { HandlePlayerKill = function() end }
	Services.HitboxService = {}
	local Talents = Load(Sources.Talents)
	Talents.KnitInit()
	local Bandage = Load(Sources.Bandage)
	local Execution = Load(Sources.Execution)
	Execution.KnitInit()
	local Buffs = Load(Sources.Buffs)
	Buffs.KnitInit()

	local Actor = Character()
	Player.Character = Actor
	local Attack = Talents:BeginAttack(Actor, false, 0.5, 1)
	Check(not Talents:TryFeint(Actor), "Feints require the purchased talent")
	Actor.Talents.Feint = true
	Actor:SetAttribute("BeenHitted", true)
	Check(not Talents:TryFeint(Actor), "Feints cannot escape hit stun")
	Actor:SetAttribute("BeenHitted", false)
	Check(Talents:TryFeint(Actor) and Actor:GetAttribute("Stamina") == 95, "Valid feints spend stamina once")
	Check(not Talents:ActivateAttack(Actor, Attack), "A feinted attack cannot later activate its hitbox")
	Check(not Talents:TryFeint(Actor), "Repeated requests cannot spend or cancel twice")
	Advance(4)
	Attack = Talents:BeginAttack(Actor, false, 0.5, 1)
	Check(Talents:ActivateAttack(Actor, Attack) and not Talents:TryFeint(Actor), "Active hitboxes cannot be feinted")
	Attack = Talents:BeginAttack(Actor, true, 0.5, 1)
	Check(not Talents:TryFeint(Actor), "Heavy attacks cannot be feinted")
	Talents:ActivateAttack(Actor, Attack)
	Check(Talents:AcceptTarget(Actor, Attack, Character()), "A heavy attack accepts its first target")
	Check(not Talents:AcceptTarget(Actor, Attack, Character()), "Heavy attacks require Make Room to hit more targets")
	Actor.Talents["Make Room"] = true
	Check(Talents:AcceptTarget(Actor, Attack, Character()) and Talents:AcceptTarget(Actor, Attack, Character()), "Make Room admits three targets")
	Check(not Talents:AcceptTarget(Actor, Attack, Character()), "Make Room has a target cap")
	Actor.Talents["Firm Response"] = true
	Talents:OnParry(Actor)
	Attack = Talents:BeginAttack(Actor, false, 0.2, 1)
	Check(Talents:GetPostureBonus(Attack) == Config.Effects.ResponsePosture and Talents:GetPostureBonus(Attack) == 0, "Parry responses are consumed once")
	Actor.Talents["Mobile Response"] = true
	Talents:OnParry(Actor)
	Check(Talents:GetRollCost(Actor) == 3 and Talents:GetRollCost(Actor) == 5, "Mobile response discounts one roll")
	Talents:OnParry(Actor)
	Advance(2)
	Check(Talents:GetRollCost(Actor) == 5, "Expired responses grant no discount")
	Actor.Talents["Rise Again"] = true
	Check(Talents:GetPostureBreakDuration(Actor) == 1.5 and Talents:GetPostureBreakDuration(Actor) == 2, "Posture recovery has a cooldown")
	Actor.Talents["Economical Guard"] = true
	Actor:SetAttribute("Stamina", 20)
	for _ = 1, 6 do
		Talents:OnBlock(Actor)
	end
	Check(Actor:GetAttribute("Stamina") == 28, "Block sequences cannot restore unlimited stamina")

	Actor = Character()
	Player.Character = Actor
	Bandage.Activated(Actor, {})
	Check(Consumed == 1 and Actor:GetAttribute("Health") == 50 and Actor:GetAttribute("Bandaging"), "Bandages consume once and heal after application")
	Bandage.Activated(Actor, {})
	Check(Consumed == 1, "Repeated bandage requests do not consume twice")
	Advance(2)
	Check(Actor:GetAttribute("Health") == 65 and not Actor:GetAttribute("Bandaging"), "Completed bandages heal the base amount")
	Advance(10)
	Actor.Talents["Efficient Dressing"] = true
	Actor.Talents["Preserved Dressing"] = true
	Bandage.Activated(Actor, {})
	Advance(1.1)
	Actor:SetAttribute("Health", 55)
	Check(Actor:GetAttribute("Health") == 55, "Interrupted bandages give no healing, even with retired item talent flags")
	local After = Actor:GetAttribute("Health")
	Advance(12)
	Check(Actor:GetAttribute("Health") == After, "Interrupted applications never heal twice")
	Bandage.Activated(Actor, {})
	Actor:SetAttribute("Health", After - 5)
	Advance(2)
	Check(Actor:GetAttribute("Health") == After - 5, "Early interruption preserves no healing")
	Advance(10)
	Actor:SetAttribute("Health", 20)
	Actor.Talents["Last Breath"] = true
	Bandage.Activated(Actor, {})
	Advance(0.75)
	Check(Actor:GetAttribute("Health") == 20, "Retired talents cannot accelerate bandages")
	Advance(1.25)
	Check(Actor:GetAttribute("Health") == 35, "Bandages keep fixed healing regardless of talents")

	local Survivor = Character()
	local Enemy = Character()
	Survivor.Talents["Second Wind"] = true
	Survivor.Talents["Recovery Reserve"] = true
	Survivor:SetAttribute("Health", 20)
	Talents:RecordDamage(Survivor, Enemy, 80)
	Advance(3)
	Check(Survivor:GetAttribute("Health") == 20, "Combat recovery requires a period without damage")
	Advance(1)
	Check(Survivor:GetAttribute("Health") == 30, "Second Wind recovers ten percent after four seconds")
	Advance(1)
	Check(Survivor:GetAttribute("Health") == 35, "Combined recovery is capped at fifteen percent per hit")
	Survivor:SetAttribute("Health", 20)
	Talents:RecordDamage(Survivor, Enemy, 15)
	Advance(5)
	Check(Survivor:GetAttribute("Health") == 23, "Second Wind respects cooldown while Reserve scales with actual damage")
	Advance(60)
	Survivor:SetAttribute("Health", 20)
	Talents:RecordDamage(Survivor, Enemy, 40)
	Advance(3)
	Survivor:SetAttribute("Health", 15)
	Talents:RecordDamage(Survivor, Enemy, 5)
	Advance(2)
	Check(Survivor:GetAttribute("Health") == 15, "Further damage cancels the earlier recovery timers")
	Advance(2)
	Check(Survivor:GetAttribute("Health") == 25, "An interrupted Second Wind does not consume its cooldown")
	Advance(1)
	Check(Survivor:GetAttribute("Health") == 26, "Reserve restores only a fraction of the latest hit")
	Survivor:SetAttribute("Health", 20)
	Talents:RecordDamage(Survivor, Enemy, 30)
	Talents:RecordDamage(Survivor, nil, 1)
	Advance(6)
	Check(Survivor:GetAttribute("Health") == 20, "Environmental damage cancels recovery without starting another one")
	Talents:RecordDamage(Survivor, Survivor, 20)
	Advance(6)
	Check(Survivor:GetAttribute("Health") == 20, "Self damage cannot generate recovery")
	Talents:RecordDamage(Survivor, Enemy, 20)
	Survivor:SetAttribute("Downed", true)
	Advance(6)
	Check(Survivor:GetAttribute("Health") == 20, "Recovery cannot lift a downed character")
	Survivor:SetAttribute("Downed", false)
	Talents:RecordDamage(Survivor, Enemy, 20)
	Survivor.Talents = {}
	Advance(6)
	Check(Survivor:GetAttribute("Health") == 20, "Resetting the tree cancels pending talent healing")
	Survivor.Talents["Recovery Reserve"] = true
	Survivor:SetAttribute("Health", 98)
	Talents:RecordDamage(Survivor, Enemy, 50)
	Advance(5)
	Check(Survivor:GetAttribute("Health") == 100, "Recovery never exceeds maximum health")
	Survivor:SetAttribute("Health", 0)
	Talents:RecordDamage(Survivor, Enemy, 100)
	Advance(6)
	Check(Survivor:GetAttribute("Health") == 0, "Lethal damage cannot trigger recovery")

	Actor:SetAttribute("Health", 50)
	Actor.Talents["Health Recovery"] = true
	local Victim = Character()
	Victim:SetAttribute("Downed", true)
	Check(Execution:Execute(Actor, Victim), "Valid enemies can be executed")
	Check(Actor:GetAttribute("Health") == 65, "Execution healing checks the attacker talent")
	Check(not Execution:Execute(Actor, Victim) and Actor:GetAttribute("Health") == 65, "One victim cannot heal twice")
	Victim = Character()
	Victim:SetAttribute("Downed", true)
	Victim:SetAttribute("NoRewards", true)
	Execution:Execute(Actor, Victim)
	Check(Actor:GetAttribute("Health") == 65, "Rewardless targets cannot be farmed for healing")
	Actor:SetAttribute("Health", 20)
	Actor.Talents["Oni Health Recovery"] = true
	Victim = Character()
	Victim:SetAttribute("Downed", true)
	Execution:Execute(Actor, Victim)
	Check(Actor:GetAttribute("Health") == 75, "Oni healing takes precedence and does not stack")
	local Protected = Character()
	Protected.Talents["Burn Resistance"] = true
	local Unprotected = Character()
	Buffs:AddBuff(Protected, "Burn", "Burn", 2, 5, "int")
	Buffs:AddBuff(Unprotected, "Burn", "Burn", 2, 5, "int")
	Check(Protected:GetAttribute("BurnDamage") == 2, "Burn Resistance does not grant immunity")
	Advance(3)
	Check(Protected:GetAttribute("BurnDamage") == 0 and Unprotected:GetAttribute("BurnDamage") == 2,
		"Burn Resistance shortens duration without affecting another character")
	Advance(2)
	Check(Unprotected:GetAttribute("BurnDamage") == 0, "Ordinary burns expire at their original duration")
	return tostring(Checks) .. " talent checks passed"
end
