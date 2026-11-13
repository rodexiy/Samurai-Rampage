local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local HorseGrounding = require(ReplicatedStorage.Shared.HorseGrounding)
local HorseSteeringController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.HorseController.HorseSteeringController)
local HorseGaitController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.HorseController.HorseGaitController)
local HorseAvoidanceController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.HorseController.HorseAvoidanceController)
local HorseMountedAnimationController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.HorseController.HorseMountedAnimationController)

local HorseController = Knit.CreateController({ Name = "HorseController" })
local LocalPlayer = Players.LocalPlayer
local HorseService
local Steering: HorseSteeringController.State? = nil
local Gait: HorseGaitController.State? = nil
local Avoidance: HorseAvoidanceController.State? = nil
local ShiftKeys: { [Enum.KeyCode]: boolean } = {}
local ControlledHorse: Model? = nil
local Grounding: HorseGrounding.State? = nil
local HorseConnections: { [Instance]: { RBXScriptConnection } } = {}
local MountedAnimation = HorseMountedAnimationController.Create()

local function UpdatePrompt(Model: Model)
	local Root = Model.PrimaryPart
	local Prompt = Root and Root:FindFirstChild("MountPrompt") :: ProximityPrompt?
	if Prompt then
		Prompt.Enabled = Model:GetAttribute("OwnerUserId") == LocalPlayer.UserId
			and Model:GetAttribute("RiderUserId") == nil
	end
end

local function DismountAction(_Name: string, State: Enum.UserInputState, _Input: InputObject): Enum.ContextActionResult
	if State == Enum.UserInputState.Begin then
		HorseService.Request:Fire("Dismount")
	end

	return Enum.ContextActionResult.Sink
end

local function GaitAction(_Name: string, State: Enum.UserInputState, Input: InputObject): Enum.ContextActionResult
	if not Gait then
		return Enum.ContextActionResult.Pass
	end
	if State == Enum.UserInputState.Begin then
		if UserInputService:GetFocusedTextBox() or LocalPlayer:GetAttribute("InDialog") then
			return Enum.ContextActionResult.Pass
		end
		ShiftKeys[Input.KeyCode] = true
	elseif State == Enum.UserInputState.End then
		ShiftKeys[Input.KeyCode] = nil
	elseif State == Enum.UserInputState.Cancel then
		table.clear(ShiftKeys)
	end
	HorseGaitController.SetHeld(Gait, next(ShiftKeys) ~= nil, os.clock())

	return Enum.ContextActionResult.Sink
end

local function SetControlledHorse(Model: Model?)
	if ControlledHorse == Model then
		return
	end

	if ControlledHorse and ControlledHorse.PrimaryPart then
		local Velocity = ControlledHorse.PrimaryPart:FindFirstChild("MountVelocity") :: LinearVelocity?
		if Velocity then
			Velocity.PlaneVelocity = Vector2.zero
			Velocity.Enabled = false
		end
	end

	HorseMountedAnimationController.Reset(MountedAnimation)
	ControlledHorse = Model
	Grounding = if Model then HorseGrounding.Create(Model) else nil
	Gait = if Model then HorseGaitController.Create() else nil
	Avoidance = if Model then HorseAvoidanceController.Create() else nil
	table.clear(ShiftKeys)
	Steering = if Model and Model.PrimaryPart
		then HorseSteeringController.Create(Model.PrimaryPart.CFrame, Model.PrimaryPart.AssemblyLinearVelocity) else nil
	ContextActionService:UnbindAction("DismountHorse")
	ContextActionService:UnbindAction("HorseGait")
	if Model then
		ContextActionService:BindActionAtPriority(
			"DismountHorse", DismountAction, true, Enum.ContextActionPriority.High.Value + 1,
			HorseConfig.DismountKey, Enum.KeyCode.ButtonA
		)
		ContextActionService:SetTitle("DismountHorse", "Dismount")
		ContextActionService:BindActionAtPriority("HorseGait", GaitAction, true,
			Enum.ContextActionPriority.High.Value + 2, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
		ContextActionService:SetTitle("HorseGait", "Galopar")
	end
end

local function TrackHorse(Instance: Instance)
	if not Instance:IsA("Model") or HorseConnections[Instance] then
		return
	end

	local Model = Instance
	local function Update()
		UpdatePrompt(Model)
		if Model:GetAttribute("RiderUserId") == LocalPlayer.UserId then
			SetControlledHorse(Model)
		elseif ControlledHorse == Model then
			SetControlledHorse(nil)
		end
	end

	local Connections = {
		Model:GetAttributeChangedSignal("OwnerUserId"):Connect(Update),
		Model:GetAttributeChangedSignal("RiderUserId"):Connect(Update),
		Model:GetPropertyChangedSignal("PrimaryPart"):Connect(Update),
	}
	HorseConnections[Model] = Connections
	local Prompt = Model.PrimaryPart and Model.PrimaryPart:FindFirstChild("MountPrompt") :: ProximityPrompt?
	if Prompt then
		table.insert(Connections, Prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			UpdatePrompt(Model)
		end))
	end
	Update()
