return function(Sources: { [string]: string }): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Signal(): any
		local Event = { Listeners = {}, Calls = {} }
		function Event:Connect(Callback: (...any) -> ()): any
			local Connection = { Callback = Callback, Connected = true }
			function Connection.Disconnect(Current: any)
				Current.Connected = false
			end
			table.insert(self.Listeners, Connection)
			return Connection
		end
		function Event:Fire(...: any)
			table.insert(self.Calls, { ... })
			for _, Connection in self.Listeners do
				if Connection.Connected then
					Connection.Callback(...)
				end
			end
		end
		function Event:Once(Callback: (...any) -> ())
			local Connection
			Connection = self:Connect(function(...: any)
				Connection:Disconnect()
				Callback(...)
			end)
		end
		return Event
	end

	local function Load(Source: string, Environment: any): any
		local Chunk = assert(loadstring(Source))
		setfenv(Chunk, Environment)
		return Chunk()
	end

	local Config = Load(Sources.Config, getfenv())
	local Near = Config.GetPressure(36, 18, 0)
	local Far = Config.GetPressure(36, 18, 40)
	Check(Near > Far and Far > 0, "Nearby enemies receive stronger intimidation")
	Check(Config.GetPressure(60, 18, 0) > Config.GetPressure(18, 18, 0), "A larger level advantage raises pressure")
	Check(Config.GetPressure(18, 24, 0) <= 20, "Higher-level targets have a twenty-percent ceiling")
	Check(Config.GetPressure(60, 0, Config.Radius) == 0, "Aura has no pressure outside its range")
	Check(Config.ShouldPlayCutscene(60, 6, 10), "A large power advantage can trigger a close-up")
	Check(not Config.ShouldPlayCutscene(18, 18, 10), "Comparable levels do not trigger close-ups")
	Check(not Config.ShouldPlayCutscene(60, 0, 30), "Distant targets do not receive close-ups")

	local Names = { "Strength", "Resistance", "Vitality", "Agility", "Dexterity", "Spirit" }
	Config.Definitions.Test = { Aura = "Test" }
	Config.Definitions.Missing = { Aura = "Missing" }
	local Actors, Owners, Levels, Fear = {}, {}, {}, {}
	local Profiles = {}
	local Now, Jobs, Changes = 0, {}, 0
	local Workspace = {}
	local Players = { PlayerAdded = Signal(), PlayerRemoving = Signal() }
	function Players:GetPlayers(): { any }
		return Actors
	end
	function Players:GetPlayerFromCharacter(Character: any): any
		return Owners[Character]
	end
	function Workspace:GetServerTimeNow(): number
		return Now
	end
	function Workspace:GetPartBoundsInRadius(): { any }
		local Parts = {}
		for _, Player in Actors do
			if Player.Character then
				table.insert(Parts, Player.Character.PrimaryPart)
			end
		end
		return Parts
	end

	local function Position(X: number): any
		return setmetatable({ X = X }, { __sub = function(First: any, Second: any): any
			return { Magnitude = math.abs(First.X - Second.X) }
		end })
	end
	local function Actor(StatLevel: number, X: number): any
		local Attributes = {
			Loaded = true, Stamina = 100, SwordStaminaCost = 5,
			Weapon = "Katana", WeaponEquipped = true,
		}
		local Character = { Parent = Workspace, Humanoid = { Health = 100, MoveDirection = { Magnitude = 1 } } }
		local CharacterSignals = {}
		Character.PrimaryPart = { Position = Position(X), FindFirstAncestorOfClass = function(): any
			return Character
		end }
		function Character:GetAttribute(Name: string): any
			return Attributes[Name]
		end
		function Character:SetAttribute(Name: string, Value: any)
			local Previous = Attributes[Name]
			Attributes[Name] = Value
			if Previous ~= Value and CharacterSignals[Name] then
				CharacterSignals[Name]:Fire()
			end
		end
		function Character:GetAttributeChangedSignal(Name: string): any
			CharacterSignals[Name] = CharacterSignals[Name] or Signal()
			return CharacterSignals[Name]
		end
		function Character:FindFirstChildWhichIsA(Name: string): any
			return if Name == "Humanoid" then self.Humanoid else nil
		end
		function Character:FindFirstChild(Name: string): any
			return if Name == "Humanoid" then self.Humanoid else nil
		end
		function Character:IsDescendantOf(_Root: any): boolean
			return self.Parent ~= nil
		end
		local PlayerAttributes, AttributeSignals = {}, {}
		local Player = { Parent = Players, Character = Character, Neutral = true, CharacterRemoving = Signal(), CharacterAdded = Signal() }
		function Player:GetAttribute(Name: string): any
			return PlayerAttributes[Name]
		end
		function Player:SetAttribute(Name: string, Value: any)
			local Previous = PlayerAttributes[Name]
			PlayerAttributes[Name] = Value
			if Previous ~= Value and AttributeSignals[Name] then
				AttributeSignals[Name]:Fire()
			end
		end
		function Player:GetAttributeChangedSignal(Name: string): any
			AttributeSignals[Name] = AttributeSignals[Name] or Signal()
			return AttributeSignals[Name]
		end
		Profiles[Player] = { EgoId = "" }
		Levels[Player] = {}
		for _, Name in Names do
			Levels[Player][Name] = StatLevel
		end
		Owners[Character] = Player
		table.insert(Actors, Player)
		return Player
	end

	local Services = {
		DataService = { GetData = function(_Self: any, Player: any): any return Profiles[Player] end },
		StatService = { GetLevel = function(_Self: any, Player: any, Name: string): number return Levels[Player][Name] end },
		FearService = {
			GetFear = function(_Self: any, Player: any): number return Fear[Player] or 0 end,
			SetFear = function(_Self: any, Player: any, Amount: number) Fear[Player] = Amount end,
		},
		PartyService = { GetPlayerParty = function(_Self: any, Player: any): any return Player.Party end },
		PostureService = { Block = function(_Self: any, Character: any, Enabled: boolean) Character:SetAttribute("Blocking", Enabled) end },
		BowService = { CancelDraw = function() end },
		AlertService = { AlertPlayer = function() end },
	}
	local Knit = {
		CreateService = function(Service: any): any return Service end,
		CreateController = function(Controller: any): any return Controller end,
		CreateSignal = Signal,
		GetService = function(Name: string): any return Services[Name] end,
	}
	local ReplicatedStorage = { Packages = { Knit = Knit }, Shared = {
		EgoConfig = Config, StatProgression = { Names = Names }, KickConfig = {},
		CharacterShared = { UpdateBoth = function() Changes += 1 end },
	} }
	ReplicatedStorage.Assets = { VFX = { Ego = { FindFirstChild = function(_Self: any, Name: string): any
		return if Name == "Missing" then nil else { IsA = function(_Asset: any, ClassName: string): boolean
			return ClassName == "Model"
		end }
	end } } }
	local Rolls = 0
	local Environment = setmetatable({
		game = { Players = Players, GetService = function(_Self: any, Name: string): any
			return if Name == "Players" then Players elseif Name == "RunService" then { Heartbeat = Signal() } else ReplicatedStorage
		end },
		require = function(Module: any): any return Module end,
		workspace = Workspace,
		OverlapParams = { new = function(): any return {} end },
		Enum = { RaycastFilterType = { Exclude = {} } },
		Random = { new = function(): any
			return { NextInteger = function(_Self: any, Minimum: number, Maximum: number): number
				Rolls += 1
				return Minimum + (Rolls - 1) % (Maximum - Minimum + 1)
			end }
		end },
		task = { delay = function(Delay: number, Callback: () -> ())
			table.insert(Jobs, { At = Now + Delay, Callback = Callback })
		end },
	}, { __index = getfenv() })
	local Service = Load(Sources.Service, Environment)
	Service.KnitInit()
	local Source = Actor(3, 0)
	local Stronger = Actor(4, 0)
	local Weak = Actor(0, 5)
	Service.KnitStart()
	Check(Source:GetAttribute("EgoId") == "1" and Stronger:GetAttribute("EgoId") == "2",
		"Joining players draw from configured Egos with existing assets")
	Check(Profiles[Source].EgoId == Source:GetAttribute("EgoId"), "The first draw is written to the persistent profile")
	Check(Weak:GetAttribute("EgoId") ~= "Missing", "Missing assets are excluded from the draw")
	local AssignedId = Source:GetAttribute("EgoId")
	local RollsBeforeRespawn = Rolls
	Source.CharacterRemoving:Fire(Source.Character)
	Source.CharacterAdded:Fire(Source.Character)
	Check(Source.Character:GetAttribute("EgoId") == AssignedId and Rolls == RollsBeforeRespawn,
		"Respawning keeps the saved Ego without rolling again")

	Levels[Source].Spirit = 2
	Check(not Service:SetActive(Source, true), "Every stat must reach level three")
	Source:SetAttribute("SpiritLevel", 10)
	Check(not Service:SetActive(Source, true), "Client-facing attributes do not bypass authoritative stat checks")
	Levels[Source].Spirit = 3
	Source:SetAttribute("EgoId", "Missing")
	Source.Character:SetAttribute("EgoId", "Missing")
	Source.Character:SetAttribute("Running", true)
	Source.Character:SetAttribute("Blocking", true)
	Check(Service:SetActive(Source, true), "Eligible players can activate Ego")
	Check(Source:GetAttribute("EgoId") == AssignedId and Source.Character:GetAttribute("EgoId") == AssignedId,
		"Activation restores the authoritative assignment instead of accepting a client-selected Ego")
	Check(Source.Character:GetAttribute("EgoActive") and not Source.Character:GetAttribute("Running")
		and not Source.Character:GetAttribute("Blocking"), "Activation cancels running and blocking")
	Service:Step(0.25)
	Check((Fear[Weak] or 0) > 0 and not Fear[Source], "Ego affects nearby opponents, not its source")
	Check(Weak.Character:GetAttribute("EgoCutscene"), "An out-of-combat weak target receives a cutscene")
	Check(Service.Client.Cutscene.Calls[1][2] == Source.Character and Service.Client.Cutscene.Calls[1][3] == 2,
		"Cutscene points at the intimidator and lasts two seconds")
	for _ = 1, 100 do
		Service:Step(0.25)
	end
	Check((Fear[Stronger] or 0) <= 20, "Sustained intimidation never exceeds twenty against a stronger target")
	Now = 2
	for _, Job in Jobs do
		if Job.At <= Now then
			Job.Callback()
		end
	end
	Check(not Weak.Character:GetAttribute("EgoCutscene"), "Cutscene releases the target after two seconds")
	Check(Changes > 0, "Ego and cutscene state changes refresh movement")
	local Count = #Service.Client.Cutscene.Calls
	Service:Step(0.25)
	Check(#Service.Client.Cutscene.Calls == Count, "Cutscene cooldown prevents repeated interruptions")

	Weak.Character.PrimaryPart.Position = Position(60)
	Fear[Weak] = 0
	Service:Step(0.25)
	Check(Fear[Weak] == 0, "Out-of-range targets receive no fear")
	Weak.Character.PrimaryPart.Position = Position(5)
	local Party = {}
	Source.Party, Weak.Party = Party, Party
	Service:Step(0.25)
	Check(Fear[Weak] == 0, "Party allies are immune")
	Source.Party, Weak.Party = nil, nil
	Source.Neutral, Weak.Neutral, Source.Team, Weak.Team = false, false, Party, Party
	Service:Step(0.25)
	Check(Fear[Weak] == 0, "Teammates are immune")
	Source.Neutral, Weak.Neutral = true, true

	local Second = Actor(3, 0)
	Check(Service:SetActive(Second, true), "Multiple sources can use Ego")
	Fear[Stronger] = 0
	for _ = 1, 100 do
		Service:Step(0.25)
	end
	Check((Fear[Stronger] or 0) <= 20, "Multiple weaker sources cannot stack beyond the cap")
	Check(Service:SetActive(Second, false) and not Second.Character:GetAttribute("EgoActive"), "Ego can be toggled off")

	Service:SetActive(Source, false)
	Now = 40
	Weak:SetAttribute("InCombat", true)
	Service:SetActive(Source, true)
	Count = #Service.Client.Cutscene.Calls
	Service:Step(0.25)
	Check(#Service.Client.Cutscene.Calls == Count, "Targets in combat do not receive cutscenes")
	Weak:SetAttribute("InCombat", false)
	Service:Step(0.25)
	Check(Weak.Character:GetAttribute("EgoCutscene"), "A vulnerable target can receive a new encounter")
	Service:SetActive(Source, false)
	Check(not Weak.Character:GetAttribute("EgoCutscene"), "Stopping the source cancels its cutscene")
	Service:SetActive(Source, true)
	Source.Character:SetAttribute("Died", true)
	Service:Step(0.25)
	Check(not Source.Character:GetAttribute("EgoActive"), "Dead characters cannot keep projecting Ego")
	Source.Character:SetAttribute("Died", false)

	local Validate = Load(Sources.Validate, Environment)
	Source.Character:SetAttribute("EgoActive", true)
	for Action in Config.BlockedActions do
		Check(not Validate:CanPerformIntroAction(Source.Character, Action), "Ego blocks " .. Action)
	end
	Check(Validate:CanEquipWeapon(Source.Character), "Ego allows drawing a sword")
	Check(Validate:CanPerformIntroAction(Source.Character, "Meditate"), "Ego allows meditation")
	Check(not Validate:CanAttack(Source.Character) and not Validate:CanRun(Source.Character)
		and not Validate:CanBlock(Source.Character) and not Validate:CanRoll(Source.Character)
		and not Validate:CanClimb(Source.Character), "Shared action guards enforce Ego restrictions")
	Source.Character:SetAttribute("EgoActive", false)
	Check(Validate:CanAttack(Source.Character), "Combat becomes available after Ego ends")

	local Sounds = {}
	local SoundService = {}
	local AudioEnvironment = setmetatable({
		game = { GetService = function(_Self: any, Name: string): any
			return if Name == "Players" then { LocalPlayer = Source } elseif Name == "SoundService" then SoundService else ReplicatedStorage
		end },
		require = function(Module: any): any return Module end,
		Instance = { new = function(ClassName: string): any
			assert(ClassName == "Sound", "Audio fixture only creates sounds")
			local Sound = { Ended = Signal() }
			function Sound:Play()
				self.Playing = true
			end
			function Sound:Destroy()
				self.Destroyed = true
				self.Playing = false
			end
			table.insert(Sounds, Sound)
			return Sound
		end },
	}, { __index = getfenv() })
	local ControllerSource = Sources.Controller:gsub("return EgoController%s*$",
		"return { RefreshAudio = RefreshAudio, StopAudio = StopAudio }")
	local Audio = Load(ControllerSource, AudioEnvironment)
	Source.Character:SetAttribute("EgoId", "1")
	Source.Character:SetAttribute("EgoActive", true)
	Audio.RefreshAudio(Source.Character, true)
	Check(#Sounds == 2 and Sounds[1].SoundId == "rbxassetid://9112840575" and Sounds[1].Looped
		and Sounds[1].Parent == SoundService, "Ego 1 starts its local background loop")
	Check(Sounds[2].SoundId == Config.Definitions["1"].ActivationSound and not Sounds[2].Looped,
		"Ego 1 plays its activation sound once")
	Audio.RefreshAudio(Source.Character, true)
	Check(#Sounds == 2, "Repeated refreshes do not duplicate audio")
	Sounds[2].Ended:Fire()
	Check(Sounds[2].Destroyed and not Sounds[1].Destroyed, "The activation sound cleans up while the loop continues")
	Audio.RefreshAudio(Weak.Character, true)
	Check(#Sounds == 2 and not Sounds[1].Destroyed, "Other players do not replace the local background audio")
	Source.Character:SetAttribute("EgoActive", false)
	Audio.RefreshAudio(Source.Character, false)
	Check(Sounds[1].Destroyed, "Deactivating Ego stops the background loop")
	Source.Character:SetAttribute("EgoActive", true)
	Audio.RefreshAudio(Source.Character, false)
	Check(#Sounds == 3 and Sounds[3].Looped, "Initial active state restores only the loop")
	Audio.StopAudio(Weak.Character)
	Check(not Sounds[3].Destroyed, "Removing another character keeps the local loop")
	Audio.StopAudio(Source.Character)
	Check(Sounds[3].Destroyed, "Removing the owner character cleans up the loop")

	local SavedData = { EgoId = Profiles[Source].EgoId }
	Players.PlayerRemoving:Fire(Source)
	Profiles[Source] = nil
	local Rejoined = Actor(3, 0)
	Profiles[Rejoined] = SavedData
	local NewService = Load(Sources.Service, Environment)
	NewService.KnitInit()
	local RollsBeforeRejoin = Rolls
	Check(NewService:AssignEgo(Rejoined) == AssignedId and Rolls == RollsBeforeRejoin,
		"A new server restores the saved Ego without rolling again")
	Check(Rejoined.Character:GetAttribute("EgoId") == AssignedId,
		"The saved Ego is replicated to the returning character")

	local Delayed = Actor(3, 0)
	Profiles[Delayed] = nil
	Players.PlayerAdded:Fire(Delayed)
	Check(Delayed:GetAttribute("EgoId") == nil and Rolls == RollsBeforeRejoin,
		"Joining before profile load does not draw a temporary Ego")
	Profiles[Delayed] = { EgoId = "Test" }
	Delayed:SetAttribute("Loaded", true)
	Check(Delayed:GetAttribute("EgoId") == "Test" and Rolls == RollsBeforeRejoin,
		"The Loaded event restores the saved Ego when the profile becomes ready")

	Profiles[Delayed].EgoId = "Missing"
	Check(Service:AssignEgo(Delayed) == "Missing" and Rolls == RollsBeforeRejoin,
		"A temporarily missing aura asset does not overwrite a saved Ego")
	Profiles[Delayed].EgoId = "RemovedEgo"
	Check(Service:AssignEgo(Delayed) ~= "RemovedEgo" and Rolls == RollsBeforeRejoin + 1,
		"An unknown saved Ego is replaced with an available definition")

	local Admin = Actor(3, 0)
	Admin.Name = "Admin"
	Check(Service:SetEgo(Admin, "2"), "An administrator can assign a configured Ego")
	Check(Profiles[Admin].EgoId == "2" and Admin:GetAttribute("EgoId") == "2"
		and Admin.Character:GetAttribute("EgoId") == "2", "Changing Ego updates the profile, player and character")
	Check(not Service:SetEgo(Admin, "Unknown") and Profiles[Admin].EgoId == "2",
		"Unknown Egos must not overwrite the saved assignment")
	Check(not Service:SetEgo(Admin, "Missing") and Profiles[Admin].EgoId == "2",
		"An unavailable aura must not overwrite the saved assignment")
	Check(Service:SetActive(Admin, true), "Assigned Ego can be activated")
	Check(Service:SetEgo(Admin, "1") and Admin.Character:GetAttribute("EgoActive") == true,
		"Changing Ego while active keeps the effect active")
	Service:SetActive(Admin, false)
	local AdminCharacter = Admin.Character
	Admin.Character = nil
	Check(Service:SetEgo(Admin, "2") and Profiles[Admin].EgoId == "2", "Ego can change between respawns")
	Admin.Character = AdminCharacter
	Check(Service:AssignEgo(Admin) == "2" and AdminCharacter:GetAttribute("EgoId") == "2",
		"Respawn preserves an administrator's saved assignment")
	local Unloaded = Actor(3, 0)
	Unloaded.Name = "Unloaded"
	Profiles[Unloaded] = nil
	Check(not Service:SetEgo(Unloaded, "1") and Unloaded:GetAttribute("EgoId") == nil,
		"Players without loaded data must not receive an unsaved Ego")
	Services.EgoService = Service
	local Command = Load(Sources.Command, Environment)
	Check(string.find(Command({ Executor = Admin }, "1"), "Admin", 1, true) ~= nil
		and Profiles[Admin].EgoId == "1", "The command defaults to its executor")
	Check(string.find(Command({ Executor = Admin }, "2", {}), "Admin", 1, true) ~= nil
		and Profiles[Admin].EgoId == "2", "An empty player list defaults to its executor")
	Delayed.Name = "Target"
	local Response = Command({ Executor = Admin }, "1", { Delayed, Unloaded })
	Check(Profiles[Delayed].EgoId == "1" and string.find(Response, "Target", 1, true) ~= nil,
		"The command applies Ego to selected players")
	Check(string.find(Response, "Unloaded", 1, true) ~= nil and string.find(Response, "Failed:", 1, true) ~= nil,
		"The command reports individual failures without dropping successful changes")

	local MusicJobs, CombatSounds = {}, {}
	local function MusicSound(): any
		local Sound = { Name = "Track", IsPlaying = true, Volume = 0.8 }
		function Sound:Play()
			self.IsPlaying = true
		end
		function Sound:Stop()
			self.IsPlaying = false
		end
		function Sound:Pause()
			self.IsPlaying = false
		end
		function Sound:GetAttribute(_Name: string): number
			return 0.8
		end
		function Sound:SetAttribute(_Name: string, _Value: any) end
		function Sound:Clone(): any
			local Copy = MusicSound()
			table.insert(CombatSounds, Copy)
			return Copy
		end
		return Sound
	end
	local Track = MusicSound()
	local Ambiences = {
		GetChildren = function(): { any }
			return {}
		end,
		FindFirstChild = function(): any
			return nil
		end,
	}
	local OSTFolder = { FindFirstChild = function(_Self: any, Name: string): any
		if Name == "DefaultCombat" then
			return { GetChildren = function(): { any }
				return { Track }
			end }
		end
		return nil
	end }
	local Package = { WaitForChild = function(_Self: any, Name: string): any
		return if Name == "Ambience" then Ambiences else OSTFolder
	end }
	local MusicServices = {
		Players = { LocalPlayer = Admin },
		ReplicatedStorage = { Assets = { Libraries = { Zone = {} } }, FindFirstChild = function(): any return nil end },
		SoundService = { WaitForChild = function(): any return Package end },
		TweenService = { Create = function(_Self: any, Sound: any, _Info: any, Goals: any): any
			return { Cancel = function() end, Play = function()
				for Name, Value in Goals do
					Sound[Name] = Value
				end
			end }
		end },
	}
	local MusicEnvironment = setmetatable({
		game = { GetService = function(_Self: any, Name: string): any return MusicServices[Name] end },
		require = function(Module: any): any return Module end,
		TweenInfo = { new = function(): any return {} end },
		task = {
			delay = function(_Time: number, Callback: () -> ()) table.insert(MusicJobs, Callback) end,
			defer = function(Callback: (...any) -> (), ...: any) Callback(...) end,
		},
	}, { __index = getfenv() })
	Admin:SetAttribute("OST", true)
	Admin:SetAttribute("Fear", 0)
	local Music = Load(Sources.Regions .. [[
return {
	IsEnabled = IsOSTEnabled,
	Seed = function(RegionTrack, CombatTrack)
		CurrentOST = RegionTrack
		CurrentCombatOST = CombatTrack
	end,
}
]], MusicEnvironment)
	Check(Music.IsEnabled(), "OST starts enabled without Ego")
	local RegionTrack, CombatTrack = MusicSound(), MusicSound()
	Music.Seed(RegionTrack, CombatTrack)
	AdminCharacter:SetAttribute("EgoActive", true)
	Check(not Music.IsEnabled() and RegionTrack.Volume == 0 and CombatTrack.Volume == 0,
		"Ego activation fades regional and combat OST")
	Check(Admin:GetAttribute("OST") == true, "Ego must not overwrite the saved OST preference")
	for _, Callback in MusicJobs do
		Callback()
	end
	Check(not RegionTrack.IsPlaying and not CombatTrack.IsPlaying, "Faded OST tracks stop")
	Admin:SetAttribute("InCombat", true)
	Check(#CombatSounds == 0, "Entering combat during Ego cannot start combat music")
	AdminCharacter:SetAttribute("EgoActive", false)
	Check(Music.IsEnabled() and #CombatSounds == 1 and CombatSounds[1].IsPlaying,
		"Deactivating Ego resumes the current combat OST")
	Admin:SetAttribute("OST", false)
	AdminCharacter:SetAttribute("EgoActive", true)
	AdminCharacter:SetAttribute("EgoActive", false)
	Check(not Music.IsEnabled() and #CombatSounds == 1, "Ending Ego respects disabled OST settings")
	Admin:SetAttribute("Fear", 50)
	Admin:SetAttribute("OST", true)
	Check(not Music.IsEnabled() and #CombatSounds == 1, "Fear continues to suppress OST after Ego ends")
	Admin:SetAttribute("Fear", 0)
	Check(Music.IsEnabled() and #CombatSounds == 2, "OST resumes when all blockers clear")
	AdminCharacter:SetAttribute("EgoActive", true)
	local Replacement = Actor(3, 0).Character
	Admin.Character = Replacement
	Admin.CharacterAdded:Fire(Replacement)
	Check(Music.IsEnabled(), "A new character does not inherit the old character's Ego mute")
	Replacement:SetAttribute("EgoActive", true)
	Check(not Music.IsEnabled(), "Ego mute follows the replacement character")
	local OldSignal = AdminCharacter:GetAttributeChangedSignal("EgoActive")
	Check(not OldSignal.Listeners[#OldSignal.Listeners].Connected, "Respawn disconnects the previous Ego listener")

	return string.format("Ego: %d checks passed", Checks)
end
