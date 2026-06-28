local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local StoryCompassController = Knit.CreateController({
	Name = "StoryCompassController",
})

local Player = Players.LocalPlayer

local COMPASS_SPAN = 120
local TICK_STEP = 15
local METERS_PER_STUD = 0.28
local TARGET_ICON = "rbxassetid://96120410967337"

local GOLD = Color3.fromRGB(218, 173, 86)
local WHITE = Color3.fromRGB(255, 255, 255)
local MUTED = Color3.fromRGB(173, 169, 160)

local CompassTargets = {}
local TargetMarkers = {}
local TickFrames = {}

local CompassGui: ScreenGui
local Container: Frame
local CompassBar: Frame
local Ticks: Frame
local Markers: Frame

local QuestTargetController

local function Create(ClassName: string, Properties, Parent: Instance?)
	local Object = Instance.new(ClassName)
	for Property, Value in Properties do
		Object[Property] = Value
	end
	Object.Parent = Parent
	return Object
end

local function BuildInterface()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Existing = PlayerGui:FindFirstChild("Compass") or PlayerGui:FindFirstChild("StoryCompass")
	if Existing then
		Existing:Destroy()
	end

	CompassGui = Create("ScreenGui", {
		Name = "Compass",
		DisplayOrder = 25,
		IgnoreGuiInset = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, PlayerGui)

	Container = Create("Frame", {
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0.52, 0, 0, 48),
		BackgroundTransparency = 1,
		Visible = true,
	}, CompassGui)

	Create("UISizeConstraint", {
		MinSize = Vector2.new(320, 48),
		MaxSize = Vector2.new(680, 48),
	}, Container)

	CompassBar = Create("Frame", {
		Name = "CompassBar",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, Container)

	Ticks = Create("Frame", {
		Name = "Ticks",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, CompassBar)

	for Index = 1, 11 do
		local Tick = Create("Frame", {
			Name = "Tick" .. Index,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(48, 26),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, Ticks)
		TickFrames[Index] = Tick

		Create("Frame", {
			Name = "Line",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(1, 6),
			BorderSizePixel = 0,
			BackgroundColor3 = MUTED,
			BackgroundTransparency = 0.35,
			ZIndex = 2,
		}, Tick)

		Create("TextLabel", {
			Name = "Direction",
			Position = UDim2.fromOffset(0, 7),
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Text = "N",
			TextColor3 = WHITE,
			TextSize = 15,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0.1,
			ZIndex = 2,
		}, Tick)
	end

	Markers = Create("Frame", {
		Name = "Targets",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, CompassBar)
end

local function NormalizeAngle(Angle: number): number
	return (Angle % 360 + 360) % 360
end

local function NormalizeDelta(Angle: number): number
	return (Angle + 180) % 360 - 180
end

local function BearingFromVector(Direction: Vector3): number
	return NormalizeAngle(math.deg(math.atan2(Direction.X, -Direction.Z)))
end

local Directions = {
	[0] = "N",
	[45] = "NE",
	[90] = "E",
	[135] = "SE",
	[180] = "S",
	[225] = "SW",
	[270] = "W",
	[315] = "NW",
}

local function RenderTicks(CameraBearing: number)
	local FirstAngle = math.floor((CameraBearing - COMPASS_SPAN / 2) / TICK_STEP) * TICK_STEP

	for Index, Tick in TickFrames do
		local Angle = FirstAngle + (Index - 1) * TICK_STEP
		local Delta = NormalizeDelta(Angle - CameraBearing)
		local Visible = math.abs(Delta) <= COMPASS_SPAN / 2 + 1
		Tick.Visible = Visible

		if Visible then
			local Normalized = math.round(NormalizeAngle(Angle))
			local Direction = Directions[Normalized]
			local Label = Tick.Direction
			Tick.Position = UDim2.new(0.5 + Delta / COMPASS_SPAN, 0, 0, 0)
			Label.Text = Direction or ""
			Label.TextColor3 = WHITE
			Label.TextSize = 15
			Tick.Line.Size = UDim2.fromOffset(if Direction then 2 else 1, if Direction then 8 else 5)
			Tick.Line.BackgroundColor3 = if Direction then GOLD else MUTED
		end
	end
end

local function GetWorldPosition(Target: BillboardGui): Vector3?
	local Adornee = Target.Adornee or Target.Parent
	if not Adornee then
		return nil
	end

	if Adornee:IsA("Attachment") then
		return Adornee.WorldPosition
	elseif Adornee:IsA("BasePart") then
		return Adornee.Position
	elseif Adornee:IsA("Model") then
		return Adornee:GetPivot().Position
	end

	return nil
end

local function CreateTargetMarker(Title: string): Frame
	local Marker = Create("Frame", {
		Name = Title,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(90, 47),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, Markers)

	Create("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Image = TARGET_ICON,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 5,
	}, Marker)

	Create("TextLabel", {
		Name = "TextIcon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.fromOffset(32, 32),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "?",
		TextColor3 = GOLD,
		TextSize = 28,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.1,
		Visible = false,
		ZIndex = 5,
	}, Marker)

	Create("TextLabel", {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 28),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "0 M",
		TextColor3 = GOLD,
		TextSize = 12,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
	}, Marker)

	TargetMarkers[Title] = Marker
	return Marker
end

local function RenderTargets(CameraBearing: number, Origin: Vector3)
	local NearestByTitle = {}

	for Target in CompassTargets do
		if not Target.Parent then
			CompassTargets[Target] = nil
			continue
		end

		local Position = GetWorldPosition(Target)
		if not Position or Target.Name:find("DONTSHOW") then
			continue
		end

		local FlatOffset = Vector3.new(Position.X - Origin.X, 0, Position.Z - Origin.Z)
		local Distance = FlatOffset.Magnitude
		local MaxDistance = Target:GetAttribute("CompassMaxDistance")
		if typeof(MaxDistance) == "number" and Distance > MaxDistance then
			continue
		end
		local Previous = NearestByTitle[Target.Name]
		if Distance > 0.01 and (not Previous or Distance < Previous.Distance) then
			NearestByTitle[Target.Name] = {
				Distance = Distance,
				Bearing = BearingFromVector(FlatOffset),
				Mode = Target:GetAttribute("CompassMode"),
				Label = Target:GetAttribute("CompassLabel"),
				IconText = Target:GetAttribute("CompassIconText"),
				IconImage = Target:GetAttribute("CompassIconImage"),
			}
		end
	end

	for Title, Marker in TargetMarkers do
		Marker.Visible = NearestByTitle[Title] ~= nil
	end

	for Title, TargetData in NearestByTitle do
		local Marker = TargetMarkers[Title] or CreateTargetMarker(Title)
		local Delta = NormalizeDelta(TargetData.Bearing - CameraBearing)
		local MarkerWidth = if TargetData.Mode == "MissionName" then 180 else 90
		local CompassWidth = math.max(CompassBar.AbsoluteSize.X, MarkerWidth)
		local EdgeMargin = MarkerWidth / 2 / CompassWidth
		local PositionScale = math.clamp(0.5 + Delta / COMPASS_SPAN, EdgeMargin, 1 - EdgeMargin)

		Marker.Visible = true
		Marker.Position = UDim2.new(PositionScale, 0, 0, 0)

		if TargetData.Mode == "MissionName" then
			Marker.Size = UDim2.fromOffset(180, 47)
			Marker.Icon.Visible = true
			Marker.Icon.Image = TARGET_ICON
			Marker.TextIcon.Visible = false
			Marker.Icon.Position = UDim2.new(0.5, 0, 0, 0)
			Marker.Icon.Size = UDim2.fromOffset(24, 24)
			Marker.Label.Position = UDim2.new(0.5, 0, 0, 25)
			Marker.Label.Size = UDim2.new(1, 0, 0, 22)
			Marker.Label.Text = TargetData.Label or Title
			Marker.Label.TextColor3 = GOLD
			Marker.Label.TextSize = 14
		else
			Marker.Size = UDim2.fromOffset(90, 47)
			Marker.Icon.Visible = TargetData.IconText == nil
			Marker.Icon.Image = TargetData.IconImage or TARGET_ICON
			Marker.TextIcon.Visible = TargetData.IconText ~= nil
			Marker.TextIcon.Text = TargetData.IconText or ""
			Marker.Icon.Position = UDim2.new(0.5, 0, 0, 0)
			Marker.Icon.Size = UDim2.fromOffset(28, 28)
			Marker.Label.Position = UDim2.new(0.5, 0, 0, 28)
			Marker.Label.Size = UDim2.new(1, 0, 0, 18)
			Marker.Label.Text = string.format("%d M", math.floor(TargetData.Distance * METERS_PER_STUD))
			Marker.Label.TextColor3 = GOLD
			Marker.Label.TextSize = 12
		end
	end
end

local function AddTarget(Target: BillboardGui)
	CompassTargets[Target] = true
end

local function RemoveTarget(Target: BillboardGui)
	CompassTargets[Target] = nil
end

function StoryCompassController.KnitStart()
	BuildInterface()

	QuestTargetController = require(script.Parent.Parent:WaitForChild("QuestTargetController"))

	QuestTargetController.TargetAdded:Connect(AddTarget)
	QuestTargetController.TargetRemoved:Connect(RemoveTarget)
	for _, Target in QuestTargetController:GetTargets() do
		AddTarget(Target)
	end

	RunService.RenderStepped:Connect(function()
		local Camera = workspace.CurrentCamera
		local Character = Player.Character
		if not Camera or not Character then
			return
		end

		local Origin = Character:GetPivot().Position
		local LookVector = Camera.CFrame.LookVector
		local FlatLook = Vector3.new(LookVector.X, 0, LookVector.Z)
		if FlatLook.Magnitude < 0.01 then
			return
		end

		local CameraBearing = BearingFromVector(FlatLook)
		RenderTicks(CameraBearing)
		RenderTargets(CameraBearing, Origin)
	end)
end

return StoryCompassController
