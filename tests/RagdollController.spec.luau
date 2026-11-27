return function(Source: string, AutoRotateSource: string): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Signal(): any
		local Listeners = {}
		local Event = { Calls = {} }
		function Event:Connect(Callback: (...any) -> ()): any
			local Connection = { Connected = true }
			function Connection.Disconnect(Current: any)
				Current.Connected = false
			end
			table.insert(Listeners, { Callback = Callback, Connection = Connection })
			return Connection
		end
		function Event:Fire(...: any)
			table.insert(self.Calls, { ... })
			for _, Listener in table.clone(Listeners) do
				if Listener.Connection.Connected then
					Listener.Callback(...)
				end
			end
		end
		return Event
	end
	local function Track(): any
		return { Stop = function(Current: any, Fade: number)
			Current.Stopped = Fade == 0
		end }
	end
	local Zero = {}
	local function Character(AnimateEnabled: boolean): any
		local RagdollChanged, RecoveryChanged, RotateChanged = Signal(), Signal(), Signal()
		local Subject = { Attributes = {}, PrimaryPart = { CFrame = "replicated-frame" } }
		local Animate = { Enabled = AnimateEnabled, Parent = Subject, IsA = function(_Self: any, Class: string): boolean
			return Class == "LocalScript"
		end }
		local Animator = { AnimationPlayed = Signal(), Tracks = { Track(), Track() } }
		function Animator:GetPlayingAnimationTracks(): { any }
			return self.Tracks
		end
		local AutoRotate = true
		local Humanoid = setmetatable({ EnabledStates = { GettingUp = true }, Jump = true }, {
			__index = function(_Self: any, Key: string): any
				return if Key == "AutoRotate" then AutoRotate else nil
			end,
			__newindex = function(Self: any, Key: string, Value: any)
				if Key == "AutoRotate" then
					AutoRotate = Value
					RotateChanged:Fire()
				else
					rawset(Self, Key, Value)
				end
			end,
		})
		function Humanoid:GetStateEnabled(Name: string): boolean
			return self.EnabledStates[Name]
		end
		function Humanoid:SetStateEnabled(Name: string, Enabled: boolean)
			self.EnabledStates[Name] = Enabled
		end
		function Humanoid:FindFirstChildWhichIsA(Class: string): any
			return if Class == "Animator" then Animator else nil
		end
		function Humanoid:GetPropertyChangedSignal(_Name: string): any
			return RotateChanged
		end
		function Humanoid:Move(Direction: any)
			self.MoveDirection = Direction
		end
		function Humanoid:ChangeState(State: string)
			self.State = State
		end
		function Humanoid:GetAttribute(_Name: string): any
			return nil
		end
		Subject.Humanoid, Subject.Animate, Subject.Animator = Humanoid, Animate, Animator
		function Subject:GetAttribute(Name: string): any
			return self.Attributes[Name]
		end
		function Subject:FindFirstChild(Name: string): any
			return self[Name]
		end
		Subject.WaitForChild = Subject.FindFirstChild
		function Subject:GetAttributeChangedSignal(Name: string): any
			return if Name == "Ragdoll" then RagdollChanged else RecoveryChanged
		end
		function Subject:SetRagdoll(Value: boolean)
			self.Attributes.Ragdoll = Value
			RagdollChanged:Fire()
		end
		function Subject:SetRecoveryId(Id: number?)
			self.Attributes.RagdollRecoveryId = Id
			RecoveryChanged:Fire()
		end
		return Subject
	end
	local Player = { CharacterAdded = Signal(), CharacterRemoving = Signal(), Character = Character(true) }
	local Service = { PrepareRecovery = Signal(), RecoveryReady = Signal() }
	local Modules = { Knit = { CreateController = function(Definition: any): any
		return Definition
	end, GetService = function(_Name: string): any
		return Service
	end }, SetAutoRotate = assert(loadstring(AutoRotateSource))() }
	local Storage = { Packages = { Knit = "Knit" }, Shared = { Utils = { SetAutoRotate = "SetAutoRotate" } } }
	local Load = assert(loadstring(Source))
	setfenv(Load, setmetatable({
		game = { GetService = function(_Self: any, Name: string): any
			return if Name == "Players" then { LocalPlayer = Player } else Storage
		end },
		require = function(Name: string): any
			return Modules[Name]
		end,
		Vector3 = { zero = Zero },
		Enum = { HumanoidStateType = { Physics = "Physics", GettingUp = "GettingUp" } },
	}, { __index = getfenv() }))
	Load().KnitStart()
	local Subject = Player.Character
	Check(Subject.Animate.Enabled and Subject.Humanoid.State == nil, "A standing character keeps its animation script and state")
	Subject:SetRagdoll(true)
	Check(not Subject.Animate.Enabled and Subject.Animator.Tracks[1].Stopped and Subject.Animator.Tracks[2].Stopped,
		"Entering ragdoll disables locomotion and immediately stops existing animations")
	Check(not Subject.Humanoid.AutoRotate and not Subject.Humanoid.Jump and Subject.Humanoid.MoveDirection == Zero
		and Subject.Humanoid.State == "Physics" and not Subject.Humanoid.EnabledStates.GettingUp,
		"Ragdoll suppresses movement, jumping, rotation and automatic recovery")
	local Late = Track()
	Subject.Animator.AnimationPlayed:Fire(Late)
	Check(Late.Stopped, "Late combat animations cannot restart during ragdoll")
	Subject.Humanoid.AutoRotate = true
	Check(not Subject.Humanoid.AutoRotate, "Camera rotation restoration cannot fight the ragdoll")
	Service.PrepareRecovery:Fire(Subject, 1)
	Check(#Service.RecoveryReady.Calls == 0,
		"Preparation arriving before its replicated recovery id waits for the correct session")
	local LinearVelocity, AngularVelocity = {}, {}
	Subject.PrimaryPart.CFrame = "updated-frame"
	Subject.PrimaryPart.AssemblyLinearVelocity = LinearVelocity
	Subject.PrimaryPart.AssemblyAngularVelocity = AngularVelocity
	Subject:SetRecoveryId(1)
	Check(#Service.RecoveryReady.Calls == 1 and Service.RecoveryReady.Calls[1][1] == Subject,
		"The owner confirms the matching recovery session")
	Check(Subject.PrimaryPart.CFrame == "updated-frame"
		and Subject.PrimaryPart.AssemblyLinearVelocity == LinearVelocity
		and Subject.PrimaryPart.AssemblyAngularVelocity == AngularVelocity,
		"Confirming recovery preserves the latest replicated pose and velocity")
	Subject:SetRagdoll(false)
	Check(not Subject.Animate.Enabled and Subject.Humanoid.State == "Physics", "Getting up waits for the ownership handoff to finish")
	Subject:SetRecoveryId(nil)
	Check(Subject.Animate.Enabled and Subject.Humanoid.AutoRotate and Subject.Humanoid.EnabledStates.GettingUp
		and Subject.Humanoid.State == "GettingUp", "Recovery restores the animation script, rotation and get-up state")
	local Resumed = Track()
	Subject.Animator.AnimationPlayed:Fire(Resumed)
	Check(not Resumed.Stopped, "Animations can play again after recovery")
	Subject:SetRagdoll(true)
	Player.CharacterRemoving:Fire(Subject)
	local Replacement = Character(false)
	Replacement.Attributes.Ragdoll = true
	Replacement.Humanoid.EnabledStates.GettingUp = false
	Player.Character = Replacement
	Player.CharacterAdded:Fire(Replacement)
	Check(Replacement.Humanoid.State == "Physics", "An already ragdolled replacement character initializes correctly")
	Replacement:SetRagdoll(false)
	Check(not Replacement.Animate.Enabled and not Replacement.Humanoid.EnabledStates.GettingUp,
		"Recovery preserves scripts and humanoid states that were already disabled")
	local OldTrack = Track()
	Subject.Animator.AnimationPlayed:Fire(OldTrack)
	Check(not OldTrack.Stopped, "Character removal disconnects the old animation blocker")
	Service.PrepareRecovery:Fire(Subject, 2)
	Check(#Service.RecoveryReady.Calls == 1, "The client ignores delayed preparation for a previous character")

	return string.format("Ragdoll controller: %d checks passed", Checks)
end