end

local function Simulate(DeltaTime: number)
	local Model = ControlledHorse
	local Character = LocalPlayer.Character
	HorseMountedAnimationController.Update(MountedAnimation, Character, Model)

	local Humanoid = Character and Character:FindFirstChildWhichIsA("Humanoid")
	local Root = Model and Model.PrimaryPart
	if not Model or not Root or not Humanoid then
		return
	end

	local Velocity = Root:FindFirstChild("MountVelocity") :: LinearVelocity?
	local Stats = HorseConfig.GetTier(Model:GetAttribute("HorseTier"))
	if not Velocity or not Stats then
		return
	end

	local Direction = Humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if UserInputService:GetFocusedTextBox() or LocalPlayer:GetAttribute("InDialog") then
		Direction = Vector3.zero
		if Gait then
			HorseGaitController.Cancel(Gait)
			table.clear(ShiftKeys)
		end
	end
	if Direction.Magnitude > 1 then
		Direction = Direction.Unit
	end

	-- Ground support is raycast-driven; gravity remains free while airborne.
	Velocity.Enabled = true
	if not Grounding then
		Grounding = HorseGrounding.Create(Model)
	end
	if Grounding then
		if not Steering then
			Steering = HorseSteeringController.Create(Root.CFrame, Root.AssemblyLinearVelocity)
		end
		local SpeedMultiplier = if Gait then HorseGaitController.Update(Gait, DeltaTime, os.clock(), Direction.Magnitude > 0.01)
			else HorseConfig.Gaits.TrotMultiplier
		local AvoidanceMultiplier = 1
		if Avoidance then
			Direction, AvoidanceMultiplier = HorseAvoidanceController.Update(Avoidance, Grounding, Direction,
				math.max(Steering.Speed, Stats.Speed * SpeedMultiplier), DeltaTime)
		end
		local Movement = HorseSteeringController.Update(Steering, Root.CFrame, Root.AssemblyLinearVelocity,
			Direction, Stats, DeltaTime, Grounding.Grounded, Root.AssemblyAngularVelocity, SpeedMultiplier * AvoidanceMultiplier)
		local Travel = HorseGrounding.ConstrainMovement(Grounding, Movement, DeltaTime)
		Velocity.PlaneVelocity = Vector2.new(Travel.X, Travel.Z)
		Grounding.Heading = Steering.Heading
		HorseGrounding.Update(Grounding, DeltaTime, nil, nil, Steering.Bank)
	else
		Velocity.PlaneVelocity = Vector2.zero
	end
end

function HorseController.KnitStart()
	HorseService = Knit.GetService("HorseService")
	CollectionService:GetInstanceAddedSignal(HorseConfig.Tag):Connect(TrackHorse)
	CollectionService:GetInstanceRemovedSignal(HorseConfig.Tag):Connect(function(Instance: Instance)
		-- Streaming can remove a tag without destroying the instance.
		local Connections = HorseConnections[Instance]
		if Connections then
			for _, Connection in Connections do
				Connection:Disconnect()
			end
			HorseConnections[Instance] = nil
		end

		if ControlledHorse == Instance then
			SetControlledHorse(nil)
		end
	end)
	for _, Model in CollectionService:GetTagged(HorseConfig.Tag) do
		TrackHorse(Model)
	end

	LocalPlayer.CharacterRemoving:Connect(function()
		SetControlledHorse(nil)
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(ShiftKeys)
		if Gait then
			HorseGaitController.Cancel(Gait)
		end
	end)
	UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if not Processed and Input.KeyCode == HorseConfig.SpawnKey and not UserInputService:GetFocusedTextBox() then
			HorseService.Request:Fire("Spawn")
		end
	end)
	RunService.PreSimulation:Connect(Simulate)
	RunService.PostSimulation:Connect(function()
		if Grounding and Grounding.Root:IsDescendantOf(workspace) then
			-- Resolve contacts after integration, before the mounted pose is rendered.
			HorseGrounding.Update(Grounding, 0)
		end
	end)
end

return HorseController
