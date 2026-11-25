local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.RagdollConfig)
local Ragdoll = require(ReplicatedStorage.Assets.Libraries.Ragdoll)

local RagdollService = Knit.CreateService({
	Name = "RagdollService",
	Client = { PrepareRecovery = Knit.CreateSignal(), RecoveryReady = Knit.CreateSignal() },
})

local PendingRecovery: { [Model]: number } = {}
local RecoveryTimers: { [Model]: thread } = {}
local RecoveryConnection: RBXScriptConnection?
type Handoff = { Id: number, Player: Player?, SentAt: number? }
local Handoffs: { [Model]: Handoff } = {}
local NextRecoveryId = 0

local HipSides = { TorsoRightLegAttachment = 1, TorsoLeftLegAttachment = -1 }

local function ConfigureRagdollPhysics(Character: Model)
	for _, Joint: BallSocketConstraint in Character:QueryDescendants("BallSocketConstraint") do
		if not Joint:GetAttribute("__Ragdoll") then
			continue
		end

		Joint.MaxFrictionTorque = Config.JointFrictionTorque
		for _, Attachment in { Joint.Attachment0, Joint.Attachment1 } do
			local Side = HipSides[Attachment.Name]
			if Side then
				-- The legacy library attaches each leg to the opposite side of the torso.
				local Position = Attachment.Position
				Attachment.Position = Vector3.new(math.abs(Position.X) * Side, Position.Y, Position.Z)
			end
		end
	end
end

local function StopMonitoringIfIdle()
	if next(PendingRecovery) == nil and next(Handoffs) == nil and RecoveryConnection then
		RecoveryConnection:Disconnect()
		RecoveryConnection = nil
	end
end

local function SetCharacterOwner(Character: Model, Owner: Player?)
	local Assemblies: { [BasePart]: boolean } = {}
	for _, Part: BasePart in Character:QueryDescendants("BasePart") do
		local Root = Part.AssemblyRootPart or Part
		if not Assemblies[Root] and Root:CanSetNetworkOwnership() then
			Assemblies[Root] = true
			Root:SetNetworkOwner(Owner)
		end
	end
end

local function ClearVelocity(Character: Model)
	for _, Part: BasePart in Character:QueryDescendants("BasePart") do
		Part.AssemblyLinearVelocity = Vector3.zero
		Part.AssemblyAngularVelocity = Vector3.zero
	end
end

local function RestoreRig(Character: Model)
	SetCharacterOwner(Character, nil)
	for _, Object in Character:QueryDescendants("Attachment, Constraint, NoCollisionConstraint") do
		if Object:GetAttribute("__Ragdoll") then
			Object:Destroy()
		end
	end
	for _, Motor: Motor6D in Character:QueryDescendants("Motor6D") do
		Motor.Transform = CFrame.identity
		Motor.Enabled = true
	end
	-- Enabling motors merges assemblies. Keep the rebuilt rig on the server too.
	SetCharacterOwner(Character, nil)
	ClearVelocity(Character)
end

local function CancelTimer(Character: Model)
	local Timer = RecoveryTimers[Character]
	if Timer then
		task.cancel(Timer)
		RecoveryTimers[Character] = nil
	end
end

local function CanRecover(Character: Model): boolean
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")

	return Character:IsDescendantOf(workspace)
		and Character:GetAttribute("Ragdoll") == true
		and not Character:GetAttribute("Downed")
		and not Character:GetAttribute("Carried")
		and not Character:GetAttribute("Died")
		and Humanoid ~= nil
		and Humanoid.Health > 0
		and Character.PrimaryPart ~= nil
end

local function FinishRecovery(Character: Model, State: Handoff)
	if Handoffs[Character] ~= State or not CanRecover(Character) then
		return
	end

	ClearVelocity(Character)
	SetCharacterOwner(Character, State.Player)
	Handoffs[Character] = nil
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid") :: Humanoid
	Humanoid.AutoRotate = true
	Character:SetAttribute("Ragdoll", false)
	Character:SetAttribute("RagdollRecoveryId", nil)
	if not State.Player then
		Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	StopMonitoringIfIdle()
