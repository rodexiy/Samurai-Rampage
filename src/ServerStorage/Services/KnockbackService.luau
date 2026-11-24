local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GetAssemblyMass = require(ReplicatedStorage.Shared.Utils.GetAssemblyMass)

local KnockbackService = Knit.CreateService({
	Name = "KnockbackService",
	Client = {},
})

local RagdollService
local FlingImpulse = 4
local FlingForceDuration = 0.2
local FlingRagdollDuration = 1

local function ClaimRagdollPhysics(Character: Model)
	local Assemblies: { [BasePart]: boolean } = {}
	for _, Part: BasePart in Character:QueryDescendants("BasePart") do
		local Root = Part.AssemblyRootPart or Part
		if not Assemblies[Root] then
			Assemblies[Root] = true
			if Root:CanSetNetworkOwnership() then
				Root:SetNetworkOwner(nil)
			end
		end
	end
end

function KnockbackService:Push(Character: Model, Velocity: Vector3, Duration: number)
	local Root = Character.PrimaryPart
	if not Root or Root.Anchored then
		return
	end

	local Attachment = Instance.new("Attachment")
	Attachment.Name = "Knockback"
	Attachment.Parent = Root

	local Force = Instance.new("LinearVelocity")
	Force.Attachment0 = Attachment
	Force.RelativeTo = Enum.ActuatorRelativeTo.World
	Force.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	Force.VectorVelocity = Velocity
	Force.ForceLimitsEnabled = false
	Force.Parent = Attachment
	Debris:AddItem(Attachment, Duration)
end

local function PrepareFling(Character: Model, ShouldRagdoll: boolean?): boolean
	if not Character.PrimaryPart or Character.PrimaryPart.Anchored then
		return false
	end

	if ShouldRagdoll ~= false and not Character:GetAttribute("Ragdoll") then
		local Root = Character.PrimaryPart
		local ExistingForces: { [Instance]: boolean } = {}
		for _, Force in Root:GetChildren() do
			if Force:IsA("BodyVelocity") then
				ExistingForces[Force] = true
			end
		end

		RagdollService:Ragdoll(Character, 0, Vector3.zero, FlingRagdollDuration)

		-- The legacy ragdoll creates a BodyVelocity; movement is handled by Push instead.
		for _, Force in Root:GetChildren() do
			if Force:IsA("BodyVelocity") and not ExistingForces[Force] then
				Force:Destroy()
			end
		end
	end

	if Character:GetAttribute("Ragdoll") then
		ClaimRagdollPhysics(Character)
	end
	return Character.PrimaryPart ~= nil and not Character.PrimaryPart.Anchored
end

function KnockbackService:FlingWithVelocity(Character: Model, Velocity: Vector3, ShouldRagdoll: boolean?)
	if PrepareFling(Character, ShouldRagdoll) then
		self:Push(Character, Velocity, FlingForceDuration)
	end
end

function KnockbackService:FlingInDirection(
	Character: Model,
	Direction: Vector3,
	ShouldRagdoll: boolean?,
	Impulse: number?
)
	if Direction.Magnitude <= 0.001 or not PrepareFling(Character, ShouldRagdoll) then
		return
	end
	Direction = Direction.Unit
	local KnockbackImpulse = Impulse or FlingImpulse
	self:Push(Character, Direction * (KnockbackImpulse * GetAssemblyMass(Character)), FlingForceDuration)
end

function KnockbackService:Fling(Character: Model, Attacker: Model, ShouldRagdoll: boolean?, Impulse: number?)
	local Offset = Character:GetPivot().Position - Attacker:GetPivot().Position
	local Direction = if Offset.Magnitude > 0.001 then Offset.Unit else Attacker:GetPivot().LookVector
	self:FlingInDirection(Character, Direction, ShouldRagdoll, Impulse)
end

function KnockbackService.KnitInit()
	RagdollService = Knit.GetService("RagdollService")
end

return KnockbackService
