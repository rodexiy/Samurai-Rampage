local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.DoorConfig)

local DoorService = Knit.CreateService({
	Name = "DoorService",
	Client = {
		Moved = Knit.CreateSignal(),
		Broken = Knit.CreateSignal(),
	},
})

local MOVE_DURATION = 0.9
local INTERACTION_COOLDOWN = 1
local INTERACTION_TAGS = { "Door", "Windows" }
local PANEL_TAG = "DoorPanel"
local PROMPT_NAME = "DoorPrompt"
local BoundContainers: { [Model]: boolean } = setmetatable({}, { __mode = "k" })
local DoorImpactService
local KnockbackService

type PanelState = {
	BoundsOffset: CFrame,
	Size: Vector3,
	Start: CFrame,
	Target: CFrame,
	StartedAt: number,
	Duration: number,
}

local Panels: { [Model]: PanelState } = setmetatable({}, { __mode = "k" })

function DoorService:GetCurrentPivot(Door: Model): CFrame
	local State = Panels[Door]
	if not State then
		return Door:GetPivot()
	end

	local Alpha = if State.Duration > 0
		then math.clamp((workspace:GetServerTimeNow() - State.StartedAt) / State.Duration, 0, 1)
		else 1
	return State.Start:Lerp(State.Target, TweenService:GetValue(Alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
end

local function EncodeMotion(Start: CFrame, Target: CFrame, StartedAt: number, Duration: number): string
	return HttpService:JSONEncode({
		Start = { Start:GetComponents() },
		Target = { Target:GetComponents() },
		StartedAt = StartedAt,
		Duration = Duration,
	})
end

local function PivotsMatch(First: CFrame, Second: CFrame): boolean
	local Difference = First:ToObjectSpace(Second)
	local _, Angle = Difference:ToAxisAngle()
	return Difference.Position.Magnitude < 0.01 and math.abs(Angle) < 0.001
end

function DoorService:RegisterDoor(Door: Model): boolean
	local OpenOffset = Door:GetAttribute("DoorOffset") or Door:GetAttribute("OpenOffset")
	if not Door.Parent or Door:GetAttribute("DoorBroken") or typeof(OpenOffset) ~= "CFrame" then
		return false
	end

	local Open = Door:GetAttribute("Open") == true
	local ClosedPivot = Door:GetAttribute("DoorClosedPivot")
	local Pivot = Door:GetPivot()
	local Rebase = typeof(ClosedPivot) ~= "CFrame"
		or (
			not Panels[Door]
			and not PivotsMatch(Pivot, ClosedPivot)
			and not PivotsMatch(Pivot, ClosedPivot * OpenOffset)
		)
	if Rebase then
		ClosedPivot = if Open then Pivot * OpenOffset:Inverse() else Pivot
		Door:SetAttribute("DoorClosedPivot", ClosedPivot)
	end

	if Rebase or typeof(Door:GetAttribute("DoorMotion")) ~= "string" then
		local Target = if Open then ClosedPivot * OpenOffset else ClosedPivot
		Door:SetAttribute("DoorMotion", EncodeMotion(Target, Target, 0, 0))
	end

	Door:SetAttribute("Open", Open)
	if not Panels[Door] then
		local Bounds, Size = Door:GetBoundingBox()
		local Target = if Open then ClosedPivot * OpenOffset else ClosedPivot
		Panels[Door] = {
			BoundsOffset = Door:GetPivot():ToObjectSpace(Bounds),
			Size = Size,
			Start = Target,
			Target = Target,
			StartedAt = 0,
			Duration = 0,
		}
	end
	if
		Door.ModelStreamingMode == Enum.ModelStreamingMode.Default
		or Door.ModelStreamingMode == Enum.ModelStreamingMode.Nonatomic
	then
		Door.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end

	-- Replicated tags let clients restore panels when joining or streaming in.
	Door:AddTag(PANEL_TAG)

	return true
end

function DoorService:BindDoor(Container: Instance)
	if not Container:IsA("Model") then
		return
	end

	if not BoundContainers[Container] then
		BoundContainers[Container] = true
		Container.ChildAdded:Connect(function(Child: Instance)
			if Child:IsA("Model") then
				self:RegisterDoor(Child)
			end
		end)
	end

	for _, Child in Container:GetChildren() do
		if Child:IsA("Model") then
			self:RegisterDoor(Child)
		end
	end

	if not Container.PrimaryPart then
		local Frame = Container:GetBoundingBox()
		local Anchor = Instance.new("Part")
		Anchor.Name = "DoorPromptAnchor"
		Anchor.Size = Vector3.one
		Anchor.CFrame = Frame
		Anchor.Anchored = true
		Anchor.Transparency = 1
		Anchor.CanCollide = false
		Anchor.CanTouch = false
		Anchor.CanQuery = false
		Anchor.Parent = Container
		Container.PrimaryPart = Anchor
	end

	local Prompt: ProximityPrompt? = nil
	for _, Child in Container:GetChildren() do
		if
			Child:IsA("ProximityPrompt") and (Child.Name == PROMPT_NAME or Child:GetAttribute("callback") == "OpenDoor")
		then
			Prompt = Child
			break
		end
	end

	if not Prompt then
		Prompt = Instance.new("ProximityPrompt")
		Prompt.Name = PROMPT_NAME
	end

	Prompt.ActionText = "Open / Close"
	Prompt.ObjectText = if Container:HasTag("Windows") then "Window" else "Door"
	Prompt.Style = Enum.ProximityPromptStyle.Custom
	Prompt.KeyboardKeyCode = Enum.KeyCode.F
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = 10
	Prompt.RequiresLineOfSight = false
	Prompt:SetAttribute("callback", "OpenDoor")
	Prompt.Parent = Container
end

function DoorService:SetOpen(Door: Model, Open: boolean): boolean
	if not self:RegisterDoor(Door) then
		return false
	end

	if Door:GetAttribute("Opening") or (Door:GetAttribute("Open") == true) == Open then
		return false
	end

	local OpenOffset = (Door:GetAttribute("DoorOffset") or Door:GetAttribute("OpenOffset")) :: CFrame
	local ClosedPivot = Door:GetAttribute("DoorClosedPivot") :: CFrame
	local OpenPivot = ClosedPivot * OpenOffset
	local StartCFrame = if Door:GetAttribute("Open") == true then OpenPivot else ClosedPivot
	local TargetCFrame = if Open then OpenPivot else ClosedPivot
	local Motion = EncodeMotion(StartCFrame, TargetCFrame, workspace:GetServerTimeNow(), MOVE_DURATION)
	local State = Panels[Door]
	State.Start = StartCFrame
	State.Target = TargetCFrame
	State.StartedAt = workspace:GetServerTimeNow()
	State.Duration = MOVE_DURATION
	Door:SetAttribute("Opening", true)
	Door:SetAttribute("Open", Open)
	-- One attribute keeps the complete transition together for late joiners.
	Door:SetAttribute("DoorMotion", Motion)

	self.Client.Moved:FireAll(Door, Motion)

	task.delay(INTERACTION_COOLDOWN, function()
		Door:SetAttribute("Opening", false)
	end)

	return true
end

function DoorService:OpenDoor(Door: Model): boolean
	return self:SetOpen(Door, true)
end

function DoorService:CloseDoor(Door: Model): boolean
	return self:SetOpen(Door, false)
end

function DoorService:ToggleDoor(Door: Model): boolean
	return self:SetOpen(Door, Door:GetAttribute("Open") ~= true)
end

function DoorService:ToggleDoors(Container: Instance)
	for _, Door in Container:GetChildren() do
		if Door:IsA("Model") then
			self:ToggleDoor(Door)
		end
	end
end

local function UpdatePrompt(Container: Instance)
	local Enabled = false
	for _, Child in Container:GetChildren() do
		if Child:IsA("Model") and Panels[Child] and not Child:GetAttribute("DoorBroken") then
			Enabled = true
			break
		end
	end

	for _, Child in Container:GetChildren() do
		if Child:IsA("ProximityPrompt") and Child:GetAttribute("callback") == "OpenDoor" then
			Child.Enabled = Enabled
		end
	end
end

local function ScheduleRespawn(Door: Model, Container: Instance)
	local Replacement = Door:Clone()
	Replacement:RemoveTag(PANEL_TAG)
	Replacement:SetAttribute("DoorMotion", nil)
	Replacement:SetAttribute("Opening", false)
	Replacement:SetAttribute("Open", false)
	Replacement:PivotTo(Door:GetAttribute("DoorClosedPivot") :: CFrame)

	-- The intact copy stays outside the DataModel while the broken panel is debris.
	task.delay(Config.RespawnDelay, function()
		if not Container:IsDescendantOf(workspace) then
			Replacement:Destroy()
			return
		end

		Replacement.Parent = Container
		DoorService:RegisterDoor(Replacement)
		UpdatePrompt(Container)
	end)
end

function DoorService:BreakDoor(
	Door: Model,
	Attacker: Model,
	Direction: Vector3,
	_Affected: { [Model]: boolean }
): boolean
	local Container = Door.Parent
	if
		not Container
		or not Container:HasTag("Door")
		or Door:GetAttribute("DoorBroken")
		or Door:GetAttribute("Open")
		or not Panels[Door]
	then
		return false
	end

	local Root = Door.PrimaryPart or Door:FindFirstChildWhichIsA("BasePart", true)
	if not Root or Direction.Magnitude <= 0.001 then
		return false
	end

	local Pivot = self:GetCurrentPivot(Door)
	ScheduleRespawn(Door, Container)
	Direction = Direction.Unit
	Door:SetAttribute("DoorBroken", true)
	Door:SetAttribute("Opening", false)
	Door:RemoveTag(PANEL_TAG)
	Panels[Door] = nil
	Door:PivotTo(Pivot)
	Door.PrimaryPart = Root

	local Collisions: { [BasePart]: boolean } = {}
	for _, Part: BasePart in Door:QueryDescendants("BasePart") do
		Collisions[Part] = Part.CanCollide
		Part.CanCollide = false
		Part.Anchored = true
	end

	-- Remove old hinges and any joint that pins this panel to its frame or the other side.
	for _, Joint in Container:QueryDescendants("JointInstance, WeldConstraint, Constraint") do
		local Part0: Instance?
		local Part1: Instance?
		if Joint:IsA("JointInstance") or Joint:IsA("WeldConstraint") then
			Part0, Part1 = Joint.Part0, Joint.Part1
		elseif Joint:IsA("Constraint") then
			Part0 = Joint.Attachment0 and Joint.Attachment0.Parent
			Part1 = Joint.Attachment1 and Joint.Attachment1.Parent
		end

		if
			Joint:IsDescendantOf(Door)
			or (Part0 and Part0:IsDescendantOf(Door))
			or (Part1 and Part1:IsDescendantOf(Door))
		then
			Joint:Destroy()
		end
	end

	Root.RootPriority = 127
	Root.Massless = false
	for Part in Collisions do
		if Part ~= Root then
			local Weld = Instance.new("WeldConstraint")
			Weld.Part0 = Root
			Weld.Part1 = Part
			Weld.Parent = Root
		end
	end

	-- Finish every weld before releasing any part, so the complete side is one assembly.
	for Part in Collisions do
		Part.Anchored = false
	end

	task.delay(Config.CollisionDelay, function()
		for Part, CanCollide in Collisions do
			if Part.Parent then
				Part.CanCollide = CanCollide
			end
		end
	end)

	if Root:CanSetNetworkOwnership() then
		Root:SetNetworkOwner(nil)
	end
	local Velocity = (Direction * Config.BreakSpeed + Vector3.new(0, Config.BreakUpSpeed, 0)) * Config.BreakImpulse
	Root.AssemblyLinearVelocity = Velocity
	Root.AssemblyAngularVelocity = Config.BreakSpin
	KnockbackService:Push(Door, Velocity, Config.CollisionDelay)
	DoorImpactService:Track(Door, Attacker)
	Debris:AddItem(Door, Config.DebrisLifetime)
	UpdatePrompt(Container)
	self.Client.Broken:FireAll(Door)
	return true
end

local function GetDoorPanel(Part: BasePart): Model?
	local Object: Instance? = Part.Parent
	while Object and Object ~= workspace do
		if
			Object:IsA("Model")
			and Object.Parent
			and Object.Parent:HasTag("Door")
			and typeof(Object:GetAttribute("DoorOffset") or Object:GetAttribute("OpenOffset")) == "CFrame"
		then
			return if Object:GetAttribute("DoorBroken") then nil else Object
		end

		Object = Object.Parent
	end

	return nil
end

function DoorService:TryKickPart(
	Attacker: Model,
	Hitbox: BasePart,
	Part: BasePart,
	Affected: { [Model]: boolean }
): boolean
	local Root = Attacker.PrimaryPart
	local Door = GetDoorPanel(Part)
	if not Root or not Door then
		return false
	end

	if not Panels[Door] and not self:RegisterDoor(Door) then
		return false
	end

	local LocalPosition = Part.CFrame:PointToObjectSpace(Hitbox.Position)
	local HalfSize = Part.Size / 2
	local Closest = Part.CFrame:PointToWorldSpace(
		Vector3.new(
			math.clamp(LocalPosition.X, -HalfSize.X, HalfSize.X),
			math.clamp(LocalPosition.Y, -HalfSize.Y, HalfSize.Y),
			math.clamp(LocalPosition.Z, -HalfSize.Z, HalfSize.Z)
		)
	)
	local Contact = self:GetCurrentPivot(Door):PointToWorldSpace(Door:GetPivot():PointToObjectSpace(Closest))
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Attacker, Hitbox, Door }
	Params.RespectCanCollide = true
	if workspace:Raycast(Root.Position, Contact - Root.Position, Params) then
		return false
	end

	return self:BreakDoor(Door, Attacker, Root.CFrame.LookVector, Affected)
end

function DoorService:BreakInHitbox(Attacker: Model, Hitbox: BasePart, Affected: { [Model]: boolean })
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Attacker, Hitbox }
	local Parts = workspace:GetPartsInPart(Hitbox, Params)
	for _, Part in Parts do
		local Door = GetDoorPanel(Part)
		if Door and (not Panels[Door] or PivotsMatch(self:GetCurrentPivot(Door), Door:GetPivot())) then
			self:TryKickPart(Attacker, Hitbox, Part, Affected)
		end
	end

	-- Sliding panels render their motion on clients. Query their current visual position separately.
	local OriginalCFrame = Hitbox.CFrame
	for Door, State in Panels do
		if not Door.Parent or not Door.Parent:HasTag("Door") then
			continue
		end

		local Pivot = self:GetCurrentPivot(Door)
		if PivotsMatch(Pivot, Door:GetPivot()) then
			continue
		end

		local Bounds = Pivot * State.BoundsOffset
		if
			(Bounds.Position - OriginalCFrame.Position).Magnitude
			> (Hitbox.Size.Magnitude + State.Size.Magnitude) / 2
		then
			continue
		end

		Hitbox.CFrame = Door:GetPivot() * Pivot:ToObjectSpace(OriginalCFrame)
		local DoorParams = OverlapParams.new()
		DoorParams.FilterType = Enum.RaycastFilterType.Include
		DoorParams.FilterDescendantsInstances = { Door }
		for _, Part in workspace:GetPartsInPart(Hitbox, DoorParams) do
			if self:TryKickPart(Attacker, Hitbox, Part, Affected) then
				break
			end
		end
	end
	Hitbox.CFrame = OriginalCFrame
end

function DoorService.KnitInit()
	DoorImpactService = Knit.GetService("DoorImpactService")
	KnockbackService = Knit.GetService("KnockbackService")
end

function DoorService.KnitStart()
	for _, Tag in INTERACTION_TAGS do
		CollectionService:GetInstanceAddedSignal(Tag):Connect(function(Container: Instance)
			DoorService:BindDoor(Container)
		end)

		for _, Container in CollectionService:GetTagged(Tag) do
			DoorService:BindDoor(Container)
		end
	end
end

return DoorService