end

local function BeginRecovery(Character: Model)
	NextRecoveryId += 1
	Handoffs[Character] = { Id = NextRecoveryId, Player = Players:GetPlayerFromCharacter(Character) }
	Character:SetAttribute("RagdollRecoveryId", NextRecoveryId)
	RestoreRig(Character)
end

local function StepRecovery(DeltaTime: number)
	-- Process handoffs first so newly rebuilt rigs always get a full physics step.
	for Character, State in Handoffs do
		if not CanRecover(Character) or (State.Player and State.Player.Character ~= Character) then
			if Character:IsDescendantOf(workspace) and Character:GetAttribute("Ragdoll") then
				RagdollService:Ragdoll(Character)
			else
				Handoffs[Character] = nil
				Character:SetAttribute("RagdollRecoveryId", nil)
			end
		elseif not State.Player or (State.SentAt and os.clock() - State.SentAt >= Config.RecoverySyncTimeout) then
			-- A missing acknowledgement must not leave the character stuck forever.
			FinishRecovery(Character, State)
		elseif not State.SentAt then
			State.SentAt = os.clock()
			local Root = Character.PrimaryPart :: BasePart
			RagdollService.Client.PrepareRecovery:Fire(State.Player, Character, State.Id, Root.CFrame)
		end
	end

	for Character, StableTime in PendingRecovery do
		if not CanRecover(Character) then
			PendingRecovery[Character] = nil
			continue
		end

		local Root = Character.PrimaryPart :: BasePart
		if Root.AssemblyLinearVelocity.Magnitude > Config.RecoveryMaxSpeed
			or Root.AssemblyAngularVelocity.Magnitude > Config.RecoveryMaxAngularSpeed then
			PendingRecovery[Character] = 0
			continue
		end

		StableTime += DeltaTime
		if StableTime >= Config.RecoveryStableTime then
			PendingRecovery[Character] = nil
			BeginRecovery(Character)
		else
			PendingRecovery[Character] = StableTime
		end
	end

	StopMonitoringIfIdle()
end

function RagdollService:Ragdoll(Character: Model, Impulse: number?, Direction: Vector3?, ImpulseDuration: number?)
	CancelTimer(Character)
	PendingRecovery[Character] = nil
	if Handoffs[Character] then
		Handoffs[Character] = nil
		Character:SetAttribute("Ragdoll", false)
	end
	StopMonitoringIfIdle()

	-- Keep timed recovery here so the legacy library cannot bypass the speed check.
	-- The library yields after making its joints; fix them before the first physics step.
	local Preparation = RunService.PreSimulation:Once(function()
		ConfigureRagdollPhysics(Character)
	end)
	Ragdoll:Ragdoll(Character, Impulse, Direction)
	Preparation:Disconnect()
	ConfigureRagdollPhysics(Character)
	SetCharacterOwner(Character, nil)
	Character:SetAttribute("RagdollRecoveryId", nil)

	if ImpulseDuration and Character:GetAttribute("Ragdoll") then
		RecoveryTimers[Character] = task.delay(ImpulseDuration, function()
			RecoveryTimers[Character] = nil
			self:Unragdoll(Character)
		end)
	end
end

function RagdollService:Unragdoll(Character: Model)
	CancelTimer(Character)
	if Handoffs[Character] or not CanRecover(Character) then
		return
	end

	PendingRecovery[Character] = PendingRecovery[Character] or 0
	if not RecoveryConnection then
		RecoveryConnection = RunService.PostSimulation:Connect(StepRecovery)
	end
end

function RagdollService.KnitInit() end

function RagdollService.KnitStart()
	RagdollService.Client.RecoveryReady:Connect(function(Player: Player, Character: Model, Id: number)
		if typeof(Character) ~= "Instance" or not Character:IsA("Model") or Player.Character ~= Character then
			return
		end

		local State = Handoffs[Character]
		if State and State.Player == Player and State.Id == Id and State.SentAt then
			FinishRecovery(Character, State)
		end
	end)
end

return RagdollService
