local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.RagdollConfig)

local RagdollImpactController = Knit.CreateController({ Name = "RagdollImpactController" })
local Randomizer = Random.new()

type BodyMotion = { Part: BasePart, Position: Vector3, Velocity: Vector3 }
type RagdollState = {
	Character: Model,
	Params: RaycastParams,
	Motions: { BodyMotion },
	LastSound: number,
	LastSoundId: string?,
}

local Active: { [Model]: RagdollState } = {}
local Bound: { [Model]: RBXScriptConnection } = {}
local PreConnection: RBXScriptConnection?
local PostConnection: RBXScriptConnection?

function RagdollImpactController:PlayImpact(State: RagdollState, Part: BasePart)
	local Assets = Config.ImpactSounds
	local Index = Randomizer:NextInteger(1, #Assets)
	if #Assets > 1 and Assets[Index] == State.LastSoundId then
		Index = Index % #Assets + 1
	end
	State.LastSoundId = Assets[Index]
	State.LastSound = os.clock()

	local Sound = Instance.new("Sound")
	Sound.Name = "RagdollGroundImpact"
	Sound.SoundId = Assets[Index]
	Sound.Volume = Config.ImpactVolume
	Sound.RollOffMinDistance = 5
	Sound.RollOffMaxDistance = Config.ImpactMaxDistance
	Sound.Parent = Part
	Sound.Ended:Once(function()
		Sound:Destroy()
	end)
	Debris:AddItem(Sound, 10)
	Sound:Play()
end

function RagdollImpactController:CaptureMotion()
	for Character, State in Active do
		table.clear(State.Motions)
		if not Character:IsDescendantOf(workspace) then
			continue
		end

		for _, Part in Character:GetChildren() do
			if Part:IsA("BasePart") and Part ~= Character.PrimaryPart then
				table.insert(State.Motions, {
					Part = Part,
					Position = Part.Position,
					Velocity = Part:GetVelocityAtPosition(Part.Position),
				})
			end
		end
	end
end

local function GroundContact(Motion: BodyMotion, Params: RaycastParams): RaycastResult?
	local Part = Motion.Part
	local Frame, Half = Part.CFrame, Part.Size / 2
	local Support = math.abs(Frame.RightVector.Y) * Half.X
		+ math.abs(Frame.UpVector.Y) * Half.Y
		+ math.abs(Frame.LookVector.Y) * Half.Z
	local Travel = Part.Position - Motion.Position
	local Hit: RaycastResult? = nil
	if Travel.Magnitude > 0.001 then
		Hit = workspace:Raycast(Motion.Position, Travel + Vector3.new(0, -Support, 0), Params)
	end
	if not Hit then
		Hit = workspace:Raycast(Part.Position, Vector3.new(0, -Support - 0.2, 0), Params)
	end

	return if Hit and Hit.Normal.Y >= 0.45 then Hit else nil
end

function RagdollImpactController:Step()
	for Character, State in Active do
		if not Character:IsDescendantOf(workspace) or not Character:GetAttribute("Ragdoll") then
			self:Stop(Character)
			continue
		end
		if os.clock() - State.LastSound < Config.ImpactSoundCooldown then
			continue
		end

		for _, Motion in State.Motions do
			if not Motion.Part.Parent or Motion.Velocity.Y > -Config.ImpactMinSpeed then
				continue
			end
			local Hit = GroundContact(Motion, State.Params)
			if not Hit then
				continue
			end
			local GroundVelocity = if Hit.Instance:IsA("BasePart")
				then Hit.Instance:GetVelocityAtPosition(Hit.Position)
				else Vector3.zero
			if -(Motion.Velocity - GroundVelocity):Dot(Hit.Normal) >= Config.ImpactMinSpeed then
				self:PlayImpact(State, Motion.Part)
				break
			end
		end
	end
end

function RagdollImpactController:Stop(Character: Model)
	Active[Character] = nil
	if next(Active) == nil then
		if PreConnection then
			PreConnection:Disconnect()
			PreConnection = nil
		end
		if PostConnection then
			PostConnection:Disconnect()
			PostConnection = nil
		end
	end
end

function RagdollImpactController:Start(Character: Model)
	if Active[Character] then
		return
	end
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Character }
	Params.RespectCanCollide = true
	Active[Character] = {
		Character = Character,
		Params = Params,
		Motions = {},
		LastSound = -math.huge,
	}
	if not PreConnection then
		PreConnection = RunService.PreSimulation:Connect(function()
			self:CaptureMotion()
		end)
		PostConnection = RunService.PostSimulation:Connect(function()
			self:Step()
		end)
	end
end

function RagdollImpactController:BindCharacter(Character: Model)
	if Bound[Character] then
		return
	end
	Bound[Character] = Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if Character:GetAttribute("Ragdoll") then
			self:Start(Character)
		else
			self:Stop(Character)
		end
	end)
	if Character:GetAttribute("Ragdoll") then
		self:Start(Character)
	end
end

function RagdollImpactController:UnbindCharacter(Character: Model)
	self:Stop(Character)
	local Connection = Bound[Character]
	if Connection then
		Connection:Disconnect()
		Bound[Character] = nil
	end
end

local function BindEntity(Object: Instance)
	if Object:IsA("Model") then
		RagdollImpactController:BindCharacter(Object)
	end
end

function RagdollImpactController.KnitStart()
	CollectionService:GetInstanceAddedSignal("Entity"):Connect(BindEntity)
	CollectionService:GetInstanceRemovedSignal("Entity"):Connect(function(Object: Instance)
		if Object:IsA("Model") then
			-- Streaming out also removes the tag locally without destroying the model.
			RagdollImpactController:UnbindCharacter(Object)
		end
	end)

	for _, Object in CollectionService:GetTagged("Entity") do
		BindEntity(Object)
	end
end

return RagdollImpactController
