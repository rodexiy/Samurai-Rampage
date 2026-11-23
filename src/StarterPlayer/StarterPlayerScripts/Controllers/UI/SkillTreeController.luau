local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.SkillTreeConfig)
local Progression = require(ReplicatedStorage.Shared.SkillTreeProgression)

local SkillTreeController = Knit.CreateController({
	Name = "SkillTreeController",
})

local HotbarController

local SkillTreeService
local SkillTreesIndex = require(ReplicatedStorage.Shared.Index.SkillTrees)

local Trees = {}

local DEFAULT_SCALE = 20

local Player = Players.LocalPlayer

local PlayerGui
local Menu

local SkillTree
local Background
local Content
local Description

local InterligationTemplate
local NodeTemplate

local Camera = workspace.CurrentCamera

local BackgroundTween = nil

local NodesInfo = Progression.Index(Config.Trees)

type Branch = {
	Name: string,
	PointsRequired: number,
	Description: string,
	Layout: { X: number, Y: number },
	Stat: string,
	Passive: boolean?,
	Color: Color3?,

	Branches: { Branch }?,
}

local SelectedNodeName = nil

function UdimToVector(Udim: UDim2): Vector2
	return Vector2.new(Udim.X.Offset, Udim.Y.Offset)
end

function MultUdim2(Vector: UDim2, Scale: number): UDim2
	return UDim2.new(Vector.X.Scale * Scale, Vector.X.Offset * Scale, Vector.Y.Scale * Scale, Vector.Y.Offset * Scale)
end

function SkillTreeController:IsSkillUnlocked(SkillName: string): boolean
	if SkillName == "No Run Stamina Drain" or SkillName == "No Climb Stamina Drain" then
		SkillName = "Travel Breath"
	end
	local UnlockedNodes = Player:FindFirstChild("UnlockedNodes")
	if not UnlockedNodes then
		warn("Unlocked nodes missing!")
		return false
	end
	return UnlockedNodes:FindFirstChild(SkillName) ~= nil
end

function SkillTreeController:CheckUnlockButton()
	local NodeInfo = NodesInfo[SelectedNodeName]
	if not NodeInfo then
		Description.TextButton.Visible = false
		return
	end

	local Allowed, Reason = Progression.CanUnlock(self:GetLocalProgress(), NodeInfo.Name, NodesInfo)
	Description.TextButton.Visible = not self:IsSkillUnlocked(NodeInfo.Name)
	Description.TextButton.Active = Allowed
	Description.TextButton.AutoButtonColor = Allowed
	Description.TextButton.Text = if Allowed then "Unlock - " .. NodeInfo.PointsRequired .. " " .. NodeInfo.Stat .. " points" else "Locked"
	Description.Description.Text = NodeInfo.Description .. "\n\nCost: " .. NodeInfo.PointsRequired .. " " .. NodeInfo.Stat .. " points."
		.. (if not Allowed and not self:IsSkillUnlocked(NodeInfo.Name) then "\n" .. (Reason or "") else "")
end

function SkillTreeController:GetLocalProgress(): { [string]: any }
	local Data = { Stats = {}, UnlockedNodes = {} }
	for _, Stat in Config.Names do
		Data.Stats[Stat] = { Level = Player:GetAttribute(Stat .. "Level") or 0 }
	end

	local Folder = Player:FindFirstChild("UnlockedNodes")
	if Folder then
		for _, Node in Folder:GetChildren() do
			if NodesInfo[Node.Name] then
				table.insert(Data.UnlockedNodes, Node.Name)
			end
		end
	end

	return Data
end

function SkillTreeController:RefreshPoints()
	local Info = NodesInfo[SelectedNodeName] or SkillTreesIndex[SelectedNodeName]
	if Info then
		SkillTree.SkillPointsLeft.Text = tostring(Player:GetAttribute(Info.Stat .. "SkillPoints") or 0)
			.. " " .. Info.Stat:upper() .. " POINTS"
	else
		SkillTree.SkillPointsLeft.Text = "SELECT AN ATTRIBUTE TREE"
	end

	for _, Stat in Config.Names do
		local Root = Content:FindFirstChild(Stat) :: ImageButton?
		if Root then
			Root.Frame.TextLabel.Text = Stat .. "\n" .. tostring(Player:GetAttribute(Stat .. "SkillPoints") or 0) .. " points"
		end
	end
	self:CheckUnlockButton()
