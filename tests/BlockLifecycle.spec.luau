-- Runs production server/client modules with queued networking and separate replicas.
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

		return Event
	end

	local function Object(ClassName: string): any
		local Attributes = {}
		local Signals = {}
		local Result = {
			ClassName = ClassName,
			Humanoid = { WalkSpeed = 12, JumpPower = 30 },
			Destroying = Signal(),
			AttributeChanged = Signal(),
			CharacterAdded = Signal(),
			CharacterRemoving = Signal(),
			InWorkspace = true,
		}
		function Result:IsA(Name: string): boolean
			return self.ClassName == Name
		end

		function Result:FindFirstChildWhichIsA(Name: string): any
			return if Name == "Humanoid" then self.Humanoid else nil
		end

		function Result:IsDescendantOf(_Ancestor: any): boolean
			return self.InWorkspace
		end

		function Result:GetAttribute(Name: string): any
			return Attributes[Name]
		end

		function Result:SetAttribute(Name: string, Value: any)
			if Attributes[Name] == Value then
				return
			end

			Attributes[Name] = Value
			if Signals[Name] then
				Signals[Name]:Fire()
			end
			self.AttributeChanged:Fire(Name)
		end

		function Result:GetAttributeChangedSignal(Name: string): any
			Signals[Name] = Signals[Name] or Signal()
			return Signals[Name]
		end

		return Result
	end

	local function Fixture(MovementBindings: boolean?): any
		local F = { Requests = {}, Results = {}, Jobs = {}, Playing = false, Starts = 0 }
		local Now = 100
		local ClientPlayer = Object("Player")
		local ServerPlayer = Object("Player")
		local ClientCharacter = Object("Model")
		local ServerCharacter = Object("Model")
		ClientPlayer.Character = ClientCharacter
		ServerPlayer.Character = ServerCharacter
		ClientPlayer:SetAttribute("FovEffects", true)
		ClientCharacter:SetAttribute("WeaponEquipped", true)
		ServerCharacter:SetAttribute("WeaponEquipped", true)
		for _, Character in { ClientCharacter, ServerCharacter } do
			Character:SetAttribute("Weapon", "Katana")
			Character:SetAttribute("DefaultWalkSpeed", 12)
			Character:SetAttribute("DefaultJumpPower", 30)
			Character:SetAttribute("Blocking", false)
		end
		local CharacterMap = { [ClientCharacter] = ServerCharacter }
		local Input = {
			InputBegan = Signal(), InputEnded = Signal(), WindowFocusReleased = Signal(), TextBoxFocused = Signal(),
		}
		local EnumMock = {
			UserInputState = { Begin = "Begin", End = "End", Cancel = "Cancel" },
			KeyCode = { F = "F" }, EasingStyle = { Sine = "Sine" }, EasingDirection = { Out = "Out" },
		}
		local Noop = setmetatable({}, { __index = function(): any
			return function() end
		end })
		local KnitServer = {
			CreateService = function(Service: any): any
				return Service
			end,
			CreateSignal = Signal,
			GetService = function(Name: string): any
				if Name == "DebounceService" then
					return { AddDebounce = function(_Self: any, Character: any, Attribute: string, Duration: number)
						Character:SetAttribute(Attribute, true)
						table.insert(F.Jobs, { At = Now + Duration, Run = function()
							Character:SetAttribute(Attribute, false)
						end })
					end }
				end
				if Name == "AnimationService" then
					return { StopAttackAnimations = function()
						F.Starts += 1
					end }
				end

				return Noop
			end,
		}
		local function Load(Source: string, Knit: any, Players: any): any
			local ReplicatedStorage = { Packages = { Knit = Knit }, Shared = {
				Validate = F.Validate, CharacterShared = F.Movement or Noop, Constants = { DEFAULT_FIELD_OF_VIEW = 70 },
				BowConfig = { DrawWalkSpeed = 6 }, CrouchConfig = { WalkSpeed = 6 },
				Utils = { GetModelMass = Noop, TeleportCharacter = Noop },
			} }
			local Camera = { FieldOfView = 70 }
			local Services = { Players = Players, ReplicatedStorage = ReplicatedStorage, UserInputService = Input,
				TweenService = { Create = function(_Self: any, _Camera: any, _Info: any, Target: any): any
					return { Cancel = function() end, Destroy = function() end, Play = function()
						Camera.FieldOfView = Target.FieldOfView
					end }
				end },
			}
			local Environment = setmetatable({
				game = { ReplicatedStorage = ReplicatedStorage, GetService = function(_Self: any, Name: string): any
					return Services[Name] or Noop
				end },
				require = function(Module: any): any
					return Module
				end,
				workspace = { CurrentCamera = Camera }, Enum = EnumMock,
				TweenInfo = { new = function(): any return {} end },
				UDim2 = { fromScale = function(): any return {} end },
				Vector3 = { new = function(): any return {} end },
				task = { spawn = function(Callback: () -> ())
					Callback()
				end },
				tick = function(): number return Now end,
				typeof = function(Value: any): string
					return if type(Value) == "table" and Value.ClassName then "Instance" else typeof(Value)
				end,
			}, { __index = getfenv() })
			local Chunk = assert(loadstring(Source))
			setfenv(Chunk, Environment)
			return Chunk()
		end

		F.Validate = Load(Sources.Validate, KnitServer, Noop)
		local ServerPlayers = { GetPlayerFromCharacter = function(): any
			return ServerPlayer
		end }
		F.Movement = Load(Sources.Movement, KnitServer, ServerPlayers)
		if MovementBindings then
			local CharacterService = Load(Sources.Character, KnitServer, ServerPlayers)
			CharacterService:BindEvents(ServerCharacter, ServerPlayer)
		end
		F.Server = Load(Sources.Server, KnitServer, ServerPlayers)
		F.Server.Client.BlockResult.Fire = function(_Self: any, _Player: any, Character: any, Sequence: number, Blocking: boolean)
			table.insert(F.Results, { Character = Character, Sequence = Sequence, Blocking = Blocking })
		end
		F.Server.KnitInit()
		F.Server.KnitStart()
		local ResultEvent = Signal()
		local ClientPosture = { BlockResult = ResultEvent, BlockRequest = {
			Fire = function(_Self: any, Character: any, Held: boolean, Sequence: number)
				table.insert(F.Requests, { Character = Character, Held = Held, Sequence = Sequence })
			end,
		} }
		local Device = {
			BindAction = function(_Self: any, _Name: string, Callback: any)
				F.MobileInput = Callback
			end,
			UnbindAction = function()
				F.MobileInput = nil
			end,
		}
		local Animation = {
			GetCombatAnimationFolder = function(): any return { Block = {} } end,
			GetAnimationFind = function(): any return F.Playing end,
			PlayAnimation = function() F.Playing = true end,
			StopAnimationFind = function() F.Playing = false end,
		}
		local KnitClient = {
			CreateController = function(Controller: any): any return Controller end,
			GetService = function(): any return ClientPosture end,
			GetController = function(Name: string): any
				return if Name == "AnimationController" then Animation elseif Name == "DeviceController" then Device else Noop
			end,
		}
		F.Client = Load(Sources.Client, KnitClient, { LocalPlayer = ClientPlayer })
		F.Client.KnitStart()
		F.ClientCharacter = ClientCharacter
		F.ServerCharacter = ServerCharacter
		F.Player = ClientPlayer
		F.Input = Input

		function F:Press(Processed: boolean?)
			Input.InputBegan:Fire({ KeyCode = "F" }, Processed == true)
		end

		function F:Release()
			Input.InputEnded:Fire({ KeyCode = "F" }, true)
		end

		function F:Request(Index: number?)
			local Request = assert(table.remove(self.Requests, Index or 1))
			self.Server.Client.BlockRequest:Fire(ServerPlayer, CharacterMap[Request.Character], Request.Held, Request.Sequence)
		end

		function F:ResultsToClient()
			while #self.Results > 0 do
				local Result = table.remove(self.Results, 1)
				local Replica = if Result.Character == ServerCharacter then ClientCharacter else nil
				ResultEvent:Fire(Replica, Result.Sequence, Result.Blocking)
			end
		end

		function F:Replicate(Attribute: string)
			ClientCharacter:SetAttribute(Attribute, ServerCharacter:GetAttribute(Attribute))
		end

		function F:SetBoth(Attribute: string, Value: any)
			ServerCharacter:SetAttribute(Attribute, Value)
			ClientCharacter:SetAttribute(Attribute, Value)
		end

		function F:Advance(Seconds: number)
			Now += Seconds
			for _, Job in self.Jobs do
				if not Job.Done and Job.At <= Now then
					Job.Done = true
					Job.Run()
				end
			end
		end

		function F:Respawn()
			ClientPlayer.CharacterRemoving:Fire(ClientCharacter)
			ClientPlayer.Character = Object("Model")
			ClientPlayer.Character:SetAttribute("WeaponEquipped", true)
			ServerPlayer.Character = Object("Model")
			ServerPlayer.Character:SetAttribute("WeaponEquipped", true)
			CharacterMap[ClientPlayer.Character] = ServerPlayer.Character
			ClientPlayer.CharacterAdded:Fire(ClientPlayer.Character)
		end

		return F
	end

	local function CheckReleased(F: any)
		Check(not F.Playing, "Released block animation must stop")
		Check(F.ClientCharacter:GetAttribute("ClientBlocking") == false, "ClientBlocking must clear immediately")
	end

	local F = Fixture()
	F:Press()
	Check(F.Playing, "Prediction must show block without waiting for the network")
	Check(#F.Requests == 1, "Press must send one request")
	F:Request()
	F:ResultsToClient()
	Check(F.ServerCharacter:GetAttribute("Blocking") == true, "Server must enable valid block")
	F:Release()
	CheckReleased(F)
	F:Request()
	Check(F.ServerCharacter:GetAttribute("Blocking") == false, "Processed release must reach the server")
	F:ResultsToClient()
	CheckReleased(F)

	F = Fixture()
	F:Press()
	F:Release()
	F:Request(2)
	F:Request()
	Check(F.ServerCharacter:GetAttribute("Blocking") ~= true, "Late Begin must not override a newer release")
	Check(F.Starts == 0, "Stale requests must not open a parry window")

	F = Fixture()
	F:Press()
	F:Request()
	F:Release()
	F:ResultsToClient()
	F:Replicate("Blocking")
	CheckReleased(F)
	F:Request()
	F:Replicate("Blocking")
	F:ResultsToClient()
	CheckReleased(F)

	F = Fixture()
	F:Press()
	F:Release()
	F:Press()
	F:Request(3)
	F:Request()
	F:Request()
	F:ResultsToClient()
	Check(F.ServerCharacter:GetAttribute("Blocking") == true, "Newest rapid press must survive old release")
	Check(F.Playing, "Old replies must not stop the newest press")
	F:Release()
	F:Request()
	Check(F.ServerCharacter:GetAttribute("Blocking") == false, "Newest release must stop rapid presses")

	F = Fixture()
	F:Press()
	F:Request()
	F:Release()
	F:Request()
	F:Press()
	F:ResultsToClient()
	Check(F.Playing, "Replies from an older press and release must not override new prediction")
	F:Request()
	F:ResultsToClient()
	Check(F.Playing, "Latest reply must confirm the current press")

	for _, Attribute in { "BeenDeflected", "HeavyDeflect", "Attack", "BlockDebounce" } do
		F = Fixture()
		F:SetBoth(Attribute, true)
		F:Press()
		F:Request()
		F:ResultsToClient()
		Check(F.Starts == 0 and not F.Playing, "Blocked input must wait without opening block")
		Check(#F.Requests == 0, "Waiting for stun must not spam requests")
		F:SetBoth(Attribute, false)
		F:ResultsToClient()
		Check(F.ServerCharacter:GetAttribute("Blocking") == true and F.Playing, "Held block must start after recovery")
		Check(F.Starts == 1, "Recovery must start block only once")
		F:Advance(0.175)
		Check(F.ServerCharacter:GetAttribute("DeflectTime") == false, "Original parry duration must expire")
	end

	F = Fixture()
	F:SetBoth("BeenDeflected", true)
	F:Press()
	F:Request()
	F:Release()
	F:Request()
	F:SetBoth("BeenDeflected", false)
	F:ResultsToClient()
	Check(F.Starts == 0, "Release during parry stun must cancel the pending attempt")
	CheckReleased(F)

	F = Fixture()
	F:Press()
	F:Request()
	F.ServerCharacter:SetAttribute("Blocking", false)
	F:ResultsToClient()
	CheckReleased(F)
	Check(F.ServerCharacter:GetAttribute("Blocking") == false, "Server cancellation must stop visual block even without attribute replication")

	for _, Attribute in { "PostureBreak", "Ragdoll", "Died", "Rolling", "RealmEditing" } do
		F = Fixture()
		F:Press()
		F:Request()
		F:ResultsToClient()
		F.ClientCharacter:SetAttribute(Attribute, true)
		CheckReleased(F)
		F:Request()
		Check(F.ServerCharacter:GetAttribute("Blocking") == false, "Interruptions must send a release")
	end

	for _, Event in { "WindowFocusReleased", "TextBoxFocused" } do
		F = Fixture()
		F:Press()
		F.Input[Event]:Fire()
		CheckReleased(F)
		Check(#F.Requests == 2, "Focus loss must send exactly one release")
	end

	F = Fixture()
	F:Press(true)
	Check(#F.Requests == 0 and not F.Playing, "UI-consumed Begin must not start block")
	F.MobileInput("Begin")
	Check(F.Playing, "Touch input must predict block")
	F.MobileInput("Cancel")
	CheckReleased(F)

	F = Fixture()
	F:SetBoth("RealmEditing", true)
	F:Press()
	F.MobileInput("Begin")
	Check(#F.Requests == 0 and not F.Playing, "Realm editor must reject keyboard and touch block")
	F:SetBoth("RealmEditing", false)
	Check(#F.Requests == 0 and not F.Playing, "Leaving the editor must not replay blocked input")
	F:Press()
	F:Request()
	Check(F.ServerCharacter:GetAttribute("Blocking") == true, "Fresh input must work after leaving the editor")

	F = Fixture()
	F:Press()
	F.ServerCharacter:SetAttribute("RealmEditing", true)
	F:Request()
	Check(F.Starts == 0, "Server must reject combat requests arriving after editor activation")
	F.ServerCharacter:SetAttribute("RealmEditing", false)
	Check(F.Starts == 0, "Server must discard editor inputs instead of queuing them until exit")

	F = Fixture()
	F:Press()
	F:Request()
	F:Respawn()
	F:ResultsToClient()
	Check(not F.Playing, "Old character replies must not animate the new character")
	F:Press()
	F:Request()
	F:Request()
	Check(F.Starts == 2, "Old character release must not prevent new character block")

	F = Fixture()
	F:Press()
	F:Request()
	F:ResultsToClient()
	F.ClientCharacter:SetAttribute("WeaponEquipped", false)
	CheckReleased(F)
	Check(F.MobileInput == nil, "Unequipping must remove the touch action")
	F:Request()
	Check(F.ServerCharacter:GetAttribute("Blocking") == false, "Unequipping must release server block")

	-- Release before the Blocking=false replica arrives must still restore movement later.
	F = Fixture()
	F:Press()
	F:Request()
	F:ResultsToClient()
	F:Replicate("Blocking")
	F.Movement:UpdateBoth(F.ClientCharacter)
	Check(F.ClientCharacter:GetAttribute("TargetWalkSpeed") == 8, "Fixture must enter block movement")
	Check(F.ClientCharacter.Humanoid.JumpPower == 0, "Fixture must disable jumping during block")
	F:Release()
	F:Request()
	F:ResultsToClient()
	F:Replicate("Blocking")
	Check(F.ClientCharacter:GetAttribute("TargetWalkSpeed") == 12, "Delayed block release must restore walking speed")
	Check(F.ClientCharacter.Humanoid.JumpPower == 30, "Delayed block release must restore jumping")

	F = Fixture(true)
	F:Press()
	F:Request()
	Check(F.ServerCharacter:GetAttribute("TargetWalkSpeed") == 8, "Server block must update movement")
	F:Release()
	F:Request()
	Check(F.ServerCharacter:GetAttribute("TargetWalkSpeed") == 12, "Server release must restore its movement target")

	for _, Attribute in { "BeenDeflected", "HeavyDeflect" } do
		F = Fixture(true)
		F:SetBoth(Attribute, true)
		F:Press()
		F:Request()
		F:Release()
		F:Request()
		local StunSpeed = if Attribute == "HeavyDeflect" then 0 else 8
		Check(F.ClientCharacter:GetAttribute("TargetWalkSpeed") == StunSpeed, "Release must respect an active parry stun")
		Check(F.ServerCharacter:GetAttribute("TargetWalkSpeed") == StunSpeed, "Server must keep active stun movement")
		F:SetBoth(Attribute, false)
		F:ResultsToClient()
		F:Replicate("Blocking")
		Check(F.ServerCharacter:GetAttribute("TargetWalkSpeed") == 12, "Parry recovery must restore server movement")
		Check(F.ClientCharacter:GetAttribute("TargetWalkSpeed") == 12, "Parry recovery must restore client movement")
	end

	F = Fixture(true)
	F:Press()
	F:Request()
	F:Replicate("Blocking")
	F:SetBoth("Crouching", true)
	F:Release()
	F:Request()
	F:Replicate("Blocking")
	Check(F.ServerCharacter:GetAttribute("TargetWalkSpeed") == 6, "Block release must preserve crouch speed on server")
	Check(F.ClientCharacter:GetAttribute("TargetWalkSpeed") == 6, "Block release must preserve crouch speed on client")

	return `BlockLifecycle: {Checks} checks passed`
end
