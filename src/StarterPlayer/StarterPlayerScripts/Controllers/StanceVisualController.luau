local Knit = require(game.ReplicatedStorage.Packages.Knit)

local StanceVisualController = Knit.CreateController({
	Name = "StanceVisualController",
})

local Stances = require(game.ReplicatedStorage.Shared.Index.Stances)

local LEFT_ARM_RAGDOLL_TAG = "ClientLeftArmRagdoll"
local LEFT_ARM_OUTWARD_OFFSET = 0.35
local LEFT_ARM_SWING_ANGLE = 35
local LEFT_ARM_TWIST_ANGLE = 70
local LEFT_ARM_FRICTION_TORQUE = 30

local CharacterConnections = {}
local CharacterState = {}

local function ClearPartVelocity(Part: BasePart)
	Part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	Part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

local function GetLeftShoulder(Character: Model): Motor6D?
	local Torso = Character:FindFirstChild("Torso")
	if not Torso then
		return
	end

	local LeftShoulder = Torso:FindFirstChild("Left Shoulder")
	if LeftShoulder and LeftShoulder:IsA("Motor6D") then
		return LeftShoulder
	end
end

local function SnapLeftArmToShoulder(LeftShoulder: Motor6D)
	if not LeftShoulder.Part0 or not LeftShoulder.Part1 then
		return
	end

	local LeftArm = LeftShoulder.Part1
	LeftArm.CFrame = LeftShoulder.Part0.CFrame * LeftShoulder.C0 * LeftShoulder.C1:Inverse()
	ClearPartVelocity(LeftArm)
end

local function SnapLeftArmRagdoll(Character: Model)
	if not CharacterState[Character] then
		return
	end

	local LeftShoulder = GetLeftShoulder(Character)
	if not LeftShoulder then
		return
	end

	SnapLeftArmToShoulder(LeftShoulder)
end

local function ScheduleLeftArmSnap(Character: Model)
	task.defer(SnapLeftArmRagdoll, Character)

	task.delay(0.2, function()
		if Character.Parent then
			SnapLeftArmRagdoll(Character)
		end
	end)

	task.delay(0.5, function()
		if Character.Parent then
			SnapLeftArmRagdoll(Character)
		end
	end)
end

local function GetOrCreateAttachment(Parent: BasePart, Name: string, CFrameValue: CFrame)
	local Attachment = Parent:FindFirstChild(Name)
	if Attachment and Attachment:IsA("Attachment") then
		Attachment.CFrame = CFrameValue
		return Attachment, false
	end

	Attachment = Instance.new("Attachment")
	Attachment.Name = Name
	Attachment.CFrame = CFrameValue
	Attachment:SetAttribute(LEFT_ARM_RAGDOLL_TAG, true)
	Attachment.Parent = Parent

	return Attachment, true
end

local function GetLeftArmAttachmentCFrames(LeftShoulder: Motor6D)
	local LeftArm = LeftShoulder.Part1
	return CFrame.new(LeftShoulder.C0.Position + Vector3.new(-LEFT_ARM_OUTWARD_OFFSET, 0, 0)),
		CFrame.new(0, LeftArm.Size.Y / 2, 0)
end

function StanceVisualController:DisableLeftArmRagdoll(Character: Model)
	local State = CharacterState[Character]
	if not State then
		return
	end

	if State.LeftShoulder and State.LeftShoulder.Parent then
		State.LeftShoulder.Enabled = State.LeftShoulderEnabled
	end
	if State.LeftArm and State.LeftArm.Parent then
		State.LeftArm.Massless = State.LeftArmMassless
	end

	for _, InstanceToDestroy in State.Instances do
		if InstanceToDestroy and InstanceToDestroy.Parent then
			InstanceToDestroy:Destroy()
		end
	end

	CharacterState[Character] = nil
end

