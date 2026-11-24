-- Run with real Roblox parts; isolates the service from gameplay initialization.
return function(Source: string, MassSource: string): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Fixture = Instance.new("Folder")
	Fixture.Name = "EntityMassValidation"
	Fixture.Parent = workspace
	local Modules = Instance.new("Folder")
	Modules.Parent = ReplicatedStorage
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local ServiceModule = Instance.new("ModuleScript")
	ServiceModule.Source = Source:gsub(
		"local Knit = require%(ReplicatedStorage%.Packages%.Knit%)",
		"local Knit = { CreateService = function(Service) return Service end }"
	)
	ServiceModule.Parent = Modules
	local MassModule = Instance.new("ModuleScript")
	MassModule.Source = MassSource
	MassModule.Parent = Modules
	local Service, GetModelMass = require(ServiceModule), require(MassModule)
	local function Rig(RigType: Enum.HumanoidRigType, Names: { string }): Model
		local Character = Instance.new("Model")
		local Humanoid = Instance.new("Humanoid")
		Humanoid.RigType = RigType
		Humanoid.Parent = Character
		for _, Name in Names do
			local Part = Instance.new("Part")
			Part.Name = Name
			Part.CanCollide = false
			Part.Massless = true
			Part.Parent = Character
		end
		local Root = Instance.new("Part")
		Root.Name = "HumanoidRootPart"
		Root.CanCollide = false
		Root.Parent = Character
		Character.PrimaryPart = Root
		local Accessory = Instance.new("Accessory")
		Accessory.Parent = Character
		local Handle = Instance.new("Part")
		Handle.Name = "Head"
		Handle.Parent = Accessory
		local Hitbox = Instance.new("Part")
		Hitbox.Name = "Hitbox"
		Hitbox.Parent = Root
		Character.Parent = Fixture
		return Character
	end
	local Success, Failure = pcall(function()
		local R6Names = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
		local R6 = Rig(Enum.HumanoidRigType.R6, R6Names)
		local Proxy = Instance.new("Part")
		Proxy.Name = "RightHand"
		Proxy.Parent = R6
		Service:ConfigureCharacter(R6)
		for _, Name in R6Names do
			Check(not R6[Name].Massless, "R6 body part contributes mass: " .. Name)
		end
		Check(R6.PrimaryPart.Massless and Proxy.Massless, "The root and R6 sword-hand proxy stay massless")
		Check(
			R6.Accessory.Head.Massless and R6.PrimaryPart.Hitbox.Massless,
			"A nested cosmetic named Head and collision helpers do not count as body parts"
		)

		local R15Names = {
			"Head",
			"UpperTorso",
			"LowerTorso",
			"LeftUpperArm",
			"LeftLowerArm",
			"LeftHand",
			"RightUpperArm",
			"RightLowerArm",
			"RightHand",
			"LeftUpperLeg",
			"LeftLowerLeg",
			"LeftFoot",
			"RightUpperLeg",
			"RightLowerLeg",
			"RightFoot",
		}
		local R15 = Rig(Enum.HumanoidRigType.R15, R15Names)
		Service:ConfigureCharacter(R15)
		for _, Name in R15Names do
			Check(not R15[Name].Massless, "R15 body segment contributes mass: " .. Name)
		end
		local Expected = 0
		for _, Name in R6Names do
			local Part = R6[Name] :: BasePart
			local Weld = Instance.new("WeldConstraint")
			Weld.Part0, Weld.Part1 = R6.PrimaryPart, Part
			Weld.Parent = Part
			Expected += Part:GetMass()
		end
		Check(
			math.abs(GetModelMass(R6) - Expected) < 0.001,
			"The mass helper counts each physical body part once, even when welded into one assembly"
		)
		R6.Head.Anchored = true
		Check(
			math.abs(GetModelMass(R6) - (Expected - R6.Head:GetMass())) < 0.001,
			"Anchored parts do not contribute to movable model mass"
		)
		R6.Head.Anchored = false
		R6:SetAttribute("Carried", true)
		R6.Torso.Massless = true
		Service:ConfigureCharacter(R6)
		Check(R6.Torso.Massless, "Configuring an entity preserves its temporary carried mass override")
		R6:SetAttribute("Carried", false)
		R6:SetAttribute("InHorse", true)
		Service:ConfigureCharacter(R6)
		Check(R6.Torso.Massless, "Configuring an entity preserves its temporary mounted mass override")
		R6:SetAttribute("InHorse", false)
		Service:ConfigureCharacter(R6)
		Check(not R6.Torso.Massless, "Normal body mass is reapplied once temporary overrides end")
	end)
	Fixture:Destroy()
	Modules:Destroy()
	assert(Success, Failure)
	return "EntityPhysics: " .. Checks .. " checks passed"
end
