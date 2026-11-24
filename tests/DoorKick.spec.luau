-- Runs against real Roblox parts in an isolated fixture, without starting gameplay.
return function(Sources: { [string]: string }): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Fixture = Instance.new("Folder")
	Fixture.Name = "DoorKickValidation"
	Fixture.Parent = workspace
	local Modules = Instance.new("Folder")
	Modules.Name = "DoorKickValidation_" .. game:GetService("HttpService"):GenerateGUID(false)
	Modules.Parent = ReplicatedStorage
	local Checks = 0
	local Now = 100
	local Nearby: { Model } = {}
	local Flings: { { Character: Model, Direction: Vector3, Impulse: number?, Ragdoll: boolean? } } = {}
	local DoorPushes: { { Door: Model, Velocity: Vector3, Duration: number } } = {}
	local TrackedDoors: { Model } = {}
	local Respawns: { () -> () } = {}
	local Base = Vector3.new(20000, 20000, 20000)
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Character(Position: Vector3): Model
		local Model = Instance.new("Model")
		local Root = Instance.new("Part")
		Root.Anchored = true
		Root.CanCollide = false
		Root.Size = Vector3.one
		Root.CFrame = CFrame.new(Base + Position)
		Root.Parent = Model
		Model.PrimaryPart = Root
		Model.Parent = Fixture
		return Model
	end

	local function Container(): Model
		local Model = Instance.new("Model")
		Model.Parent = Fixture
		Model:AddTag("Door")
		return Model
	end

	local function Panel(Parent: Model, Position: Vector3): Model
		local Model = Instance.new("Model")
		local Root = Instance.new("Part")
		Root.Size = Vector3.new(3, 6, 0.4)
		Root.CFrame = CFrame.new(Base + Position)
		Root.Anchored = true
		Root.Parent = Model
		local Trim = Instance.new("Part")
		Trim.Name = "Trim"
		Trim.Size = Vector3.new(0.2, 6, 0.4)
		Trim.CFrame = Root.CFrame * CFrame.new(1.4, 0, 0)
		Trim.Anchored = true
		Trim.Parent = Model
		Model.PrimaryPart = Root
		Model:SetAttribute("OpenOffset", CFrame.new(5, 0, 0))
		Model.Parent = Parent
		return Model
	end

	local Services = {
		DoorImpactService = {
			Track = function(_Self: any, Door: Model, _Attacker: Model)
				table.insert(TrackedDoors, Door)
			end,
		},
		HitboxService = {
			GetCharactersInCircleArea = function(): { Model }
				return Nearby
			end,
		},
		DamageService = {
			CanDamage = function(_Self: any, Subject: Model): boolean
				return not Subject:GetAttribute("ForceField") and not Subject:GetAttribute("Died")
			end,
		},
		KnockbackService = {
			Push = function(_Self: any, Door: Model, Velocity: Vector3, Duration: number)
				table.insert(DoorPushes, { Door = Door, Velocity = Velocity, Duration = Duration })
			end,
			FlingInDirection = function(
				_Self: any,
				Subject: Model,
				Direction: Vector3,
				ShouldRagdoll: boolean?,
				Impulse: number?
			)
				table.insert(
					Flings,
					{ Character = Subject, Direction = Direction, Impulse = Impulse, Ragdoll = ShouldRagdoll }
				)
				Subject:SetAttribute("Ragdoll", true)
			end,
		},
	}
	local Dependencies = {
		RealWorkspace = workspace,
		Task = {
			wait = task.wait,
			delay = function(Delay: number, Callback: () -> ()): thread?
				if Delay == 60 then
					table.insert(Respawns, Callback)
					return nil
				end
				return task.delay(Delay, Callback)
			end,
		},
		Knit = {
			CreateService = function(Service: any): any
				return Service
			end,
			CreateController = function(Controller: any): any
				return Controller
			end,
			CreateSignal = function(): any
				return { FireAll = function() end }
			end,
			GetService = function(Name: string): any
				return Services[Name]
			end,
		},
		Config = {
			BreakSound = "rbxassetid://103518062249191",
			BreakRadius = 8,
			KnockbackImpulse = 2.3,
			BreakImpulse = 1,
			BreakSpeed = 55,
			BreakUpSpeed = 8,
			BreakSpin = Vector3.new(2, 4, 1),
			DebrisLifetime = 8,
			RespawnDelay = 60,
			CollisionDelay = 0.2,
		},
		Workspace = {
			NPCs = workspace:FindFirstChild("NPCs"),
			GetServerTimeNow = function(): number
				return Now
			end,
			GetPartsInPart = function(_Self: any, Part: BasePart, Params: OverlapParams): { BasePart }
				return workspace:GetPartsInPart(Part, Params)
			end,
			GetPartBoundsInBox = function(
				_Self: any,
				Frame: CFrame,
				Size: Vector3,
				Params: OverlapParams
			): { BasePart }
				return workspace:GetPartBoundsInBox(Frame, Size, Params)
			end,
			Raycast = function(_Self: any, Origin: Vector3, Direction: Vector3, Params: RaycastParams): RaycastResult?
				return workspace:Raycast(Origin, Direction, Params)
			end,
		},
	}

	local function Load(Name: string, Source: string): any
		Source =
			Source:gsub("Container:IsDescendantOf%(workspace%)", "Container:IsDescendantOf(Dependencies.RealWorkspace)")
		Source =
			Source:gsub("local Knit = require%(ReplicatedStorage%.Packages%.Knit%)", "local Knit = Dependencies.Knit")
		Source = Source:gsub(
			"local Config = require%(ReplicatedStorage%.Shared%.DoorConfig%)",
			"local Config = Dependencies.Config"
		)
		local Module = Instance.new("ModuleScript")
		Module.Name = Name
		Module.Source = "return function(Dependencies)\nlocal workspace = Dependencies.Workspace\nlocal task = Dependencies.Task\n"
			.. Source
			.. "\nend"
		Module.Parent = Modules
		return require(ReplicatedStorage[Modules.Name][Name])(Dependencies)
	end

	local Success, Failure = pcall(function()
		local Service = Load("Service", Sources.Server)
		Service.KnitInit()
		local function KickDoor(Attacker: Model, Frame: CFrame, Size: Vector3, Affected: { [Model]: boolean })
			local Hitbox = Instance.new("Part")
			Hitbox.Name = "KickDoorHitbox"
			Hitbox.Anchored = true
			Hitbox.CanCollide = false
			Hitbox.CanQuery = false
			Hitbox.Transparency = 1
			Hitbox.Size = Size
			Hitbox.CFrame = Frame
			Hitbox.Parent = Fixture
			Service:BreakInHitbox(Attacker, Hitbox, Affected)
			Hitbox:Destroy()
		end
		local Attacker = Character(Vector3.zero)
		local Target = Character(Vector3.new(0, 0, -5))
		local Side = Character(Vector3.new(2, 0, -3))
		local Far = Character(Vector3.new(0, 0, -20))
		local Protected = Character(Vector3.new(-2, 0, -3))
		Protected:SetAttribute("ForceField", true)
		local Dodging = Character(Vector3.new(1, 0, -5))
		Dodging:SetAttribute("RollIFrame", true)
		Nearby = { Attacker, Target, Side, Far, Protected, Dodging, Target }
		local Holder = Container()
		local Door = Panel(Holder, Vector3.new(0, 0, -3))
		Door:SetAttribute("DoorClosedPivot", CFrame.new(0, 0, 0))
		local Frame = Instance.new("Part")
		Frame.Anchored = true
		Frame.CanCollide = false
		Frame.CFrame = Door.PrimaryPart.CFrame
		Frame.Parent = Holder
		local Hinge = Instance.new("WeldConstraint")
		Hinge.Part0 = Door.PrimaryPart
		Hinge.Part1 = Frame
		Hinge.Parent = Holder
		Service:BindDoor(Holder)
		Check(
			(Door:GetAttribute("DoorClosedPivot").Position - Door:GetPivot().Position).Magnitude < 0.01,
			"A copied door with stale pivot metadata registers at its actual position"
		)
		local Prompt = Holder:FindFirstChildWhichIsA("ProximityPrompt") :: ProximityPrompt
		local Affected = {}
		KickDoor(Attacker, CFrame.new(Base + Vector3.new(0, 0, -2.5)), Vector3.new(4, 5, 5), Affected)
		task.wait()
		Check(Door:GetAttribute("DoorBroken") == true, "A kick breaks the contacted panel")
		Check(
			not Door.PrimaryPart.Anchored and Door.PrimaryPart.AssemblyLinearVelocity.Z < -50,
			"The broken door is released toward the kick direction"
		)
		Check(not Prompt.Enabled and not Service:SetOpen(Door, true), "A broken door cannot be opened again")
		local Trim = Door:FindFirstChild("Trim") :: BasePart
		Check(
			not Trim.Anchored and #Door:QueryDescendants("WeldConstraint") > 0,
			"All door parts are released and kept together"
		)
		Check(
			Hinge.Parent == nil and Frame.Anchored,
			"Breaking removes a weld to the anchored frame without releasing the frame"
		)
		Check(
			#DoorPushes == 1 and DoorPushes[1].Door == Door and DoorPushes[1].Velocity.Z == -55,
			"The complete door panel receives a sustained launch after its assembly is rebuilt"
		)
		Check(
			#Flings == 0 and not Target:GetAttribute("Ragdoll") and not Side:GetAttribute("Ragdoll"),
			"Breaking a door no longer applies ragdoll merely by proximity"
		)
		Check(#TrackedDoors == 1 and TrackedDoors[1] == Door, "The broken panel starts moving-impact detection")
		Check(
			not Attacker:GetAttribute("Ragdoll")
				and not Far:GetAttribute("Ragdoll")
				and not Protected:GetAttribute("Ragdoll")
				and not Dodging:GetAttribute("Ragdoll"),
			"The kicker, distant characters, protected characters and dodge remain unaffected"
		)
		Check(
			not Service:BreakDoor(Door, Attacker, Vector3.new(0, 0, -1), Affected),
			"Repeated contact cannot break a door twice"
		)

		Nearby = {}
		local BlockedHolder = Container()
		local BlockedDoor = Panel(BlockedHolder, Vector3.new(20, 0, -3))
		Service:BindDoor(BlockedHolder)
		local OtherAttacker = Character(Vector3.new(20, 0, 0))
		local Wall = Instance.new("Part")
		Wall.Anchored = true
		Wall.Size = Vector3.new(4, 10, 0.3)
		Wall.CFrame = CFrame.new(Base + Vector3.new(20, 0, -1.5))
		Wall.Parent = Fixture
		KickDoor(OtherAttacker, CFrame.new(Base + Vector3.new(20, 0, -2.5)), Vector3.new(4, 5, 5), {})
		Check(not BlockedDoor:GetAttribute("DoorBroken"), "Kicks cannot break doors through a wall")
		Wall:Destroy()

		local MovingHolder = Container()
		local MovingDoor = Panel(MovingHolder, Vector3.new(40, 0, -3))
		Service:BindDoor(MovingHolder)
		Check(Service:SetOpen(MovingDoor, true), "The test opens a sliding panel")
		Check(
			not Service:BreakDoor(MovingDoor, OtherAttacker, -Vector3.zAxis, {}),
			"A panel cannot break once opening has started"
		)
		Now += 1
		MovingDoor:SetAttribute("Opening", false)
		OtherAttacker:PivotTo(CFrame.new(Base + Vector3.new(40, 0, 0)))
		KickDoor(OtherAttacker, CFrame.new(Base + Vector3.new(40, 0, -2.5)), Vector3.new(4, 5, 5), {})
		Check(not MovingDoor:GetAttribute("DoorBroken"), "An opened panel is not hit at its old server position")
		OtherAttacker:PivotTo(CFrame.new(Base + Vector3.new(45, 0, 0)))
		KickDoor(OtherAttacker, CFrame.new(Base + Vector3.new(45, 0, -2.5)), Vector3.new(4, 5, 5), {})
		Check(
			not MovingDoor:GetAttribute("DoorBroken") and MovingDoor.PrimaryPart.Anchored,
			"An opened panel remains intact even when kicked at its rendered position"
		)
		Check(#Respawns == 1 and #TrackedDoors == 1, "Kicking an open door starts no debris, impact or respawn work")
		Check(Service:SetOpen(MovingDoor, false), "The test closes the panel again")
		Now += 1
		MovingDoor:SetAttribute("Opening", false)
		OtherAttacker:PivotTo(CFrame.new(Base + Vector3.new(40, 0, 0)))
		KickDoor(OtherAttacker, CFrame.new(Base + Vector3.new(40, 0, -2.5)), Vector3.new(4, 5, 5), {})
		Check(MovingDoor:GetAttribute("DoorBroken") == true, "The same panel can be kicked apart after closing")

		local WindowHolder = Container()
		WindowHolder:RemoveTag("Door")
		WindowHolder:AddTag("Windows")
		local Window = Panel(WindowHolder, Vector3.new(60, 0, -3))
		Service:BindDoor(WindowHolder)
		OtherAttacker:PivotTo(CFrame.new(Base + Vector3.new(60, 0, 0)))
		KickDoor(OtherAttacker, CFrame.new(Base + Vector3.new(60, 0, -2.5)), Vector3.new(4, 5, 5), {})
		Check(not Window:GetAttribute("DoorBroken"), "Door kicks do not break windows")

		local DoubleHolder = Container()
		local First = Panel(DoubleHolder, Vector3.new(80, 0, -3))
		local Second = Panel(DoubleHolder, Vector3.new(84, 0, -3))
		Service:BindDoor(DoubleHolder)
		local DoublePrompt = DoubleHolder:FindFirstChildWhichIsA("ProximityPrompt") :: ProximityPrompt
		Target:PivotTo(CFrame.new(Base + Vector3.new(82, 0, -5)))
		Nearby = { Target }
		local BeforeFlings = #Flings
		local DoubleAffected = {}
		Check(
			Service:BreakDoor(First, OtherAttacker, Vector3.new(0, 0, -1), DoubleAffected),
			"The first double-door panel breaks"
		)
		Check(DoublePrompt.Enabled, "The remaining panel keeps its interaction prompt")
		Check(
			Service:BreakDoor(Second, OtherAttacker, Vector3.new(0, 0, -1), DoubleAffected),
			"The second double-door panel breaks"
		)
		Check(not DoublePrompt.Enabled, "Breaking every panel disables the interaction prompt")
		Check(#Flings == BeforeFlings, "A double-door break also waits for actual impacts")
		Nearby = {}

		local ReverseHolder = Container()
		Dependencies.Config.BreakImpulse = 2
		local ReverseDoor = Panel(ReverseHolder, Vector3.new(120, 0, -3))
		Service:BindDoor(ReverseHolder)
		local ReversePosition = Base + Vector3.new(120, 0, -6)
		OtherAttacker:PivotTo(CFrame.lookAt(ReversePosition, ReversePosition + Vector3.zAxis))
		KickDoor(OtherAttacker, CFrame.new(Base + Vector3.new(120, 0, -3.5)), Vector3.new(4, 5, 5), {})
		Check(
			ReverseDoor:GetAttribute("DoorBroken")
				and ReverseDoor.PrimaryPart.AssemblyLinearVelocity.Z == 110
				and ReverseDoor.PrimaryPart.AssemblyLinearVelocity.Y == 16,
			"BreakImpulse doubles the door panel's launch independently of the nearby-character impulse"
		)
		Check(DoorPushes[#DoorPushes].Velocity.Z == 110, "The sustained launch also uses the door impulse multiplier")
		Dependencies.Config.BreakImpulse = 1

		Check(#Respawns == 5, "Each broken panel schedules exactly one respawn after 60 seconds")
		Respawns[1]()
		local Restored: Model? = nil
		for _, Child in Holder:GetChildren() do
			if Child:IsA("Model") and Child ~= Door then
				Restored = Child
			end
		end
		Check(Restored ~= nil and Restored.PrimaryPart.Anchored, "The entire intact panel returns anchored")
		local RestoredPanel = Restored :: Model
		Check(Prompt.Enabled and Service:SetOpen(RestoredPanel, true), "The returned panel re-enables interaction")
		RestoredPanel:SetAttribute("Opening", false)
		Check(Service:SetOpen(Restored :: Model, false), "The restored panel can close after opening")
		Respawns[2]()
		local RestoredMoving: Model? = nil
		for _, Child in MovingHolder:GetChildren() do
			if Child:IsA("Model") and Child ~= MovingDoor then
				RestoredMoving = Child
			end
		end
		Check(
			RestoredMoving ~= nil and math.abs(RestoredMoving:GetPivot().Position.X - (Base.X + 40)) < 0.01,
			"A panel opened and closed before breaking returns at its original closed position"
		)
		Check(Service:BreakDoor(Restored :: Model, Attacker, -Vector3.zAxis, {}), "A restored door can be broken again")
		Check(#Respawns == 6, "Breaking the restored door starts a fresh timer")
		DoubleHolder:Destroy()
		Respawns[3]()
		Respawns[4]()
		Check(DoubleHolder.Parent == nil, "Removed containers are not recreated by pending timers")

		local Controller = Load("Controller", Sources.Client)
		local UnregisteredHolder = Container()
		local UnregisteredDoor = Panel(UnregisteredHolder, Vector3.new(140, 0, -3))
		OtherAttacker:PivotTo(CFrame.new(Base + Vector3.new(140, 0, 0)))
		Check(
			not UnregisteredDoor:HasTag("HitboxDetectable")
				and not UnregisteredDoor:HasTag("DoorPanel")
				and not UnregisteredDoor:FindFirstChildWhichIsA("Humanoid"),
			"Door contact fixture has no humanoid, character hitbox tag or prior panel registration"
		)
		KickDoor(OtherAttacker, CFrame.new(Base + Vector3.new(140, 0, -3)), Vector3.new(5, 5, 6), {})
		Check(
			UnregisteredDoor:GetAttribute("DoorBroken") == true,
			"The physical door hitbox detects and breaks an unregistered door directly from scenery parts"
		)

		local ClientHolder = Container()
		local ClientDoor = Panel(ClientHolder, Vector3.new(100, 0, -3))
		Service:BindDoor(ClientHolder)
		local Record = Controller:BindDoor(ClientDoor)
		local Cancelled = false
		Record.Tween = {
			Cancel = function()
				Cancelled = true
			end,
		}
		ClientDoor:SetAttribute("DoorBroken", true)
		task.wait()
		Check(
			Cancelled and not Record.StateConnection.Connected and not Record.BrokenConnection.Connected,
			"Breaking cancels the client opening tween and releases its observers"
		)
		Check(Controller:BindDoor(ClientDoor) == nil, "A broken panel cannot restart client animation")
		Controller:PlayBreakEffect(ClientDoor)
		local Sound = ClientDoor.PrimaryPart:FindFirstChild("DoorBreakSound") :: Sound
		Check(
			Sound and Sound.SoundId == "rbxassetid://103518062249191",
			"Breaking plays the requested sound on the detached panel"
		)
	end)

	Fixture:Destroy()
	Modules:Destroy()
	assert(Success, Failure)
	return "DoorKick: " .. Checks .. " checks passed"
end