end

function SkillTreeController:RefreshNodes()
	local Data = self:GetLocalProgress()
	for Name in NodesInfo do
		local Node = Content:FindFirstChild(Name) :: ImageButton?
		local Learned = self:IsSkillUnlocked(Name)
		local Allowed = Progression.CanUnlock(Data, Name, NodesInfo)
		local Color = if Learned then Color3.new(1, 1, 1)
			elseif Allowed then Color3.fromRGB(160, 160, 160) else Color3.fromRGB(65, 65, 65)
		if Node then
			Node.ImageColor3 = Color
		end
	end
	for _, Line in Content:GetChildren() do
		local Target = Line:GetAttribute("TargetNode")
		local Required = Line:GetAttribute("RequiredNode")
		if Line:IsA("ImageLabel") and Target and Required then
			local Connected = self:IsSkillUnlocked(Required)
			Line.ImageColor3 = if Connected and self:IsSkillUnlocked(Target) then Color3.new(1, 1, 1)
				elseif Connected then Color3.fromRGB(160, 160, 160) else Color3.fromRGB(65, 65, 65)
		end
	end
	self:RefreshPoints()
end

function SkillTreeController:GetTrees()
	local TreesName = SkillTreeService:GetTreesName()

	table.clear(Trees)

	for _, BranchName in TreesName do
		if SkillTreesIndex[BranchName] then
			table.insert(Trees, SkillTreesIndex[BranchName])
		end
	end
end

function SkillTreeController:GetLayoutSpacing(): Vector2
	-- The template is outside the zoomed Content and already reflects SizeConstraint.
	return NodeTemplate.AbsoluteSize + Vector2.new(64, 64)
end

function SkillTreeController:DrawConnections()
	for Name, Info in NodesInfo do
		local Requirements = {}
		if not Info.RequiresAny and not Info.RequiresAll then
			table.insert(Requirements, Info.Previous)
		end
		for _, Required in Info.RequiresAll or {} do
			table.insert(Requirements, Required)
		end
		for _, Required in Info.RequiresAny or {} do
			if not table.find(Requirements, Required) then
				table.insert(Requirements, Required)
			end
		end
		local Node = Content:FindFirstChild(Name) :: ImageButton?
		for _, Required in Requirements do
			local Previous = Content:FindFirstChild(Required) :: ImageButton?
			if not Node or not Previous then
				continue
			end
			local Start = Previous:GetAttribute("FinalPosition")
			local Finish = Node:GetAttribute("FinalPosition")
			local Difference = UdimToVector(Finish - Start)
			local Line = InterligationTemplate:Clone()
			Line.Name = Name .. "From" .. Required
			Line:SetAttribute("TargetNode", Name)
			Line:SetAttribute("RequiredNode", Required)
			Line.AnchorPoint = Vector2.new(0.5, 0.5)
			Line.Position = MultUdim2(Start + Finish, 0.5)
			Line.Rotation = math.deg(math.atan2(Difference.Y, Difference.X)) - 90
			Line.Size = UDim2.fromOffset(DEFAULT_SCALE / 3, Difference.Magnitude)
			Line.ZIndex = 1
			Line.Visible = true
			Line.Parent = Content
		end
	end
end

