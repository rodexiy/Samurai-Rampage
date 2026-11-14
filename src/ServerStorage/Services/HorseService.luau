local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local HorseGrounding = require(ReplicatedStorage.Shared.HorseGrounding)

local HorseService = Knit.CreateService({
	Name = "HorseService",
	Client = {
		Request = Knit.CreateSignal(),
	},
})

type PartState = { CanCollide: boolean, Massless: boolean }
type RiderState = {
	Character: Model,
	Humanoid: Humanoid,
	AutoRotate: boolean,
	PlatformStand: boolean,
	Parts: { [BasePart]: PartState },
	Weld: Weld,
}
type HorseState = {
	Model: Model,
	Root: BasePart,
	Prompt: ProximityPrompt,
	Velocity: LinearVelocity,
	Orientation: AlignOrientation,
	Tier: number,
	Rider: RiderState?,
	LastPosition: Vector3,
	LastCheck: number,
	LastLook: number,
	Grounding: HorseGrounding.State,
}

local Horses: { [Player]: HorseState } = {}
local LastSpawn: { [Player]: number } = {}
local HorseFolder: Folder
local LookEvent: UnreliableRemoteEvent
local DataService

local function GetGroundParams(Character: Model): RaycastParams
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Character, HorseFolder }
	Params.RespectCanCollide = true

	return Params
end

local function GetWorldBounds(Model: Model): (CFrame, Vector3)
	local Bounds, Size = Model:GetBoundingBox()
	local Minimum = Vector3.new(math.huge, math.huge, math.huge)
	local Maximum = -Minimum

	-- Imported horse pivots are rotated 90 degrees; physics uses upright world axes.
	for X = -1, 1, 2 do
		for Y = -1, 1, 2 do
			for Z = -1, 1, 2 do
				local Corner = Bounds:PointToWorldSpace(Size * Vector3.new(X, Y, Z) * 0.5)
				Minimum = Minimum:Min(Corner)
				Maximum = Maximum:Max(Corner)
			end
		end
	end

	return CFrame.new((Minimum + Maximum) * 0.5), Maximum - Minimum
end

local function WeldParts(Root: BasePart, Part: BasePart)
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = Root
	Weld.Part1 = Part
	Weld.Parent = Root
end

local function CreatePhysics(Model: Model): (BasePart, LinearVelocity, AlignOrientation, Vector3)
	local Bounds, Size = GetWorldBounds(Model)
	local RigRoot = Model.PrimaryPart

	for _, Part in Model:QueryDescendants("BasePart") :: { BasePart } do
		Part.Anchored = false
		Part.CanCollide = false
		Part.CanTouch = false
		Part.Massless = true
	end

	local Root = Instance.new("Part")
	Root.Name = "MountRoot"
	Root.Size = Vector3.new(Size.X * 0.8, Size.Y * 0.55, Size.Z * 0.6)
	Root.CFrame = Bounds
	Root.Transparency = 1
	Root.RootPriority = 127
	Root.CanTouch = false
	Root.CollisionGroup = HorseConfig.Grounding.CollisionGroup
	Root.CustomPhysicalProperties = PhysicalProperties.new(1, 0.2, 0, 1, 1)
	Root.Parent = Model

	if RigRoot then
		WeldParts(Root, RigRoot)
	else
		for _, Part in Model:QueryDescendants("BasePart") :: { BasePart } do
			if Part ~= Root then
				WeldParts(Root, Part)
			end
		end
	end

	Model.PrimaryPart = Root
	Model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	Model:SetAttribute("GroundClearance", Size.Y * 0.5)
	Model:SetAttribute("GroundHalfWidth", Size.X * 0.3)
	Model:SetAttribute("GroundHalfLength", Size.Z * 0.26)

	local Attachment = Instance.new("Attachment")
	Attachment.Name = "MountAttachment"
	Attachment.Parent = Root

	local Velocity = Instance.new("LinearVelocity")
	Velocity.Name = "MountVelocity"
	Velocity.Attachment0 = Attachment
	Velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	Velocity.PrimaryTangentAxis = Vector3.xAxis
	Velocity.SecondaryTangentAxis = Vector3.zAxis
	Velocity.ForceLimitsEnabled = true
	Velocity.MaxForce = Root.AssemblyMass * HorseConfig.PhysicsAcceleration
	Velocity.Enabled = true
	Velocity.Parent = Root

	local GroundVelocity = Instance.new("LinearVelocity")
	GroundVelocity.Name = "MountGroundVelocity"
	GroundVelocity.Attachment0 = Attachment
	GroundVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	GroundVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	GroundVelocity.LineDirection = Vector3.yAxis
	GroundVelocity.ForceLimitsEnabled = true
	GroundVelocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	GroundVelocity.MaxForce = Root.AssemblyMass * (workspace.Gravity + HorseConfig.Grounding.SupportAcceleration)
	GroundVelocity.Enabled = false
	GroundVelocity.Parent = Root

	local Orientation = Instance.new("AlignOrientation")
	Orientation.Name = "MountOrientation"
	Orientation.Attachment0 = Attachment
	Orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	Orientation.MaxTorque = math.huge
	Orientation.MaxAngularVelocity = 10
	Orientation.Responsiveness = 20
	Orientation.Parent = Root

	return Root, Velocity, Orientation, Size
