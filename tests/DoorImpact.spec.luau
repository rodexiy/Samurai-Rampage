return function(Source: string): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Fixture = Instance.new("Folder")
	Fixture.Name = "DoorImpactValidation"
	Fixture.Parent = workspace
	local Module = Instance.new("ModuleScript")
	Module.Name = "DoorImpactValidation_" .. game:GetService("HttpService"):GenerateGUID(false)
	local Targets: { Model } = {}
	local Doors: { Model } = {}
	local Hits: { { Character: Model, Velocity: Vector3 } } = {}
	local Checks, Connections = 0, 0
	local Offset = 0
	local Base = Vector3.new(20000, 20000, 20000)
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Signal(): any
		return {
			Connect = function(_Self: any, _Callback: any): any
				Connections += 1
				local Connected = true
				return {
					Disconnect = function()
						if Connected then
							Connected = false
							Connections -= 1
						end
					end,
				}
			end,
		}
	end

	local Dependencies = {
		Collection = {
			GetTagged = function(): { Model }
				return Targets
			end,
		},
		Run = { PreSimulation = Signal(), PostSimulation = Signal() },
		Config = {
			KnockbackImpulse = 1.4,
			ImpactMinSpeed = 15,
			ImpactMaxKnockbackSpeed = 120,
			ImpactStopSpeed = 2,
			ImpactStopDelay = 0.25,
			ImpactRotationStep = 10,
			ImpactMaxSubsteps = 12,
			DebrisLifetime = 8,
		},
		Knit = {
			CreateService = function(Value: any): any
				return Value
			end,
			GetService = function(Name: string): any
				if Name == "DamageService" then
					return {
						CanDamage = function(_Self: any, Character: Model): boolean
							return not Character:GetAttribute("ForceField") and not Character:GetAttribute("Died")
						end,
					}
				end
				return {
					FlingWithVelocity = function(_Self: any, Character: Model, Velocity: Vector3)
						table.insert(Hits, { Character = Character, Velocity = Velocity })
						Character:SetAttribute("Ragdoll", true)
					end,
				}
			end,
		},
	}
	Source = Source:gsub(
		'local CollectionService = game:GetService%("CollectionService"%)',
		"local CollectionService = Dependencies.Collection"
	)
	Source = Source:gsub('local RunService = game:GetService%("RunService"%)', "local RunService = Dependencies.Run")
	Source = Source:gsub("local Knit = require%(ReplicatedStorage%.Packages%.Knit%)", "local Knit = Dependencies.Knit")
	Source = Source:gsub(
		"local Config = require%(ReplicatedStorage%.Shared%.DoorConfig%)",
		"local Config = Dependencies.Config"
	)
	Module.Source = "return function(Dependencies)\n" .. Source .. "\nend"
	Module.Parent = ReplicatedStorage
	local Service = require(ReplicatedStorage[Module.Name])(Dependencies)
	Service.KnitInit()

	local function Character(Position: Vector3): Model
		local Model = Instance.new("Model")
		local Root = Instance.new("Part")
		Root.Name = "HumanoidRootPart"
		Root.Size = Vector3.new(1, 4, 1)
		Root.CFrame = CFrame.new(Base + Vector3.new(Offset, 0, 0) + Position)
		Root.CanCollide = false
		Root.Parent = Model
		local Humanoid = Instance.new("Humanoid")
		Humanoid.RequiresNeck = false
		Humanoid.Parent = Model
		Model.PrimaryPart = Root
		Model.Parent = Fixture
		table.insert(Targets, Model)
		return Model
	end

	local function NewCase(): Model
		for _, Door in Doors do
			Service:Stop(Door)
		end
		table.clear(Doors)
		table.clear(Targets)
		table.clear(Hits)
		Offset += 100
		return Character(Vector3.new(0, 0, 4))
	end

	local function Door(Attacker: Model, Velocity: Vector3, Angular: Vector3?): Model
		local Model = Instance.new("Model")
		local Root = Instance.new("Part")
		Root.Size = Vector3.new(6, 6, 0.4)
		Root.CFrame = CFrame.new(Base + Vector3.new(Offset, 0, 0))
		Root.RootPriority = 127
		Root.CanCollide = false
		Root.Parent = Model
		Model.PrimaryPart = Root
		Model.Parent = Fixture
		Root.AssemblyLinearVelocity = Velocity
		Root.AssemblyAngularVelocity = Angular or Vector3.zero
		Service:Track(Model, Attacker)
		table.insert(Doors, Model)
		return Model
	end

	local function Move(Model: Model, Position: Vector3, Rotation: number?)
		Model:PivotTo(CFrame.new(Base + Vector3.new(Offset, 0, 0) + Position) * CFrame.Angles(0, Rotation or 0, 0))
	end

	local Success, Failure = pcall(function()
		local Attacker = NewCase()
		local Target = Character(Vector3.new(0, 0, -3))
		local Side = Character(Vector3.new(4.5, 0, -3))
		local MovingDoor = Door(Attacker, Vector3.new(0, 0, -35))
		local Hitbox = MovingDoor:FindFirstChild("DoorImpactHitbox") :: BasePart
		Check(
			Hitbox ~= nil and Hitbox.Massless and not Hitbox.CanCollide,
			"The door has a welded hitbox matching its physical panel"
		)
		Check((Hitbox.Size - Vector3.new(6, 6, 0.4)).Magnitude < 0.01, "Door hitbox copies panel dimensions")
		Service:CaptureMotion()
		Move(MovingDoor, Vector3.new(0, 0, -5))
		Service:Step(0.1)
		Check(#Hits == 1 and Hits[1].Character == Target, "Only the character in the door's path is hit")
		Check(not Side:GetAttribute("Ragdoll"), "Being near the door is no longer sufficient for ragdoll")
		Check(math.abs(Hits[1].Velocity.Z + 49) < 0.01, "Impact speed controls transferred velocity")
		Service:CaptureMotion()
		Move(MovingDoor, Vector3.new(0, 0, -2))
		Service:Step(0.1)
		Check(#Hits == 1, "A door cannot hit the same character twice")

		Attacker = NewCase()
		Target = Character(Vector3.new(0, 0, -3))
		MovingDoor = Door(Attacker, Vector3.new(0, 0, -5))
		Service:CaptureMotion()
		Move(MovingDoor, Vector3.new(0, 0, -5))
		Service:Step(0.1)
		Check(#Hits == 0, "Slow impacts do not ragdoll")

		Attacker = NewCase()
		Target = Character(Vector3.new(0, 0, -0.5))
		Target.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, 50)
		MovingDoor = Door(Attacker, Vector3.zero)
		Service:CaptureMotion()
		Service:Step(0.01)
		Check(#Hits == 0, "Running into an already stationary door does not trigger its projectile impact")

		Attacker = NewCase()
		Target = Character(Vector3.new(0, 0, -3))
		Target.PrimaryPart.AssemblyLinearVelocity = Vector3.new(0, 0, -35)
		MovingDoor = Door(Attacker, Vector3.new(0, 0, -35))
		Service:CaptureMotion()
		Move(MovingDoor, Vector3.new(0, 0, -5))
		Service:Step(0.1)
		Check(#Hits == 0, "Matching player and door velocities do not count as a strong impact")

		Attacker = NewCase()
		Target = Character(Vector3.new(0, 0, -15))
		MovingDoor = Door(Attacker, Vector3.new(0, 0, -300))
		Service:CaptureMotion()
		Move(MovingDoor, Vector3.new(0, 0, -30))
		MovingDoor.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
		Service:Step(0.1)
		Check(#Hits == 1 and Hits[1].Character == Target, "The sweep detects a target crossed between frames")
		Check(
			math.abs(Hits[1].Velocity.Magnitude - 120) < 0.01,
			"Pre-collision speed is retained and the knockback cap is respected"
		)

		Attacker = NewCase()
		Target = Character(Vector3.new(2.8, 0, -1))
		MovingDoor = Door(Attacker, Vector3.zero, Vector3.new(0, 8, 0))
		Service:CaptureMotion()
		Move(MovingDoor, Vector3.zero, 0.5)
		Service:Step(0.0625)
		Check(
			#Hits == 1 and Hits[1].Character == Target,
			"Rotation can strike a player even when the door center does not move"
		)
		Check(
			Hits[1].Velocity.Z < 0 and Hits[1].Velocity.Magnitude >= 15,
			"Rotational point velocity determines the impact direction and strength"
		)

		Attacker = NewCase()
		Target = Character(Vector3.new(0, 0, -3))
		Target:SetAttribute("ForceField", true)
		local Dodging = Character(Vector3.new(0, 0, -5))
		Dodging:SetAttribute("RollIFrame", true)
		MovingDoor = Door(Attacker, Vector3.new(0, 0, -35))
		Service:CaptureMotion()
		Move(MovingDoor, Vector3.new(0, 0, -7))
		Service:Step(0.1)
		Check(#Hits == 0, "Protected characters, dodge frames and the kicker remain immune")

		Attacker = NewCase()
		Target = Character(Vector3.new(0, 0, -3))
		MovingDoor = Door(Attacker, Vector3.new(0, 0, -35))
		local Wall = Instance.new("Part")
		Wall.Anchored = true
		Wall.Size = Vector3.new(8, 8, 0.3)
		Wall.CFrame = CFrame.new(Base + Vector3.new(Offset, 0, -1.5))
		Wall.Parent = Fixture
		Service:CaptureMotion()
		Move(MovingDoor, Vector3.new(0, 0, -5))
		Service:Step(0.1)
		Check(#Hits == 0, "A wall blocks swept impacts")

		Attacker = NewCase()
		MovingDoor = Door(Attacker, Vector3.zero)
		Hitbox = MovingDoor:FindFirstChild("DoorImpactHitbox") :: BasePart
		Service:CaptureMotion()
		Service:Step(0.3)
		Check(
			Hitbox.Parent == nil and Connections == 0,
			"A stationary door stops detection and releases shared connections"
		)

		Attacker = NewCase()
		MovingDoor = Door(Attacker, Vector3.new(0, 0, -35))
		local OtherDoor = Door(Attacker, Vector3.new(0, 0, -35))
		Check(Connections == 2, "Multiple moving doors share one connection per physics phase")
		Service:CaptureMotion()
		Service:Step(9)
		Check(
			not MovingDoor:FindFirstChild("DoorImpactHitbox")
				and not OtherDoor:FindFirstChild("DoorImpactHitbox")
				and Connections == 0,
			"Lifetime expiration removes every sensor and shared connection"
		)
	end)

	for _, Model in Doors do
		Service:Stop(Model)
	end
	Fixture:Destroy()
	Module:Destroy()
	assert(Success, Failure)
	return "DoorImpact: " .. Checks .. " checks passed"
end