function SkillTreeController:LoadBranch(Branch: Branch, ParentBranch: Branch?, Tree: Branch, InitialPosition: UDim2?)
	local Node = NodeTemplate:Clone()
	Node.Name = Branch.Name
	Node.Frame.TextLabel.Text = Branch.Name
	Node.Frame.TextLabel.TextWrapped = true
	Node.Frame.TextLabel.TextScaled = true
	Node.ZIndex = math.max(Node.ZIndex, 2)
	if ParentBranch and Branch.Passive then
		Node.Size = MultUdim2(Node.Size, 0.85)
		Node.Image = "rbxassetid://73039894467555"
		Node.Frame.Image = "rbxassetid://73039894467555"
	end

	-- Button styles must observe the final Size when the clone enters PlayerGui.
	local EntranceScale = Instance.new("UIScale")
	EntranceScale.Name = "EntranceScale"
	EntranceScale.Scale = 0
	EntranceScale.Parent = Node
	Node.Parent = Content
	Node.Frame.ImageColor3 = Tree.Color
	TweenService:Create(EntranceScale, TweenInfo.new(0.25), { Scale = 1 }):Play()

	if ParentBranch and not self:IsSkillUnlocked(Branch.Name) then
		Node.ImageColor3 = Color3.fromRGB(85, 85, 85)
	end

	if ParentBranch then
		local ParentNodeInstance = Content:FindFirstChild(ParentBranch.Name) :: ImageButton
		Node.Position = ParentNodeInstance:GetAttribute("FinalPosition")
		local Root = Content:FindFirstChild(Tree.Name) :: ImageButton
		local Spacing = self:GetLayoutSpacing()
		local FinalPosition = Root:GetAttribute("FinalPosition") + UDim2.fromOffset(Branch.Layout.X * Spacing.X, Branch.Layout.Y * Spacing.Y)
		TweenService:Create(Node, TweenInfo.new(0.5), { Position = FinalPosition }):Play()
		Node:SetAttribute("FinalPosition", FinalPosition)
	else
		Node:SetAttribute("FinalPosition", InitialPosition)
		Node.Position = InitialPosition
	end

	Node.Activated:Connect(function()
		HotbarController:LoadHotbar(false, false)
		if SelectedNodeName == Branch.Name then
			self:UnlockSkillButton()
			return
		end

		SelectedNodeName = Branch.Name
		if BackgroundTween then
			BackgroundTween:Cancel()
			BackgroundTween = nil
		end
		BackgroundTween = TweenService:Create(Background, TweenInfo.new(0.5), { BackgroundColor3 = Tree.Color })
		BackgroundTween:Play()
		Description.Description.Text = Branch.Description
			.. (if Branch.PointsRequired then "\n\nCost: " .. Branch.PointsRequired .. " " .. Branch.Stat .. " points."
				else "\n\nPoints belong to this attribute only.")
		Description.SkillName.Text = Branch.Name

		Description.Visible = true

		self:RefreshPoints()
	end)

	Node.Visible = true

	if Branch.Branches then
		for _, SubBranch in Branch.Branches do
			SkillTreeController:LoadBranch(SubBranch, Branch, Tree)
		end
	end
end

function SkillTreeController:LoadTree(Tree: Branch, InitialPosition: UDim2)
	SkillTreeController:LoadBranch(Tree, nil, Tree, InitialPosition)
end

local LastScale