end

function HorseService:Dismount(Player: Player)
	local State = Horses[Player]
	local Rider = State and State.Rider
	if not State or not Rider then
		return
	end

	State.Rider = nil
	State.Model:SetAttribute("RiderLookDirection", nil)
	State.Model:SetAttribute("RiderLookTime", nil)
	Rider.Weld:Destroy()
	Rider.Character:SetAttribute("Mounted", nil)
	Rider.Character:SetAttribute("InHorse", false)
	State.Model:SetAttribute("RiderUserId", nil)
	State.Velocity.Enabled = true
	State.Velocity.PlaneVelocity = Vector2.zero
	State.Orientation.CFrame = State.Root.CFrame.Rotation
	State.Root.AssemblyLinearVelocity = Vector3.new(0, State.Root.AssemblyLinearVelocity.Y, 0)
	State.Root.AssemblyAngularVelocity = Vector3.zero
	HorseGrounding.Reset(State.Grounding)
	HorseGrounding.Update(State.Grounding, 0)
	if State.Root:IsDescendantOf(workspace) then
		State.Root:SetNetworkOwner(nil)
	end
	State.Prompt.Enabled = true

	local CharacterRoot = Rider.Character.PrimaryPart
	if CharacterRoot and Rider.Character.Parent then
		local Params = GetGroundParams(Rider.Character)
		local Offset = State.Root.Size.X * 0.5 + 3

		for _, Sign in { 1, -1 } do
			local Direction = State.Root.CFrame.RightVector * Offset * Sign
			if workspace:Raycast(State.Root.Position, Direction, Params) then
				continue
			end

			local Position = State.Root.Position + Direction
			local GroundDistance = State.Root.Size.Y + Rider.Humanoid.HipHeight + CharacterRoot.Size.Y
			local Ground = workspace:Raycast(Position, -Vector3.yAxis * GroundDistance, Params)
			if Ground and Ground.Normal.Y >= HorseConfig.MinimumGroundNormal then
				Position = Ground.Position + Vector3.yAxis * (Rider.Humanoid.HipHeight + CharacterRoot.Size.Y * 0.5 + 0.5)
			end

			local Heading = HorseGrounding.HorizontalDirection(State.Root.CFrame.LookVector)
			CharacterRoot.CFrame = CFrame.lookAt(Position, Position + Heading)
			break
		end

		CharacterRoot.AssemblyLinearVelocity = Vector3.zero
		CharacterRoot.AssemblyAngularVelocity = Vector3.zero
		if CharacterRoot:IsDescendantOf(workspace) then
			CharacterRoot:SetNetworkOwnershipAuto()
		end
	end

	for Part, Original in Rider.Parts do
		if Part.Parent then
			Part.CanCollide = Original.CanCollide
			Part.Massless = Original.Massless
		end
	end

	Rider.Humanoid.AutoRotate = Rider.AutoRotate
	Rider.Humanoid.PlatformStand = Rider.PlatformStand
end

