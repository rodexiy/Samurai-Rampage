local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local EntityPhysicsService = Knit.CreateService({ Name = "EntityPhysicsService", Client = {} })

local R6BodyParts: { [string]: boolean } = {
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

local R15BodyParts: { [string]: boolean } = {
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

function EntityPhysicsService:ConfigureCharacter(Character: Model)
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if not Humanoid or Character:GetAttribute("Carried") or Character:GetAttribute("InHorse") then
		return
	end

	local BodyParts = if Humanoid.RigType == Enum.HumanoidRigType.R15 then R15BodyParts else R6BodyParts
	for _, Part: BasePart in Character:QueryDescendants("BasePart") do
		-- Only real body segments contribute mass; roots, hitboxes and cosmetic parts stay massless.
		Part.Massless = not (Part.Parent == Character and BodyParts[Part.Name] == true)
	end
end

local function ConfigureEntity(Object: Instance)
	if Object:IsA("Model") and Object:IsDescendantOf(workspace) then
		EntityPhysicsService:ConfigureCharacter(Object)
	end
end

function EntityPhysicsService.KnitStart()
	CollectionService:GetInstanceAddedSignal("Entity"):Connect(ConfigureEntity)
	for _, Object in CollectionService:GetTagged("Entity") do
		ConfigureEntity(Object)
	end
end

return EntityPhysicsService