function SkillTreeController:BindControls()
	local Mouse = Player:GetMouse()

	Mouse.Button1Down:Connect(function()
		if not Background.Parent.Enabled then
			return
		end

		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessedEvent: boolean)
		if not Background.Parent.Enabled then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)

	Mouse.Move:Connect(function()
		if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			return
		end

		if not Background.Parent.Enabled then
			return
		end

		local md = UserInputService:GetMouseDelta() * 3 / UserInputService.MouseDeltaSensitivity -- so that sens doesnt affect behaviour

		Content.Position += UDim2.fromOffset(md.X, md.Y)
	end)

	local function UpdateScale()
		local mousePosition = UDim2.fromOffset(
			math.floor(Mouse.X - Content.Position.X.Offset),
			math.floor(Mouse.Y - Content.Position.Y.Offset + 36)
		) -- Get mouse position relative to frame
		local x1 = mousePosition.X.Offset * (Content.UIScale.Scale / LastScale) -- calculate frame position
		local y1 = mousePosition.Y.Offset * (Content.UIScale.Scale / LastScale)
		local x2 = Content.Position.X.Offset + (mousePosition.X.Offset - x1)
		local y2 = Content.Position.Y.Offset + (mousePosition.Y.Offset - y1)
		Content.Position = UDim2.fromOffset(x2, y2)

		LastScale = Content.UIScale.Scale
	end

	local lastMagnitude = 0
	local difference = 0
	UserInputService.TouchPinch:Connect(
		function(
			touchPositions: { any },
			_scale: number,
			_velocity: number,
			state: Enum.UserInputState,
			gameProcessedEvent: boolean
		)
			if gameProcessedEvent then
				return
			end
			if not Background.Parent.Enabled then
				return
			end

			local currentMagnitude = (touchPositions[1] - touchPositions[2]).magnitude
			if state == Enum.UserInputState.Change or state == Enum.UserInputState.End then
				difference = currentMagnitude - lastMagnitude
			end

			Content.UIScale.Scale += (difference / Camera.ViewportSize.X)

			lastMagnitude = currentMagnitude

			Content.UIScale.Scale = math.clamp(Content.UIScale.Scale, 0.4, 2)

			UpdateScale()
		end
	)

	UserInputService.TouchMoved:Connect(function(touch)
		if not Background.Parent.Enabled then
			return
		end
		local td = touch.Delta / UserInputService.MouseDeltaSensitivity
		Content.Position += UDim2.fromOffset(td.X, td.Y)
	end)

	Background.MouseWheelForward:Connect(function()
		if not Background.Parent.Enabled then
			return
		end
		Content.UIScale.Scale /= 0.9
		Content.UIScale.Scale = math.min(Content.UIScale.Scale, 2)

		UpdateScale()
	end)

	Background.MouseWheelBackward:Connect(function()
		if not Background.Parent.Enabled then
			return
		end
		Content.UIScale.Scale *= 0.9
		Content.UIScale.Scale = math.max(Content.UIScale.Scale, 0.4)

		UpdateScale()
	end)

	local Pressing = {}
	local Keycodes = {
		Enum.KeyCode.W,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
	}

	local map = {
		[Enum.KeyCode.W] = Vector2.new(0, 1),
		[Enum.KeyCode.S] = Vector2.new(0, -1),

		[Enum.KeyCode.A] = Vector2.new(-1, 0),
		[Enum.KeyCode.D] = Vector2.new(1, 0),
	}
	local Moving = false
	local speed = 750
	UserInputService.InputBegan:Connect(function(key, processing)
		if processing then
			return
		end
		if not Background.Parent.Enabled then
			return
		end

		if table.find(Keycodes, key.KeyCode) and not table.find(Pressing, key.KeyCode) then
			table.insert(Pressing, key.KeyCode)
		end

		if Moving then
			return
		end

		Moving = true
		while Moving do
			if #Pressing == 0 then
				break
			end

			local mapped = Vector2.new()
			for _, PressedKey in Pressing do
				local vec = map[PressedKey]
				mapped += vec
			end

			local dt = task.wait()

			if mapped.Magnitude == 0 then
				continue
			end

			mapped = mapped.Unit

			Content.Position += UDim2.fromOffset(-mapped.X * speed * dt, mapped.Y * speed * dt)
		end

		Moving = false
	end)
	UserInputService.InputEnded:Connect(function(key, processing)
		if processing then
			return
		end

		table.remove(Pressing, table.find(Pressing, key.KeyCode))
	end)

	for _, v: GuiButton in Content:GetChildren() do
		if v:IsA("GuiButton") then
			v.MouseButton1Up:Connect(function()
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end)
		end
	end
end

