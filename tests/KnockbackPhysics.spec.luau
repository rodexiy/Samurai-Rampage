-- Run on the server in a playtest with a loaded player character.
return function(Player: Player): { [string]: any }
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Knit = require(ReplicatedStorage.Packages.Knit)
	local GetAssemblyMass = require(ReplicatedStorage.Shared.Utils.GetAssemblyMass)
	local WeaponService = Knit.GetService("WeaponService")
	local MobService = Knit.GetService("MobService")
	local AIService = Knit.GetService("AIService")
	local KickService = Knit.GetService("KickService")
	local RagdollService = Knit.GetService("RagdollService")
	local Character = assert(Player.Character, "Player character must be loaded")
	local Root = assert(Character.PrimaryPart, "Player root part must be loaded")
	local OriginalPivot = Character:GetPivot()
	local OriginalCombo = Character:GetAttribute("ComboCounter")
	local OriginalOwner = Root:GetNetworkOwner()
	local Created: { Model } = {}
	local Results = {}
	local Checks = 0
	local Platform = Instance.new("Part")
	Platform.Name = "KnockbackPhysicsValidation"
	Platform.Size = Vector3.new(300, 1, 300)
	Platform.CFrame = CFrame.new(20000, 10000, 20000)
	Platform.Anchored = true
	Platform.Parent = workspace
	local Origin = Platform.CFrame * CFrame.new(0, 4, 0)

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Spawn(Offset: Vector3): Model
		local Dummy = assert(MobService:SpawnMob("Dummy", Origin * CFrame.new(Offset), "Dummy"), "Dummy must spawn")
		table.insert(Created, Dummy)
		AIService:AddAI(Dummy, "Dummy", "Dummy")
		return Dummy
	end

	local function Observe(Label: string, Target: Model, Attacker: Model, Apply: () -> ())
		local TargetRoot = assert(Target.PrimaryPart, Label .. " must have a root part")
		local Initial = TargetRoot.Position
		local Direction = (Initial - assert(Attacker.PrimaryPart, "Attacker must have a root part").Position).Unit
		Apply()
		Check(Target:GetAttribute("Ragdoll") == true, Label .. " enters ragdoll")
		local Mass = GetAssemblyMass(Target)
		Check(Mass > 0, Label .. " has nonzero physical mass")
		local Attachment = TargetRoot:FindFirstChild("Knockback") :: Attachment?
		local Force = Attachment and Attachment:FindFirstChildWhichIsA("LinearVelocity")
		Check(Force ~= nil and Force.VectorVelocity.Magnitude > 0, Label .. " receives nonzero LinearVelocity")
		Check(
			TargetRoot:FindFirstChildWhichIsA("BodyVelocity") == nil,
			Label .. " has no competing legacy BodyVelocity"
		)
		Check(TargetRoot:GetNetworkOwner() == nil, Label .. " physics is owned by the server")
		local Speed = Force and Force.VectorVelocity.Magnitude or 0
		task.wait(0.35)
		local Distance = (TargetRoot.Position - Initial):Dot(Direction)
		Check(Distance > 0.5, Label .. " must physically move away")
		task.wait(0.85)
		Check(not Target:GetAttribute("Ragdoll"), Label .. " recovers from timed ragdoll")
		if Target == Character then
			Check(
				TargetRoot:GetNetworkOwner() == Player,
				Label .. " returns physics ownership to the player after recovery"
			)
		end
		table.insert(Results, { Case = Label, Mass = Mass, Speed = Speed, Distance = Distance })
	end

	local Success, Failure = pcall(function()
		Character:PivotTo(Origin)
		local Dummy = Spawn(Vector3.new(10, 0, 0))
		task.wait(0.3)
		Character:SetAttribute("ComboCounter", #WeaponService:GetStanceAnimationFolder(Character).M1:GetChildren())
		Observe("Sword combo on Dummy", Dummy, Character, function()
			WeaponService:TryFling(Dummy, Character)
		end)

		Dummy:PivotTo(Origin * CFrame.new(-10, 0, 0))
		Dummy:SetAttribute("ComboCounter", #WeaponService:GetStanceAnimationFolder(Dummy).M1:GetChildren())
		Observe("Sword combo on player", Character, Dummy, function()
			WeaponService:TryFling(Character, Dummy)
		end)

		local KickTarget = Spawn(Vector3.new(20, 0, 0))
		task.wait(0.2)
		Observe("Configured kick on Dummy", KickTarget, Character, function()
			KickService:HitTarget(Character, KickTarget)
		end)
	end)

	if Character.Parent then
		if Character:GetAttribute("Ragdoll") then
			RagdollService:Unragdoll(Character)
		end
		Character:SetAttribute("ComboCounter", OriginalCombo)
		Character:PivotTo(OriginalPivot)
		for _, Part: BasePart in Character:QueryDescendants("BasePart") do
			Part.AssemblyLinearVelocity = Vector3.zero
			Part.AssemblyAngularVelocity = Vector3.zero
		end
		if Root:CanSetNetworkOwnership() then
			Root:SetNetworkOwner(OriginalOwner)
		end
	end
	for _, Dummy in Created do
		Dummy:Destroy()
	end
	Platform:Destroy()
	assert(Success, Failure)
	return { Checks = Checks, Cases = Results }
end
