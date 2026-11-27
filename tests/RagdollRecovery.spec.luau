return function(Source: string, Config: any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Connection: any
	local Callback: ((number) -> ())?
	local Jobs = {}
	local Now = 0
	local World = {}
	local Signal = {}
	function Signal:Connect(Handler: (number) -> ()): any
		Check(Connection == nil or not Connection.Connected, "Recovery uses only one simulation connection")
		Connection = { Connected = true }
		function Connection.Disconnect(Current: any)
			Current.Connected = false
		end
		Callback = Handler
		return Connection
	end
	local function Step(DeltaTime: number)
		if Connection and Connection.Connected and Callback then
			Callback(DeltaTime)
		end
	end
	local function Character(): any
		local Subject = {
			InWorld = true,
			Attributes = { Ragdoll = true },
			Humanoid = { Health = 100, ChangeState = function() end },
			PrimaryPart = { CFrame = "server-frame", AssemblyLinearVelocity = { Magnitude = 0 }, AssemblyAngularVelocity = { Magnitude = 0 } },
			Motors = { { Enabled = false, Transform = "animated" } },
		}
		Subject.Parts = { Subject.PrimaryPart }
		function Subject.PrimaryPart:CanSetNetworkOwnership(): boolean
			return true
		end
		function Subject.PrimaryPart:SetNetworkOwner(Owner: any)
			Check(Owner == nil or Subject.Motors[1].Enabled, "Player ownership is granted only after motors are restored")
			self.Owner = Owner
		end
		function Subject:SetAttribute(Name: string, Value: any)
			self.Attributes[Name] = Value
		end
		function Subject:IsA(Class: string): boolean
			return Class == "Model"
		end
		function Subject:IsDescendantOf(Ancestor: any): boolean
			return self.InWorld and Ancestor == World
		end
		function Subject:GetAttribute(Name: string): any
			return self.Attributes[Name]
		end
		function Subject:FindFirstChildWhichIsA(Class: string): any
			return if Class == "Humanoid" then self.Humanoid else nil
		end
		function Subject:QueryDescendants(Selector: string): { any }
			if Selector == "BasePart" then
				return self.Parts
			elseif Selector == "Motor6D" then
				return self.Motors
			end
			return self.Joints or {}
		end
		return Subject
	end
	local Library = {}
	function Library:Ragdoll(Subject: any, _Impulse: number?, _Direction: any, Duration: number?)
		Check(Duration == nil, "The legacy timer cannot bypass recovery validation")
		Subject.Attributes.Ragdoll = true
	end
	function Library:Unragdoll(_Subject: any)
		error("The legacy recovery returns ownership before rebuilding the rig")
	end
	local function Remote(): any
		local Event = { Calls = {} }
		function Event:Fire(...: any)
			table.insert(self.Calls, { ... })
			if self.Callback then
				self.Callback(...)
			end
		end
		function Event:Connect(Handler: (...any) -> ())
			self.Callback = Handler
		end
		return Event
	end
	local Knit = { CreateSignal = Remote, CreateService = function(Definition: any): any
		return Definition
	end }
	local Storage = { Packages = { Knit = Knit }, Shared = { RagdollConfig = Config }, Assets = { Libraries = { Ragdoll = Library } } }
	local Environment = setmetatable({
		workspace = World,
		CFrame = { identity = "identity" },
		Enum = { HumanoidStateType = { GettingUp = "GettingUp" } },
		os = { clock = function(): number
			return Now
		end },
		typeof = function(Value: any): string
			return if type(Value) == "table" and Value.IsA then "Instance" else type(Value)
		end,
		Vector3 = { new = function(X: number, Y: number, Z: number): any
			return { X = X, Y = Y, Z = Z }
		end, zero = { Magnitude = 0 } },
		game = { GetService = function(_Self: any, Name: string): any
			if Name == "ReplicatedStorage" then
				return Storage
			elseif Name == "Players" then
				return { GetPlayerFromCharacter = function(_Players: any, Subject: any): any
					return Subject.Player
				end }
			end
			return {
				PostSimulation = Signal,
				PreSimulation = { Once = function(): any
					return { Disconnect = function() end }
				end },
			}
		end },
		require = function(Value: any): any
			return Value
		end,
		task = {
			delay = function(Duration: number, Handler: () -> ()): any
				local Job = { Duration = Duration, Handler = Handler, Cancelled = false }
				table.insert(Jobs, Job)
				return Job
			end,
			cancel = function(Job: any)
				Job.Cancelled = true
			end,
		},
	}, { __index = getfenv() })
	local Load = assert(loadstring(Source))
	setfenv(Load, Environment)
	local Service = Load()
	Service.KnitStart()
	local Subject = Character()
	local RightHip = { MaxFrictionTorque = 0, Attachment0 = { Name = "RightLegAttachment" },
		Attachment1 = { Name = "TorsoRightLegAttachment", Position = { X = -0.5, Y = -1, Z = 0 } },
		GetAttribute = function(): boolean
			return true
		end }
	local LeftHip = { MaxFrictionTorque = 0, Attachment0 = { Name = "LeftLegAttachment" },
		Attachment1 = { Name = "TorsoLeftLegAttachment", Position = { X = 0.5, Y = -1, Z = 0 } },
		GetAttribute = function(): boolean
			return true
		end }
	local OtherJoint = { MaxFrictionTorque = 1, GetAttribute = function(): boolean
		return false
	end }
	function RightHip:Destroy()
		self.Destroyed = true
	end
	function LeftHip:Destroy()
		self.Destroyed = true
	end
	Subject.Joints = { RightHip, LeftHip, OtherJoint }
	Service:Ragdoll(Subject, 0, nil, 1)
	Check(RightHip.Attachment1.Position.X == 0.5 and LeftHip.Attachment1.Position.X == -0.5,
		"Each leg attaches to its own side of the torso without crossed constraints")
	Check(RightHip.MaxFrictionTorque == Config.JointFrictionTorque and LeftHip.MaxFrictionTorque == Config.JointFrictionTorque
		and OtherJoint.MaxFrictionTorque == 1, "Only ragdoll joints receive friction to settle their movement")
	Check(Jobs[1].Duration == 1 and Connection == nil, "Timed ragdoll preserves its minimum duration")
	Jobs[1].Handler()
	Subject.PrimaryPart.AssemblyLinearVelocity = { Magnitude = Config.RecoveryMaxSpeed + 1 }
	Step(1)
	Check(Subject:GetAttribute("Ragdoll"), "A moving or falling body stays ragdolled after the timer")
	Subject.PrimaryPart.AssemblyLinearVelocity = { Magnitude = 0 }
	Subject.PrimaryPart.AssemblyAngularVelocity = { Magnitude = Config.RecoveryMaxAngularSpeed + 1 }
	Step(1)
	Check(Subject:GetAttribute("Ragdoll"), "A spinning body cannot recover even when translation is slow")
	Subject.PrimaryPart.AssemblyAngularVelocity = { Magnitude = 0 }
	Step(Config.RecoveryStableTime / 2)
	Check(Subject:GetAttribute("Ragdoll"), "A brief pause does not trigger recovery")
	Subject.PrimaryPart.AssemblyLinearVelocity = { Magnitude = Config.RecoveryMaxSpeed + 1 }
	Step(0.1)
	Subject.PrimaryPart.AssemblyLinearVelocity = { Magnitude = Config.RecoveryMaxSpeed }
	Step(Config.RecoveryStableTime / 2)
	Check(Subject:GetAttribute("Ragdoll"), "New movement resets the stability interval")
	Service:Unragdoll(Subject)
	Step(Config.RecoveryStableTime / 2)
	Step(0)
	Check(not Subject:GetAttribute("Ragdoll"), "Repeated requests preserve progress and slow bodies recover")
	Check(RightHip.Destroyed and LeftHip.Destroyed and Subject.Motors[1].Transform == "identity",
		"Recovery removes physical constraints and resets animation transforms before handing off")
	Check(not Connection.Connected, "Monitoring stops after the last recovery")

	Subject = Character()
	Service:Ragdoll(Subject, nil, nil, 1)
	local OldJob = Jobs[#Jobs]
	Service:Ragdoll(Subject)
	Check(OldJob.Cancelled, "A new ragdoll cancels a stale recovery timer")
	Service:Unragdoll(Subject)
	Step(Config.RecoveryStableTime / 2)
	Service:Ragdoll(Subject)
	Step(1)
	Check(Subject:GetAttribute("Ragdoll") and not Connection.Connected, "A new knockdown cancels pending recovery")
	Service:Unragdoll(Subject)
	Step(Config.RecoveryStableTime)
	Step(0)
	Check(not Subject:GetAttribute("Ragdoll"), "Manual recovery uses the same motion check")

	for _, Attribute in { "Downed", "Carried", "Died" } do
		Subject = Character()
		Service:Unragdoll(Subject)
		Subject.Attributes[Attribute] = true
		Step(1)
		Check(Subject:GetAttribute("Ragdoll") and not Connection.Connected, Attribute .. " cancels pending recovery")
	end
	for _, Case in { "Removed", "DeadHumanoid", "MissingRoot", "AlreadyRecovered" } do
		Subject = Character()
		Service:Unragdoll(Subject)
		if Case == "Removed" then
			Subject.InWorld = false
		elseif Case == "DeadHumanoid" then
			Subject.Humanoid.Health = 0
		elseif Case == "MissingRoot" then
			Subject.PrimaryPart = nil
		else
			Subject.Attributes.Ragdoll = false
		end
		Step(1)
		Check(not Connection.Connected, Case .. " removes its pending simulation work")
	end

	local Slow, Fast = Character(), Character()
	Fast.PrimaryPart.AssemblyLinearVelocity = { Magnitude = Config.RecoveryMaxSpeed + 1 }
	Service:Unragdoll(Slow)
	Service:Unragdoll(Fast)
	Step(Config.RecoveryStableTime)
	Step(0)
	Check(not Slow:GetAttribute("Ragdoll") and Fast:GetAttribute("Ragdoll") and Connection.Connected,
		"Multiple characters recover independently on one connection")
	Fast.PrimaryPart.AssemblyLinearVelocity = { Magnitude = 0 }
	Step(Config.RecoveryStableTime)
	Step(0)
	Check(not Fast:GetAttribute("Ragdoll") and not Connection.Connected, "The final character stops monitoring")

	Subject = Character()
	local Owner = { Character = Subject }
	Subject.Player = Owner
	Service:Unragdoll(Subject)
	Step(Config.RecoveryStableTime)
	local Id = Subject:GetAttribute("RagdollRecoveryId")
	Check(Subject:GetAttribute("Ragdoll") and Subject.Motors[1].Enabled and Subject.PrimaryPart.Owner == nil,
		"Rebuilt player rigs remain server-owned and in Physics until synchronized")
	Service.Client.RecoveryReady:Fire(Owner, Subject, Id)
	Check(Subject.PrimaryPart.Owner == nil, "Acknowledgements before preparation are rejected")
	Step(0)
	local Packet = Service.Client.PrepareRecovery.Calls[#Service.Client.PrepareRecovery.Calls]
	Check(Packet[1] == Owner and Packet[2] == Subject and Packet[3] == Id and Packet[4] == nil,
		"The owner receives preparation after a full simulation step without a stale pose to apply")
	Service.Client.RecoveryReady:Fire({ Character = Subject }, Subject, Id)
	Service.Client.RecoveryReady:Fire(Owner, Subject, Id + 1)
	Check(Subject:GetAttribute("Ragdoll") and Subject.PrimaryPart.Owner == nil, "Forged and stale confirmations cannot claim ownership")
	local RecoveryVelocity = { Magnitude = 2 }
	local RecoveryAngularVelocity = { Magnitude = 1 }
	Subject.PrimaryPart.CFrame = "moved-during-handoff"
	Subject.PrimaryPart.AssemblyLinearVelocity = RecoveryVelocity
	Subject.PrimaryPart.AssemblyAngularVelocity = RecoveryAngularVelocity
	Service.Client.RecoveryReady:Fire(Owner, Subject, Id)
	Check(Subject.PrimaryPart.Owner == Owner and not Subject:GetAttribute("Ragdoll")
		and Subject:GetAttribute("RagdollRecoveryId") == nil and not Connection.Connected,
		"A valid confirmation returns ownership and then releases getting up")
	Check(Subject.PrimaryPart.CFrame == "moved-during-handoff"
		and Subject.PrimaryPart.AssemblyLinearVelocity == RecoveryVelocity
		and Subject.PrimaryPart.AssemblyAngularVelocity == RecoveryAngularVelocity,
		"Ownership transfer preserves movement during a delayed confirmation")

	Service:Ragdoll(Subject)
	Service:Unragdoll(Subject)
	Step(Config.RecoveryStableTime)
	Step(0)
	Id = Subject:GetAttribute("RagdollRecoveryId")
	Service:Ragdoll(Subject)
	Service.Client.RecoveryReady:Fire(Owner, Subject, Id)
	Check(Subject:GetAttribute("Ragdoll") and Subject.PrimaryPart.Owner == nil,
		"A new knockdown invalidates an in-flight ownership handoff")
	Service:Unragdoll(Subject)
	Step(Config.RecoveryStableTime)
	Step(0)
	Now += Config.RecoverySyncTimeout
	Step(0)
	Check(not Subject:GetAttribute("Ragdoll") and Subject.PrimaryPart.Owner == Owner,
		"An unresponsive client cannot leave recovery permanently stuck")
	Service:Ragdoll(Subject)
	Service:Unragdoll(Subject)
	Step(Config.RecoveryStableTime)
	Step(0)
	Id = Subject:GetAttribute("RagdollRecoveryId")
	Subject.Attributes.Downed = true
	Step(0)
	Service.Client.RecoveryReady:Fire(Owner, Subject, Id)
	Check(Subject:GetAttribute("Ragdoll") and Subject:GetAttribute("RagdollRecoveryId") == nil
		and Subject.PrimaryPart.Owner == nil, "Being downed during a handoff returns to ragdoll instead of granting stale ownership")

	return string.format("Ragdoll recovery: %d checks passed", Checks)
end