function HorseService:Mount(Player: Player, Model: Model)
	local State = Horses[Player]
	local Character = Player.Character
	if not State or State.Model ~= Model or State.Rider or not Character then
		return
	end

	if not State.Prompt.Enabled or not HorseConfig.CanMount(Character) then
		return
	end

	local Root = Character.PrimaryPart
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if not Root or not Humanoid or (Root.Position - State.Root.Position).Magnitude > HorseConfig.MountDistance then
		return
	end

	local Params = GetGroundParams(Character)
	if workspace:Raycast(Root.Position, State.Root.Position - Root.Position, Params) then
		return
	end

	local Parts: { [BasePart]: PartState } = {}
	for _, Part in Character:QueryDescendants("BasePart") :: { BasePart } do
		Parts[Part] = { CanCollide = Part.CanCollide, Massless = Part.Massless }
		Part.CanCollide = false
		Part.Massless = true
	end

	local AutoRotate = Humanoid.AutoRotate
	local PlatformStand = Humanoid.PlatformStand
	Character:SetAttribute("InHorse", true)
	Humanoid.AutoRotate = false
	Humanoid.PlatformStand = true
	Humanoid.Jump = false
	Character:SetAttribute("Running", false)
	HorseGrounding.Reset(State.Grounding)
	Root.CFrame = State.Root.CFrame * HorseConfig.RiderOffset

	local Weld = Instance.new("Weld")
	Weld.Name = "RiderWeld"
	Weld.Part0 = State.Root
	Weld.Part1 = Root
	Weld.C0 = HorseConfig.RiderOffset
	Weld.C1 = CFrame.identity
	Weld.Parent = State.Root
	State.Rider = {
		Character = Character, Humanoid = Humanoid, AutoRotate = AutoRotate,
		PlatformStand = PlatformStand, Parts = Parts, Weld = Weld,
	}
	State.LastLook = -math.huge

	State.Prompt.Enabled = false
	State.LastPosition = State.Root.Position
	State.LastCheck = os.clock()
	State.Velocity.MaxForce = State.Root.AssemblyMass * HorseConfig.PhysicsAcceleration
	State.Root:SetNetworkOwner(Player)
	State.Model:SetAttribute("RiderUserId", Player.UserId)
	Character:SetAttribute("Mounted", true)
end

function HorseService:Despawn(Player: Player)
	local State = Horses[Player]
	if not State then
		return
	end

	self:Dismount(Player)
	Horses[Player] = nil
	State.Model:Destroy()
end

function HorseService:GetTier(Player: Player): number
	local Data = DataService:GetData(Player)
	local Tier = Data and Data.HorseTier

	return if typeof(Tier) == "number" and HorseConfig.GetTier(Tier) then Tier else HorseConfig.DefaultTier
end