function SkillTreeController:UpdateTree()
	for _, v in Content:GetChildren() do
		if not v:IsA("UIScale") then
			v:Destroy()
		end
	end

	local Spacing = self:GetLayoutSpacing()
	local Bounds = {}
	local Width = 0
	for _, Tree in Trees do
		local Left, Right = 0, 0
		for _, Info in NodesInfo do
			if Info.Stat == Tree.Stat then
				Left = math.min(Left, Info.Layout.X)
				Right = math.max(Right, Info.Layout.X)
			end
		end
		local Span = Right - Left + 2
		table.insert(Bounds, { Left = Left, Span = Span })
		Width += Span
	end
	local Cursor = -Width / 2
	for Index, Tree in Trees do
		local Bound = Bounds[Index]
		local OffsetX = (Cursor - Bound.Left + 1) * Spacing.X
		self:LoadTree(Tree, UDim2.new(0.5, OffsetX, 0.8, 0))
		Cursor += Bound.Span
	end
	self:DrawConnections()
	self:RefreshNodes()
end

function SkillTreeController:UnlockSkillButton()
	if SelectedNodeName and Progression.CanUnlock(self:GetLocalProgress(), SelectedNodeName, NodesInfo) then
		if SkillTreeService:UnlockNode(SelectedNodeName) then
			self:RefreshNodes()
		end
	end
end

function SkillTreeController:Unselect()
	SelectedNodeName = nil
end

function SkillTreeController:GetSelected()
	return SelectedNodeName
end

function SkillTreeController.KnitInit()
	SkillTreeService = Knit.GetService("SkillTreeService")
	HotbarController = Knit.GetController("HotbarController")
end

function SkillTreeController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	Menu = PlayerGui:WaitForChild("Menu")

	SkillTree = Menu:WaitForChild("SkillTree") :: ScreenGui
	Background = SkillTree:WaitForChild("Background") :: Frame
	Content = SkillTree:WaitForChild("Content") :: Frame
	Description = SkillTree:WaitForChild("Description") :: Frame

	InterligationTemplate = SkillTree:WaitForChild("InterligationTemplate") :: ImageLabel
	NodeTemplate = SkillTree:WaitForChild("NodeTemplate") :: ImageButton

	LastScale = Content.UIScale.Scale
	Content.Position = UDim2.fromOffset(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	SkillTreeController:GetTrees()
	SkillTreeService.UpdateUI:Connect(function(_Trees: { string })
		SkillTreeController:GetTrees()
		if SkillTree.Enabled then
			SkillTreeController:UpdateTree()
		end
	end)

	local function BindCharacter()
		if not Player.Character then
			return
		end
		Player.Character:GetAttributeChangedSignal("Race"):Connect(function()
			SkillTreeController:GetTrees()

			if SkillTree.Enabled then
				SkillTreeController:UpdateTree()
			end
		end)

		Player.Character:GetAttributeChangedSignal("Artifact"):Connect(function()
			SkillTreeController:GetTrees()

			if SkillTree.Enabled then
				SkillTreeController:UpdateTree()
			end
		end)
	end

	BindCharacter()

	Player.CharacterAdded:Connect(function(_character: Model)
		BindCharacter()
	end)

	SkillTreeController:BindControls()

	SkillTree:GetPropertyChangedSignal("Enabled"):Connect(function()
		LastScale = 1
		if not SkillTree.Enabled then
			HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
		end

		SelectedNodeName = nil
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default

		Background.BackgroundColor3 = Color3.fromRGB(51, 51, 51)
		Content.UIScale.Scale = 1
		Content.Position = UDim2.fromOffset(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
		Description.Visible = false

		if BackgroundTween then
			BackgroundTween:Cancel()
			BackgroundTween = nil
		end
	end)

	for _, Stat in Config.Names do
		Player:GetAttributeChangedSignal(Stat .. "SkillPoints"):Connect(function()
			SkillTreeController:RefreshNodes()
		end)
		Player:GetAttributeChangedSignal(Stat .. "Level"):Connect(function()
			SkillTreeController:RefreshNodes()
		end)
	end
	local Folder = Player:WaitForChild("UnlockedNodes") :: Folder
	Folder.ChildAdded:Connect(function()
		SkillTreeController:RefreshNodes()
	end)
	Folder.ChildRemoved:Connect(function()
		SkillTreeController:RefreshNodes()
	end)
	SkillTreeController:RefreshPoints()
end

return SkillTreeController
