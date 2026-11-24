-- Run on the server in a playtest; restores the player after testing a real impact.
return function(Player: Player): { [string]: any }
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Knit = require(ReplicatedStorage.Packages.Knit)
	local MobService = Knit.GetService("MobService")
	local AIService = Knit.GetService("AIService")
	local DoorService = Knit.GetService("DoorService")
	local RagdollService = Knit.GetService("RagdollService")
	local CharacterService = Knit.GetService("CharacterService")
	local Character = assert(Player.Character, "A player character must be loaded")
	local Root = assert(Character.PrimaryPart, "Player root must be loaded")
	local OriginalPivot = Character:GetPivot()
	local OriginalOwner = Root:GetNetworkOwner()
	local HadForceField = Character:GetAttribute("ForceField") == true
	local Models: { Model } = {}
	local Connections: { RBXScriptConnection } = {}
	local Checks = 0
	local Results = {}
	local Fixture = Instance.new("Folder")
	Fixture.Name = "DoorImpactPhysicsValidation"
	Fixture.Parent = workspace
	local Platform = Instance.new("Part")
	Platform.Size = Vector3.new(200, 1, 200)
	Platform.CFrame = CFrame.new(20000, 10000, 20000)
	Platform.Anchored = true
	Platform.Parent = Fixture
	local Origin = Platform.CFrame * CFrame.new(0, 4, 0)

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Spawn(Offset: Vector3): Model
		local Dummy = assert(MobService:SpawnMob("Dummy", Origin * CFrame.new(Offset), "Dummy"), "Dummy must spawn")
		table.insert(Models, Dummy)
		AIService:AddAI(Dummy, "Dummy", "Dummy")
		return Dummy
	end

	local Success, Failure = pcall(function()
		-- Spawn protection intentionally ignores door impacts; disable it only for this trial.
		if HadForceField then
			CharacterService:EnableForceField(Character, false)
		end
		local Attacker = Spawn(Vector3.new(0, 0, 4))
		local Side = Spawn(Vector3.new(6, 0, -3))
		local Target = Spawn(Vector3.new(0, 0, -7))
		local Template: Model? = nil
		for _, Model in workspace.SlidingDoor:GetChildren() do
			if Model:IsA("Model") and Model:GetAttribute("OpenOffset") then
				Template = Model
				break
			end
		end
		assert(Template, "The map must contain a sliding door panel")

		local function Trial(Label: string, Victim: Model)
			Victim:PivotTo(Origin * CFrame.new(0, 0, -7))
			for _, Part: BasePart in Victim:QueryDescendants("BasePart") do
				Part.AssemblyLinearVelocity = Vector3.zero
				Part.AssemblyAngularVelocity = Vector3.zero
			end
			task.wait(0.3)
			local Holder = Instance.new("Model")
			local Door = (Template :: Model):Clone()
			Door:SetAttribute("DoorClosedPivot", nil)
			Door:SetAttribute("DoorMotion", nil)
			Door:SetAttribute("DoorBroken", nil)
			Door:SetAttribute("Open", false)
			Door:SetAttribute("Opening", false)
			local Bounds = Door:GetBoundingBox()
			local Pose = Origin * CFrame.Angles(0, math.pi / 2, 0)
			Door:PivotTo(Pose * Bounds:ToObjectSpace(Door:GetPivot()))
			Door.Parent = Holder
			Holder:AddTag("Door")
			Holder.Parent = Fixture
			DoorService:BindDoor(Holder)
			local VictimRoot = assert(Victim.PrimaryPart, "Victim must have a root")
			local Initial = VictimRoot.Position
			local HitCount, MaxSpeed = 0, 0
			local Changed = Victim:GetAttributeChangedSignal("Ragdoll"):Connect(function()
				if Victim:GetAttribute("Ragdoll") then
					HitCount += 1
				end
			end)
			local Motion = RunService.PostSimulation:Connect(function()
				MaxSpeed = math.max(MaxSpeed, VictimRoot.AssemblyLinearVelocity.Magnitude)
			end)
			table.insert(Connections, Changed)
			table.insert(Connections, Motion)
			Check(DoorService:BreakDoor(Door, Attacker, Vector3.new(0, 0, -1), {}), Label .. " door must break")
			local Sensor = Door:FindFirstChild("DoorImpactHitbox") :: BasePart?
			Check(Sensor ~= nil, Label .. " receives the tracking hitbox")
			task.wait(0.65)
			local Distance = (VictimRoot.Position - Initial):Dot(Vector3.new(0, 0, -1))
			Check(
				HitCount == 1 and Victim:GetAttribute("Ragdoll") == true,
				Label
					.. " enters ragdoll exactly once on impact: "
					.. game:GetService("HttpService"):JSONEncode({
						Hits = HitCount,
						Ragdoll = Victim:GetAttribute("Ragdoll"),
						Distance = Distance,
						MaxSpeed = MaxSpeed,
						Attributes = Victim:GetAttributes(),
						Position = tostring(VictimRoot.Position),
						Initial = tostring(Initial),
						Door = tostring(Door:GetPivot().Position),
					})
			)
			Check(Distance > 1 and MaxSpeed > 15, Label .. " receives a velocity-based push")
			Check(not Side:GetAttribute("Ragdoll"), Label .. " leaves a nearby off-path character unaffected")
			Check(not Attacker:GetAttribute("Ragdoll"), Label .. " excludes the kicker")
			table.insert(Results, { Case = Label, Distance = Distance, MaxSpeed = MaxSpeed, Hits = HitCount })
			task.wait(0.7)
			Changed:Disconnect()
			Motion:Disconnect()
			Holder:Destroy()
			Check(not Sensor or Sensor.Parent == nil, Label .. " sensor is cleaned up with the panel")
		end

		Trial("Dummy", Target)
		Target:PivotTo(Origin * CFrame.new(30, 0, 0))
		Trial("Player", Character)
	end)

	for _, Connection in Connections do
		Connection:Disconnect()
	end
	if Character.Parent then
		if Character:GetAttribute("Ragdoll") then
			RagdollService:Unragdoll(Character)
		end
		Character:PivotTo(OriginalPivot)
		for _, Part: BasePart in Character:QueryDescendants("BasePart") do
			Part.AssemblyLinearVelocity = Vector3.zero
			Part.AssemblyAngularVelocity = Vector3.zero
		end
		if Root:CanSetNetworkOwnership() then
			Root:SetNetworkOwner(OriginalOwner)
		end
		if HadForceField then
			CharacterService:EnableForceField(Character, true)
		end
	end
	-- Allow a failed trial's scheduled recovery to finish before destroying test rigs.
	task.wait(1.1)
	for _, Model in Models do
		Model:Destroy()
	end
	Fixture:Destroy()
	assert(Success, Failure)
	return { Checks = Checks, Cases = Results }
end