function HorseService:SetTier(Player: Player, Tier: any): (boolean, string?)
	if typeof(Tier) ~= "number" or Tier % 1 ~= 0 or not HorseConfig.GetTier(Tier) then
		return false, "Invalid horse level. Choose a level from 1 to " .. tostring(#HorseConfig.Tiers) .. "."
	end

	local Data = DataService:GetData(Player)
	if not Data then
		return false, "Player data is not ready."
	end

	if Data.HorseTier ~= Tier then
		Data.HorseTier = Tier
		self:Despawn(Player)
	end

	return true
end

-- Tier is chosen by server code only; requests from clients never accept a tier.
function HorseService:Spawn(Player: Player, Tier: number?)
	local Character = Player.Character
	local Existing = Horses[Player]
	if Existing and Existing.Rider then
		self:Dismount(Player)
		return
	end

	if not Character or not HorseConfig.CanMount(Character) or Character:GetAttribute("Loaded") ~= true then
		return
	end

	local Now = os.clock()
	if Now - (LastSpawn[Player] or -math.huge) < HorseConfig.SpawnCooldown then
		return
	end
	LastSpawn[Player] = Now

	local HorseTier = Tier or self:GetTier(Player)
	local Stats = HorseConfig.GetTier(HorseTier)
	if not Stats then
		return
	end

	local Template = ReplicatedStorage.Assets.Models.Horses:FindFirstChild(Stats.ModelName) :: Model?
	local CharacterRoot = Character.PrimaryPart
	if not Template or not Template:IsA("Model") or not CharacterRoot then
		return
	end

	local Direction = CharacterRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	Direction = if Direction.Magnitude > 0.01 then Direction.Unit else -Vector3.zAxis
	local Position = CharacterRoot.Position + Direction * HorseConfig.SpawnDistance
	local Params = GetGroundParams(Character)
	if workspace:Raycast(CharacterRoot.Position, Direction * HorseConfig.SpawnDistance, Params) then
		return
	end

	local Ground = workspace:Raycast(
		Position + Vector3.yAxis * HorseConfig.GroundProbeHeight,
		-Vector3.yAxis * (HorseConfig.GroundProbeHeight + HorseConfig.GroundProbeDepth), Params
	)
	if not Ground or Ground.Material == Enum.Material.Water or not HorseGrounding.IsWalkable(Ground.Normal) then
		return
	end

	local Model = Template:Clone()
	local Root, Velocity, Orientation, Size = CreatePhysics(Model)
	Position = Ground.Position + Vector3.yAxis * (Size.Y * 0.5 + 0.25)
	Model:PivotTo(CFrame.lookAt(Position, Position + Direction))
	Orientation.CFrame = Root.CFrame.Rotation

	local Overlap = OverlapParams.new()
	Overlap.FilterType = Enum.RaycastFilterType.Exclude
	Overlap.FilterDescendantsInstances = { Character, HorseFolder }
	Overlap.RespectCanCollide = true
	if #workspace:GetPartBoundsInBox(Root.CFrame, Size - Vector3.one * 0.2, Overlap) > 0 then
		Model:Destroy()
		return
	end

	self:Despawn(Player)
	Model.Name = "Horse_" .. Player.UserId
	Model:SetAttribute("OwnerUserId", Player.UserId)
	Model:SetAttribute("HorseTier", HorseTier)
	Model:SetAttribute("GaitEpoch", workspace:GetServerTimeNow())

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "MountPrompt"
	Prompt.ActionText = "Mount"
	Prompt.ObjectText = Stats.ModelName
	Prompt.KeyboardKeyCode = Enum.KeyCode.E
	Prompt.MaxActivationDistance = HorseConfig.MountDistance
	Prompt.RequiresLineOfSight = false
	Prompt.Style = Enum.ProximityPromptStyle.Custom
	Prompt.Parent = Root
	Prompt.Triggered:Connect(function(TriggeringPlayer: Player)
		self:Mount(TriggeringPlayer, Model)
	end)

	Model.Parent = HorseFolder
	local Grounding = assert(HorseGrounding.Create(Model), "Horse grounding constraints are missing")
	Horses[Player] = {
		Model = Model, Root = Root, Prompt = Prompt, Velocity = Velocity,
		Orientation = Orientation, Tier = HorseTier, LastPosition = Root.Position, LastCheck = Now, LastLook = -math.huge, Grounding = Grounding,
	}
	Root:SetNetworkOwner(nil)
	HorseGrounding.Update(Grounding, 0)
	CollectionService:AddTag(Model, HorseConfig.Tag)
end

local function ValidateRider(Player: Player, State: HorseState, Now: number)
	local Rider = State.Rider
	if not Rider then
		return
	end

	if Player.Character ~= Rider.Character or not Rider.Character.Parent or Rider.Humanoid.Health <= 0 then
		HorseService:Despawn(Player)
		return
	end

	for _, Attribute in HorseConfig.BlockedAttributes do
		if Rider.Character:GetAttribute(Attribute) then
			HorseService:Dismount(Player)
			return
		end
	end

	local Position = State.Root.Position
	local Distance = ((Position - State.LastPosition) * Vector3.new(1, 0, 1)).Magnitude
	local Stats = HorseConfig.GetTier(State.Tier)
	if not Stats then
		HorseService:Despawn(Player)
		return
	end

	local MaximumDistance = Stats.Speed * (Now - State.LastCheck) + HorseConfig.PositionTolerance
	if Position.X ~= Position.X or Position.Y ~= Position.Y or Position.Z ~= Position.Z
		or math.abs(Position.X) == math.huge or math.abs(Position.Y) == math.huge or math.abs(Position.Z) == math.huge
		or Distance > MaximumDistance
	then
		State.Model:PivotTo(CFrame.new(State.LastPosition) * State.Orientation.CFrame)
		HorseService:Dismount(Player)
		return
	end

	State.LastPosition = Position
	State.LastCheck = Now
end

function HorseService:UpdateRiderLook(Player: Player, Direction: any)
	local State = Horses[Player]
	if not State or not State.Rider or State.Rider.Character ~= Player.Character or typeof(Direction) ~= "Vector3" then
		return
	end
	local Magnitude = Direction.Magnitude
	if Magnitude ~= Magnitude or Magnitude < 0.5 or Magnitude > 2
		or (State.Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > HorseConfig.Animation.RiderLook.MaximumSpeed then
		return
	end
	local Now = os.clock()
	if Now - State.LastLook < HorseConfig.Animation.RiderLook.Interval * 0.75 then
		return
	end
	State.LastLook = Now
	State.Model:SetAttribute("RiderLookDirection", Direction.Unit)
	State.Model:SetAttribute("RiderLookTime", workspace:GetServerTimeNow())
end

function HorseService.KnitInit()
	DataService = Knit.GetService("DataService")

	local Events = ReplicatedStorage.Assets:FindFirstChild("Events")
	if not Events then
		Events = Instance.new("Folder")
		Events.Name = "Events"
		Events.Parent = ReplicatedStorage.Assets
	end
	LookEvent = Events:FindFirstChild("HorseLook") :: UnreliableRemoteEvent?
	if not LookEvent then
		LookEvent = Instance.new("UnreliableRemoteEvent")
		LookEvent.Name = "HorseLook"
		LookEvent.Parent = Events
	end
end

function HorseService.KnitStart()
	LookEvent.OnServerEvent:Connect(function(Player: Player, Direction: any)
		HorseService:UpdateRiderLook(Player, Direction)
	end)
	local GroupName = HorseConfig.Grounding.CollisionGroup
	if not PhysicsService:IsCollisionGroupRegistered(GroupName) then
		PhysicsService:RegisterCollisionGroup(GroupName)
	end
	for _, Group in PhysicsService:GetRegisteredCollisionGroups() do
		PhysicsService:CollisionGroupSetCollidable(GroupName, Group.name, table.find(HorseConfig.Grounding.CharacterGroups, Group.name) ~= nil)
	end

	HorseFolder = Instance.new("Folder")
	HorseFolder.Name = "Horses"
	HorseFolder.Parent = workspace

	HorseService.Client.Request:Connect(function(Player: Player, Action: string)
		if Action == "Spawn" then
			HorseService:Spawn(Player)
		elseif Action == "Dismount" then
			HorseService:Dismount(Player)
		end
	end)

	local function TrackPlayer(Player: Player)
		local function TrackCharacter(Character: Model)
			Character:SetAttribute("InHorse", false)
		end

		Player.CharacterAdded:Connect(TrackCharacter)
		if Player.Character then
			TrackCharacter(Player.Character)
		end

		Player.CharacterRemoving:Connect(function()
			HorseService:Despawn(Player)
		end)
	end

	Players.PlayerAdded:Connect(TrackPlayer)
	for _, Player in Players:GetPlayers() do
		TrackPlayer(Player)
	end

	Players.PlayerRemoving:Connect(function(Player: Player)
		HorseService:Despawn(Player)
		LastSpawn[Player] = nil
	end)

	local Elapsed = 0
	RunService.PreSimulation:Connect(function(DeltaTime: number)
		for _, State in Horses do
			if not State.Rider and State.Root:IsDescendantOf(workspace) then
				HorseGrounding.Update(State.Grounding, DeltaTime)
			end
		end
	end)
	RunService.PostSimulation:Connect(function()
		for _, State in Horses do
			if not State.Rider and State.Root:IsDescendantOf(workspace) then
				HorseGrounding.Update(State.Grounding, 0)
			end
		end
	end)

	RunService.Heartbeat:Connect(function(DeltaTime: number)
		Elapsed += DeltaTime
		if Elapsed < HorseConfig.ValidationInterval then
			return
		end
		Elapsed = 0

		local Now = os.clock()
		for Player, State in Horses do
			if not State.Model.Parent or State.Root.Position.Y < workspace.FallenPartsDestroyHeight + 20 then
				HorseService:Despawn(Player)
			else
				ValidateRider(Player, State, Now)
			end
		end
	end)
end

return HorseService
