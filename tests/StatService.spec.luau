-- Executes production modules; only Roblox services and instances are replaced.
return function(Sources: { [string]: string }): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Copy(Value: any): any
		if type(Value) ~= "table" then return Value end
		local Result = {}
		for Key, Child in Value do
			Result[Key] = Copy(Child)
		end
		return Result
	end
	local function Signal(): any
		local Listeners = {}
		return {
			Connect = function(_Self: any, Callback: any): any
				table.insert(Listeners, Callback)
				return { Disconnect = function() end }
			end,
			Fire = function(_Self: any, ...: any)
				for _, Callback in Listeners do
					Callback(...)
				end
			end,
		}
	end
	local Methods = {}
	function Methods:IsA(Class: string): boolean
		return self.ClassName == Class or Class == "Instance" or (self.ClassName == "Part" and Class == "BasePart")
	end
	function Methods:FindFirstChild(Name: any): any
		for _, Child in self._children do
			if tostring(Child.Name) == tostring(Name) then return Child end
		end
		return nil
	end
	function Methods:FindFirstChildWhichIsA(Class: string): any
		for _, Child in self._children do
			if Child:IsA(Class) then
				return Child
			end
		end
		return nil
	end
	function Methods:GetChildren(): { any }
		return table.clone(self._children)
	end
	function Methods:GetAttributes(): { [string]: any }
		return table.clone(self._attributes)
	end
	function Methods:GetAttribute(Name: string): any
		return self._attributes[Name]
	end
	function Methods:SetAttribute(Name: string, Value: any)
		self._attributes[Name] = Value
	end
	function Methods:ClearAllChildren()
		for _, Child in table.clone(self._children) do
			Child:Destroy()
		end
	end
	function Methods:Destroy()
		self:ClearAllChildren()
		self.Parent = nil
	end
	local function InstanceNew(Class: string): any
		return setmetatable({ ClassName = Class, Name = Class, Value = 0, _children = {}, _attributes = {} }, {
			__index = function(Self: any, Key: string): any
				if Key == "Parent" then return rawget(Self, "_parent") end
				return Methods[Key] or Methods.FindFirstChild(Self, Key)
			end,
			__newindex = function(Self: any, Key: string, Value: any)
				if Key ~= "Parent" then
					rawset(Self, Key, Value)
					return
				end
				local Old = rawget(Self, "_parent")
				if Old then
					table.remove(Old._children, table.find(Old._children, Self))
				end
				rawset(Self, "_parent", Value)
				if Value then
					table.insert(Value._children, Self)
				end
			end,
		})
	end
	local Vector = {}
	local function VectorNew(X: number, Y: number, Z: number): any
		return setmetatable({ X = X, Y = Y, Z = Z }, Vector)
	end
	Vector.__sub = function(A: any, B: any): any
		return VectorNew(A.X - B.X, A.Y - B.Y, A.Z - B.Z)
	end
	Vector.__index = function(Self: any, Key: string): any
		if Key == "Magnitude" then return math.sqrt(Self.X ^ 2 + Self.Y ^ 2 + Self.Z ^ 2) end
		return nil
	end

	local Profiles = {}
	local Owners = {}
	local Services = {}
	local Workspace = InstanceNew("Workspace")
	local Rugs = InstanceNew("Folder")
	Rugs.Name = "Rugs"
	Rugs.Parent = Workspace
	local Rug = InstanceNew("Model")
	Rug.Parent = Rugs
	local RugPart = InstanceNew("Part")
	RugPart.Name = "Rug"
	RugPart.Position = VectorNew(0, 0, 0)
	RugPart.Parent = Rug
	local Players = {
		GetPlayerFromCharacter = function(_Self: any, Character: any): any return Owners[Character] end,
		PlayerRemoving = Signal(),
	}
	local ReplicatedStorage = {
		Packages = { Knit = "Knit" },
		Shared = { StatProgression = "Config", CharacterShared = "CharacterShared", Index = { SkillTrees = "Trees" },
			SkillTreeConfig = "TreeConfig", SkillTreeProgression = "TreeProgression",
			InventoryConfig = "InventoryConfig", HorseConfig = "HorseConfig" },
		Assets = { Public = { MousePositionUpdater = {} } },
	}
	local Knit = {
		CreateSignal = Signal,
		CreateService = function(Service: any): any
			Services[Service.Name] = Service
			return Service
		end,
		GetService = function(Name: string): any
			assert(Services[Name], Name)
			return Services[Name]
		end,
	}
	Services.DataService = { GetData = function(_Self: any, Player: any): any
		return Profiles[Player]
	end }
	Services.RenderService = { RenderForAllPlayers = function() end }
	local WeaponStows = 0
	local BowStows = 0
	Services.WeaponService = { Equip = function(_Self: any, Character: any, State: boolean)
		WeaponStows += 1
		Character:SetAttribute("WeaponEquipped", State)
	end }
	Services.BowService = { SetInHand = function(_Self: any, Player: any, InHand: boolean)
		BowStows += 1
		Player.Character:SetAttribute("BowEquipped", InHand)
		Player.Character:SetAttribute("BowDrawing", false)
	end }
	Services.HitService = { HitResolved = { Event = Signal() } }
	Services.PartyService = { GetPlayerParty = function(): any
		return nil
	end }
	Services.ItemService = { GetItemData = function(_Self: any, Name: string): any
		return if Name == "TestArtifact" then { Type = "Artifact" } else nil
	end }
	Services.ItemService.CreateItem = function(_Self: any, Name: string, Stack: number): any
		return { Name = Name, Stack = Stack, Class = "Skill" }
	end
	Services.StanceService = { GetStance = function(): any
		return { BaseDamage = 10, BaseStaminaCost = 10 }
	end }
	Services.RaceService = { GetRaceData = function(): any
		return { BaseStats = { MaxHealth = 100 } }
	end }
	Services.EquipmentService = { EquipmentTypes = {} }
	local TalentDamage = {}
	Services.TalentService = { RecordDamage = function(_Self: any, Character: any, Attacker: any, Amount: number)
		table.insert(TalentDamage, { Character, Attacker, Amount })
	end }
	Services.InventoryService = { RemoveItemFromPlayer = function() end }
	Services.InventoryService.GetPlayerItemByName = function(_Self: any, Player: any, Name: string): any
		for _, Item in Profiles[Player].Inventory do
			if Item.Name == Name then return Item end
		end
		return nil
	end
	Services.InventoryService.GiveItemToPlayer = function(_Self: any, Player: any, Item: any)
		table.insert(Profiles[Player].Inventory, Item)
	end
	Services.AlertService = { AlertPlayer = function() end }
	Services.ArtifactService = {}
	Services.IntroCutsceneService = { TryInterceptHit = function(): boolean
		return false
	end }
	local Modules = {
		Knit = Knit,
		Trees = { Kendo = { Name = "Kendo", Branches = { { Name = "Kendo Proficiency I", Passive = true, PointsRequired = 1 } } } },
		CharacterShared = { UpdateWalkspeed = function() end },
		InventoryConfig = { DefaultBackpackTier = 1, Columns = 6, Rows = 8 },
		HorseConfig = { DefaultTier = 1 },
	}
	local Env = setmetatable({
		game = { GetService = function(_Self: any, Name: string): any
			return ({ Players = Players, ReplicatedStorage = ReplicatedStorage, RunService = { Heartbeat = Signal() } })[Name]
		end },
		workspace = Workspace,
		Instance = { new = InstanceNew },
		Vector3 = { new = VectorNew },
		Color3 = { fromRGB = function(...: any): any return { ... } end },
		require = function(Name: string): any
			assert(Modules[Name], Name)
			return Modules[Name]
		end,
	}, { __index = getfenv() })
	local function Load(Source: string): any
		local Chunk = assert(loadstring(Source))
		setfenv(Chunk, Env)
		return Chunk()
	end
	local Config = Load(Sources.Config)
	Modules.Config = Config
	Modules.TreeConfig = Load(Sources.TreeConfig)
	Modules.TreeProgression = Load(Sources.TreeProgression)
	local Template = Load(Sources.Profile)
	local Stats = Load(Sources.StatService)
	local Trees = Load(Sources.SkillTreeService)
	local Values = Load(Sources.ValuesService)
	local Damage = Load(Sources.DamageService)
	local Skills = Load(Sources.SkillService)
	for _, Service in { Stats, Trees, Values, Damage, Skills } do
		Service.KnitInit()
	end
	Trees.KnitStart()
	local PureChecks = Load(Sources.PureTests)(Config) + Load(Sources.TreeTests)(Modules.TreeConfig, Modules.TreeProgression)
	local LoadingPlayer = InstanceNew("Player")
	Profiles[LoadingPlayer] = Copy(Template)
	Check(Stats:GetProgress(LoadingPlayer).Strength.Level == 0, "UI reads safely before stat initialization")

	local function NewPlayer(): any
		local Player = InstanceNew("Player")
		Player.UserId = 1
		local Profile = Copy(Template)
		Profile.Race = "Human"
		Profiles[Player] = Profile
		Stats:LoadPlayer(Player)
		Trees:LoadAttributes(Player)
		return Player
	end
	local function Character(Player: any): any
		local Model = InstanceNew("Model")
		Owners[Model] = Player
		Player.Character = Model
		local Root = InstanceNew("Part")
		Root.Position = VectorNew(0, 0, 0)
		Root.Parent = Model
		Model.PrimaryPart = Root
		for Name, Value in { Loaded = true, Health = 100, MaxHealth = 100, Stamina = 100, MaxStamina = 100, Race = "Human", Stance = "Beginner" } do
			Model:SetAttribute(Name, Value)
		end
		return Model
	end
	local Player = NewPlayer()
	local Data = Profiles[Player]
	Check(Data.Level == nil and Data.Exp == nil, "New profiles have no general level")
	Check(Data.FreePoints == 0 and Data.SkillPoints.Strength == 0, "New profiles start without attribute points")
	Check(#Data.Inventory == 3 and #Data.OtherSkills == 3, "The beginner sword kit is granted without attribute points")
	Check(Player:GetAttribute("FightingStyle") == nil and Player:GetAttribute("SwordStyle") == "Beginner",
		"The initial sword path does not occupy the fighting style slot")
	for _, Name in Config.Names do
		Check(Data.Stats[Name].Level == 0 and Data.Stats[Name].XP == 0, Name .. " starts at zero")
	end
	Stats:GiveXP(Player, "Strength", Config.GetXPRequired("Strength", 0))
	Check(Data.Stats.Strength.Level == 1 and Data.Stats.Strength.XP == 0 and Data.SkillPoints.Strength == 1, "Exact threshold grants a strength point")
	Stats:GiveXP(Player, "Vitality", Config.GetXPRequired("Vitality", 0))
	Check(Data.SkillPoints.Strength == 1 and Data.SkillPoints.Vitality == 1 and Data.SkillPoints.Dexterity == 0, "Attributes have independent point balances")
	Stats:GiveXP(Player, "Strength", Config.GetXPRequired("Strength", 1) + Config.GetXPRequired("Strength", 2) + 17)
	Check(Data.Stats.Strength.Level == 3 and Data.Stats.Strength.XP == 17 and Data.SkillPoints.Strength == 3, "Multiple levels preserve remainder and award attribute points")
	for _, Amount in { -1, math.huge, 0 / 0 } do
		Stats:GiveXP(Player, "Strength", Amount)
	end
	Stats:GiveXP(Player, "Unknown", 100)
	Check(Data.Stats.Strength.XP == 17, "Invalid awards cannot change progress")
	Stats:GiveXP(Player, "Strength", 10000000)
	local Points = Data.SkillPoints.Strength
	Stats:GiveXP(Player, "Strength", 10000000)
	Check(Data.Stats.Strength.Level == Config.MaxLevel and Data.Stats.Strength.XP == 0 and Data.SkillPoints.Strength == Points, "The cap prevents additional XP and points")
	Check(Stats.Client.GiveXP == nil, "There is no client XP-award remote")
	local RewardPlayer = NewPlayer()
	Stats:GiveRewardXP(RewardPlayer, 60, "Combat")
	local RewardXP = 30 * Config.Rewards.Multiplier
	Check(Profiles[RewardPlayer].Stats.Strength.XP == RewardXP and Profiles[RewardPlayer].Stats.Dexterity.XP == RewardXP, "Rewards use configured weights and scaling")
	local RewardBefore = Profiles[RewardPlayer].Stats.Strength.XP
	Stats:GiveRewardXP(RewardPlayer, 10500, "Combat")
	Check(Profiles[RewardPlayer].Stats.Strength.XP == RewardBefore + Config.Rewards.MaxXPPerStat, "Large legacy rewards respect the per-stat reward cap")
	local Legacy = NewPlayer()
	local Old = Profiles[Legacy]
	Old.StatProgressionVersion = 0
	Old.Level = 3
	Old.Exp = 50
	Old.FreePoints = 2
	Old.UnlockedNodes = { "Kendo Proficiency I", "Oni Health Recovery", "Longer Barrage" }
	Old.SkillTreeVersion = 0
	Old.LegacySkillTree = nil
	Stats:LoadPlayer(Legacy)
	Trees:LoadAttributes(Legacy)
	Check(Old.Level == nil and Old.Exp == nil and Old.LegacyProgression.Level == 3, "Legacy fields are archived and retired")
	Check(Old.LegacySkillTree.FreePoints == 2 and Old.LegacySkillTree.UnlockedNodes[1] == "Kendo Proficiency I"
		and Legacy.UnlockedNodes:FindFirstChild("Kendo Proficiency I") == nil, "Migration archives legacy points and retires old nodes")
	Check(Trees:IsSkillUnlocked(Legacy, "Oni Health Recovery") and Trees:IsSkillUnlocked(Legacy, "Longer Barrage"),
		"Already learned racial skills and sword modifiers become permanent knowledge")
	local XP = Old.Stats.Strength.XP
	local Credits = Old.LegacySkillPointCredits
	Stats:LoadPlayer(Legacy)
	Trees:LoadAttributes(Legacy)
	Check(Old.Stats.Strength.XP == XP and Old.LegacySkillPointCredits == Credits, "Repeated loads do not migrate twice")
	local Earned = Stats:GetEarnedSkillPoints(Legacy, "Strength")
	Trees:ResetSkillTree(Legacy)
	Check(Old.SkillPoints.Strength == Earned and #Old.UnlockedNodes == 0 and #Old.Inventory == 3,
		"Reset restores attribute points and preserves permanent sword skills")
	local Specialist = NewPlayer()
	local SpecialData = Profiles[Specialist]
	SpecialData.Stats.Strength.Level = 10
	SpecialData.Stats.Agility.Level = 10
	SpecialData.Stats.Spirit.Level = 10
	Stats:Publish(Specialist)
	Check(SpecialData.SkillPoints.Strength == 10 and SpecialData.SkillPoints.Spirit == nil,
		"Spirit creates no spendable skill tree points")
	Check(not Trees:UnlockNode(Specialist, "Feint"), "Strength cannot buy Dexterity nodes")
	for _, Name in { "Committed Attack", "Continuity", "Make Room", "Heavy Impact", "Exploit Opening" } do
		Check(Trees:UnlockNode(Specialist, Name), "A full strength route can be purchased")
	end
	Check(SpecialData.SkillPoints.Strength == 0 and SpecialData.SkillPoints.Agility == 10, "Purchases debit only their own attribute")
	Check(not Trees:UnlockNode(Specialist, "Close Pressure") and not Trees:UnlockNode(Specialist, "Heavy Impact"), "Exclusive and duplicate purchases fail")
	Check(not Trees:UnlockNode(Specialist, {}) and not Trees:UnlockNode(Specialist, "Kendo Proficiency I"), "Malformed and retired nodes are rejected")
	Trees:LoadAttributes(Specialist)
	Check(SpecialData.SkillPoints.Strength == 0 and #SpecialData.Inventory == 3, "Reloading does not refund purchases or duplicate starter items")
	Check(Trees:UnlockNode(Specialist, "Travel Breath"), "Another attribute can spend its own points")
	Check(Trees:ResetSpecificSkillTree(Specialist, "Strength"), "A single tree can be reset")
	Check(SpecialData.SkillPoints.Strength == 10 and SpecialData.SkillPoints.Agility == 8 and Trees:IsSkillUnlocked(Specialist, "Travel Breath"),
		"Single-tree resets preserve other purchases")
	Check(Trees:UnlockNode(Specialist, "Committed Attack"), "Refunded points remain spendable")
	Trees:ResetSkillTree(Specialist)
	Check(SpecialData.SkillPoints.Strength == 10 and SpecialData.SkillPoints.Agility == 10
		and #SpecialData.Inventory == 3 and Trees:IsSkillUnlocked(Specialist, "Up Slash"), "Full resets preserve the sword kit")
	SpecialData.FightingStyle = "Bow"
	Trees:LoadAttributes(Specialist)
	Trees:ResetSkillTree(Specialist)
	Check(Specialist:GetAttribute("FightingStyle") == "Bow" and Specialist:GetAttribute("SwordStyle") == "Beginner",
		"Sword paths and learned fighting styles coexist and survive tree resets")
	SpecialData.FightingStyle = "Sword"
	Trees:LoadAttributes(Specialist)
	Check(Specialist:GetAttribute("FightingStyle") == nil and Specialist:GetAttribute("SwordStyle") == "Beginner",
		"Sword cannot be restored into the fighting style slot")
	Trees:LearnOtherSkill(Specialist, "WallRun")
	Check(Trees:IsSkillUnlocked(Specialist, "WallRun") and Specialist.UnlockedNodes.WallRun:GetAttribute("OtherSkill") == true,
		"The wall run trainer still grants permanent knowledge with a replicated source marker")
	Check(SpecialData.SkillPoints.Agility == 10 and not Trees:UnlockNode(Specialist, "WallRun"),
		"Trainer unlocks spend no agility points and cannot be bought twice")
	Trees:LearnOtherSkill(Specialist, "Climb Speed")
	Check(not Trees:IsSkillUnlocked(Specialist, "Climb Speed"), "Other skill grants cannot bypass normal tree purchases")
	Trees:LoadAttributes(Specialist)
	Check(Trees:IsSkillUnlocked(Specialist, "WallRun") and Specialist.UnlockedNodes.WallRun:GetAttribute("OtherSkill") == true,
		"Existing trainer unlocks remain replicated after reload")
	Trees:ResetSkillTree(Specialist)
	Check(Trees:IsSkillUnlocked(Specialist, "WallRun") and SpecialData.SkillPoints.Agility == 10,
		"Tree resets preserve wall run learned from the trainer")
	for _, Name in { "Travel Breath", "WallRun", "Climb Speed" } do
		if Name ~= "WallRun" then
			Check(Trees:UnlockNode(Specialist, Name), "Optional traversal talents can be purchased: " .. Name)
		end
	end
	Check(SpecialData.SkillPoints.Agility == 6, "Purchased traversal talents debit agility points")
	Trees:ResetSpecificSkillTree(Specialist, "Agility")
	Check(not Trees:IsSkillUnlocked(Specialist, "Climb Speed") and Trees:IsSkillUnlocked(Specialist, "WallRun"),
		"Agility resets remove purchases and preserve trainer knowledge")
	local Trainee = NewPlayer()
	local AttackingPlayer = NewPlayer()
	local Defender = Character(Trainee)
	local Attacker = Character(AttackingPlayer)
	local Training = Profiles[Trainee].Stats
	Stats:RecordHit(Defender, Attacker, "Block", {}, 10)
	Stats:RecordHit(Defender, Attacker, "Deflect", {}, 10)
	Stats:RecordHit(Defender, Attacker, "Dodge", {}, 10)
	Stats:RecordHit(Defender, Attacker, "Hit", { By = "Weapon" }, 10)
	Check(Training.Resistance.XP == Config.Training.Block and Training.Dexterity.XP == Config.Training.Parry and Training.Agility.XP == Config.Training.Dodge, "Defensive actions train their own attributes")
	Check(Profiles[AttackingPlayer].Stats.Strength.XP == Config.Training.MeleeHit, "Landed melee attacks train strength")
	Damage:DealDamage(Defender, 20, Attacker)
	Check(Defender:GetAttribute("Health") == 80 and Training.Vitality.XP == 20 * Config.Training.DamageTaken, "Actual combat damage trains vitality")
	Check(#TalentDamage == 1 and TalentDamage[1][1] == Defender and TalentDamage[1][2] == Attacker and TalentDamage[1][3] == 20,
		"Actual health loss notifies combat recovery on the server")
	Defender:SetAttribute("ForceField", true)
	Damage:DealDamage(Defender, 20, Attacker)
	Check(Training.Vitality.XP == 20 * Config.Training.DamageTaken, "Protected damage grants no vitality XP")
	Check(#TalentDamage == 1, "Protected damage cannot start or cancel talent recovery")
	Defender:SetAttribute("ForceField", false)
	Stats:SampleTraining(1)
	Defender:SetAttribute("Running", true)
	local PreviousAgility = Training.Agility.XP
	Stats:SampleTraining(1)
	Check(Training.Agility.XP == PreviousAgility, "Running in place grants no XP")
	Defender.PrimaryPart.Position = VectorNew(20, 0, 0)
	Stats:SampleTraining(1)
	Check(Training.Agility.XP == PreviousAgility + 20 * Config.Training.RunDistance, "Sprinting distance grants agility XP")
	Defender.PrimaryPart.Position = VectorNew(2000, 0, 0)
	Stats:SampleTraining(1)
	Check(Training.Agility.XP == PreviousAgility + 20 * Config.Training.RunDistance, "Teleports are not running distance")
	Defender:SetAttribute("Running", false)
	Defender:SetAttribute("WeaponEquipped", true)
	Defender:SetAttribute("BowEquipped", true)
	Defender:SetAttribute("BowDrawing", true)
	Stats:SetMeditating(Trainee, true)
	Stats:SampleTraining(1)
	Check(Training.Spirit.XP == 0, "Meditation away from rugs is rejected")
	Check(WeaponStows == 0 and BowStows == 0 and Defender:GetAttribute("WeaponEquipped")
		and Defender:GetAttribute("BowEquipped"), "Rejected meditation must not stow weapons")
	Defender.PrimaryPart.Position = VectorNew(0, 0, 0)
	Defender:SetAttribute("RealmEditing", true)
	Trainee:SetAttribute("MeditateAnywhere", true)
	Stats:SetMeditating(Trainee, true)
	Stats:SampleTraining(1)
	Check(not Defender:GetAttribute("Meditating") and Training.Spirit.XP == 0 and WeaponStows == 0 and BowStows == 0,
		"Realm editing blocks meditation and XP even with MeditateAnywhere")
	Defender:SetAttribute("RealmEditing", false)
	Trainee:SetAttribute("InIntroCutscene", true)
	Stats:SetMeditating(Trainee, true)
	Stats:SampleTraining(1)
	Check(not Defender:GetAttribute("Meditating") and Training.Spirit.XP == 0 and WeaponStows == 0 and BowStows == 0,
		"Introduction blocks meditation even with MeditateAnywhere")
	Trainee:SetAttribute("InIntroCutscene", false)
	Trainee:SetAttribute("MeditateAnywhere", false)
	Stats:SetMeditating(Trainee, true)
	Check(WeaponStows == 1 and BowStows == 1 and not Defender:GetAttribute("WeaponEquipped")
		and not Defender:GetAttribute("BowEquipped") and not Defender:GetAttribute("BowDrawing"),
		"Accepted meditation must stow melee weapons and cancel/stow the bow")
	Stats:SampleTraining(1)
	Check(Training.Spirit.XP == Config.Training.Meditation, "Valid server meditation grants spirit XP")
	Defender.PrimaryPart.Position = VectorNew(3, 0, 0)
	Stats:SampleTraining(1)
	Check(Training.Spirit.XP == Config.Training.Meditation and not Defender:GetAttribute("Meditating"), "Moving ends meditation training")
	Stats:SetMeditating(Trainee, false)
	Check(WeaponStows == 1 and BowStows == 1 and not Defender:GetAttribute("WeaponEquipped")
		and not Defender:GetAttribute("BowEquipped"), "Ending meditation must leave weapons stowed")
	Skills:SetSkillData(Attacker, "TestArtifact", "Charge")
	Skills:SetSkillData(Attacker, "TestArtifact", "Active")
	Check(Profiles[AttackingPlayer].Stats.Spirit.XP == Config.Training.ArtifactSkill, "An artifact activation grants XP once across its states")
	Values:UpdateAll(Defender, false)
	local Health = Defender:GetAttribute("MaxHealth")
	local Stamina = Defender:GetAttribute("MaxStamina")
	local Posture = Defender:GetAttribute("MaxPosture")
	local WeaponDamage = Defender:GetAttribute("SwordDamage")
	local ActualDamage = Damage:CalculateDamage(Defender, Attacker, 0, { "Weapon" })
	for _, Name in Config.Names do
		Profiles[Trainee].Stats[Name].Level = 2
	end
	Values:UpdateAll(Defender, false)
	Check(Defender:GetAttribute("MaxHealth") == Health + 2 * Config.Bonuses.Vitality.Health, "Vitality applies its health bonus")
	Check(Defender:GetAttribute("MaxStamina") == Stamina + 2 * Config.Bonuses.Resistance.Stamina and Defender:GetAttribute("MaxPosture") == Posture + 2 * Config.Bonuses.Resistance.Posture, "Resistance applies stamina and posture bonuses")
	Check(Defender:GetAttribute("SwordDamage") == WeaponDamage + 2 * Config.Bonuses.Strength.WeaponDamage, "Strength applies displayed damage")
	local NewDamage = Damage:CalculateDamage(Defender, Attacker, 0, { "Weapon" })
	Check(math.abs(NewDamage - ActualDamage - 2 * Config.Bonuses.Strength.WeaponDamage) < 0.001, "Strength applies actual damage")
	Check(math.abs(Defender:GetAttribute("DefaultWalkSpeed") - (12 + 2 * Config.Bonuses.Agility.WalkSpeed)) < 0.001, "Agility applies movement bonuses")
	Check(Damage:CanDamage(Defender, Attacker), "Combat no longer depends on general level")

	local MaxPlayer = NewPlayer()
	MaxPlayer.Name = "MaxPlayer"
	local MaxCharacter = Character(MaxPlayer)
	local MaxData = Profiles[MaxPlayer]
	Stats:GiveXP(MaxPlayer, "Strength", Config.GetXPRequired("Strength", 0) + Config.GetXPRequired("Strength", 1))
	Check(Trees:UnlockNode(MaxPlayer, "Committed Attack"), "Existing purchases precede the max-stats command")
	local MaxCommand = Load(Sources.MaxStatsCommand)
	Check(Load(Sources.MaxStatsDefinition).Group == "Admin" and Stats.Client.MaxStats == nil,
		"Maxing stats uses admin permissions without exposing a client remote")
	Check(MaxCommand({ Executor = MaxPlayer }):find(MaxPlayer.Name, 1, true) ~= nil, "The command defaults to its executor")
	for _, Name in Config.Names do
		Check(MaxData.Stats[Name].Level == Config.MaxLevel and MaxData.Stats[Name].XP == 0
			and MaxPlayer:GetAttribute(Name .. "Level") == Config.MaxLevel and MaxPlayer:GetAttribute(Name .. "XPRequired") == 0,
			"Maxing saves and replicates the configured maximum: " .. Name)
	end
	Check(MaxData.SkillPoints.Strength == Config.MaxLevel * Config.PointsPerLevel - 2
		and MaxData.SkillPoints.Agility == Config.MaxLevel * Config.PointsPerLevel and MaxData.SkillPoints.Spirit == nil,
		"Maxing grants earned points while accounting for existing purchases and excluding Spirit")
	Check(MaxCharacter:GetAttribute("MaxHealth") == 100 + Config.MaxLevel * Config.Bonuses.Vitality.Health
		and MaxCharacter:GetAttribute("MaxStamina") == 100 + Config.MaxLevel * Config.Bonuses.Resistance.Stamina,
		"Maxing immediately applies character bonuses")
	Check(Stats:MaxStats(MaxPlayer) and Trees:IsSkillUnlocked(MaxPlayer, "Committed Attack")
		and #MaxData.Inventory == 3, "Repeated maxing preserves purchased talents and inventory")
	Stats:LoadPlayer(MaxPlayer)
	Check(Stats:GetLevel(MaxPlayer, "Spirit") == Config.MaxLevel, "Maxed stats survive profile reload")
	local Target = NewPlayer()
	Target.Name = "SelectedPlayer"
	local Missing = InstanceNew("Player")
	Missing.Name = "UnloadedPlayer"
	local Response = MaxCommand({ Executor = MaxPlayer }, { Target, Missing })
	Check(Stats:GetLevel(Target, "Agility") == Config.MaxLevel and Response:find(Target.Name, 1, true) ~= nil
		and Response:find(Missing.Name, 1, true) ~= nil, "Selected players update while unloaded profiles report failure")
	Check(not Stats:MaxStats(LoadingPlayer), "A profile whose stats have not loaded cannot be maxed")
	return tostring(PureChecks + Checks) .. " progression checks passed"
end