function StanceVisualController:EnableLeftArmRagdoll(Character: Model)
	if CharacterState[Character] then
		return
	end

	local LeftShoulder = GetLeftShoulder(Character)
	if not LeftShoulder or not LeftShoulder.Part0 or not LeftShoulder.Part1 then
		return
	end

	local Attachment0CFrame, Attachment1CFrame = GetLeftArmAttachmentCFrames(LeftShoulder)
	local Attachment0, CreatedAttachment0 =
		GetOrCreateAttachment(LeftShoulder.Part0, "ClientLeftShoulderRagdollAttachment", Attachment0CFrame)
	local Attachment1, CreatedAttachment1 =
		GetOrCreateAttachment(LeftShoulder.Part1, "ClientLeftArmRagdollAttachment", Attachment1CFrame)

	local Socket = Instance.new("BallSocketConstraint")
	Socket.Name = "ClientLeftArmRagdollSocket"
	Socket.Attachment0 = Attachment0
	Socket.Attachment1 = Attachment1
	Socket.LimitsEnabled = true
	Socket.UpperAngle = LEFT_ARM_SWING_ANGLE
	Socket.TwistLimitsEnabled = true
	Socket.TwistLowerAngle = -LEFT_ARM_TWIST_ANGLE
	Socket.TwistUpperAngle = LEFT_ARM_TWIST_ANGLE
	Socket.MaxFrictionTorque = LEFT_ARM_FRICTION_TORQUE
	Socket.Restitution = 0
	Socket:SetAttribute(LEFT_ARM_RAGDOLL_TAG, true)
	Socket.Parent = LeftShoulder.Part0

	local Instances = { Socket }
	if CreatedAttachment0 then
		table.insert(Instances, Attachment0)
	end
	if CreatedAttachment1 then
		table.insert(Instances, Attachment1)
	end

	CharacterState[Character] = {
		LeftShoulder = LeftShoulder,
		LeftShoulderEnabled = LeftShoulder.Enabled,
		LeftArm = LeftShoulder.Part1,
		LeftArmMassless = LeftShoulder.Part1.Massless,
		Instances = Instances,
	}

	LeftShoulder.Part1.Massless = true
	LeftShoulder.Enabled = false
	SnapLeftArmToShoulder(LeftShoulder)
end

function StanceVisualController:UpdateCharacter(Character: Model)
	local StanceData = Stances[Character:GetAttribute("Stance")]
	if StanceData and StanceData.LeftArmRagdoll then
		self:EnableLeftArmRagdoll(Character)
	else
		self:DisableLeftArmRagdoll(Character)
	end
end

function StanceVisualController:BindCharacter(Character: Model)
	if CharacterConnections[Character] then
		return
	end

	local Connections = {}
	CharacterConnections[Character] = Connections

	local function Update()
		self:UpdateCharacter(Character)
	end

	local function SnapAfterTeleport()
		if Character:GetAttribute("RealmTeleporting") then
			return
		end

		ScheduleLeftArmSnap(Character)
	end

	table.insert(Connections, Character:GetAttributeChangedSignal("Stance"):Connect(Update))
	table.insert(Connections, Character:GetAttributeChangedSignal("RealmTeleporting"):Connect(SnapAfterTeleport))
	table.insert(Connections, Character:GetAttributeChangedSignal("InWisdomWorld"):Connect(SnapAfterTeleport))
	table.insert(Connections, Character.DescendantAdded:Connect(function(Descendant)
		if Descendant.Name == "Left Shoulder" and Descendant:IsA("Motor6D") then
			task.defer(Update)
		end
	end))
	table.insert(Connections, Character.Destroying:Connect(function()
		self:DisableLeftArmRagdoll(Character)

		for _, Connection in Connections do
			Connection:Disconnect()
		end

		CharacterConnections[Character] = nil
	end))

	Update()
end

function StanceVisualController.KnitStart()
	local Entity = workspace:WaitForChild("Entity")

	for _, Character in Entity:GetChildren() do
		if Character:IsA("Model") then
			StanceVisualController:BindCharacter(Character)
		end
	end

	Entity.ChildAdded:Connect(function(Character)
		if Character:IsA("Model") then
			StanceVisualController:BindCharacter(Character)
		end
	end)
end

return StanceVisualController
