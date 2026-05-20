local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SkillTreeController = Knit.CreateController({
	Name = "SkillTreeController",
})

local HotbarController

local SkillTreeService
local SkillTreesIndex = require(game.ReplicatedStorage.Shared.Index.SkillTrees)

local Trees = {}

local DEFAULT_SCALE = 20

local Player = game.Players.LocalPlayer

local PlayerGui
local Hud
local Menu

local SkillTree
local Background
local Content
local Description

local InterligationTemplate
local NodeTemplate

local Camera = workspace.CurrentCamera

local BackgroundTween = nil

local NodesInfo = {}

type Branch = {
	Name: string,
	PointsRequired: number,
	Description: string,
	Position: string,

	Branches: { Branch }?,
}

local SelectedNodeName = nil

function UdimToVector(Udim: UDim2): Vector2
	return Vector2.new(Udim.X.Offset, Udim.Y.Offset)
end

function MultUdim2(Vector: UDim2, Scale: number)
	return UDim2.new(Vector.X.Scale * Scale, Vector.X.Offset * Scale, Vector.Y.Scale * Scale, Vector.Y.Offset * Scale)
end

function SkillTreeController:IsSkillUnlocked(SkillName: string)
	return false
	-- local UnlockedNodes = Player:FindFirstChild("UnlockedNodes")
	-- if not UnlockedNodes then
	-- 	warn("Unlocked nodes missing!")
	-- 	return false
	-- end
	-- return UnlockedNodes:FindFirstChild(SkillName) ~= nil
end

function SkillTreeController:CheckUnlockButton()
	local NodeInfo = NodesInfo[SelectedNodeName]
	if not NodeInfo then
		Description.TextButton.Visible = false
		return
	end

	if NodeInfo.Passive and self:IsSkillUnlocked(NodeInfo.Name) then
		Description.TextButton.Visible = false
	elseif not NodeInfo.Passive and self:IsSkillUnlocked(NodeInfo.Name) then
		Description.TextButton.Visible = true
		Description.TextButton.Text = "Equip"
	else
		Description.TextButton.Visible = true
		Description.TextButton.Text = "Unlock - "
			.. tostring(NodeInfo.PointsRequired)
			.. (NodeInfo.PointsRequired == 1 and " Point" or " Points")
	end
end

function SkillTreeController:GetTrees()
	local TreesName = SkillTreeService:GetTreesName()

	table.clear(Trees)

	for _, BranchName in TreesName do
		table.insert(Trees, SkillTreesIndex[BranchName])
	end
end

function SkillTreeController:GetPositionOffset(Position)
	local OffsetAmount = NodeTemplate.AbsoluteSize.Y + 64
	if not Position then
		return UDim2.new(0, 0, 0, OffsetAmount)
	end

	local SideOffset = 64

	local Offsets = {
		Forward = UDim2.new(0, 0, 0, -OffsetAmount),
		Backward = UDim2.new(0, 0, 0, OffsetAmount),
		Left = UDim2.new(0, -OffsetAmount, 0, 0),
		Right = UDim2.new(0, OffsetAmount, 0, 0),
		DiagonalLeft = UDim2.new(0, -OffsetAmount, 0, -OffsetAmount),
		DiagonalRight = UDim2.new(0, OffsetAmount, 0, -OffsetAmount),
		BackwardLeft = UDim2.new(0, -OffsetAmount, 0, OffsetAmount),
		BackwardRight = UDim2.new(0, OffsetAmount, 0, OffsetAmount),
	}

	local Offset = Offsets[Position]

	if Offset.X.Offset > 0 then
		Offset += UDim2.fromOffset(SideOffset, 0)
	elseif Offset.X.Offset < 0 then
		Offset -= UDim2.fromOffset(SideOffset, 0)
	end

	if Position == "DiagonalLeft" then
		Offset += UDim2.fromOffset(-SideOffset, -SideOffset * 2)
	elseif Position == "DiagonalRight" then
		Offset += UDim2.fromOffset(SideOffset, -SideOffset * 2)
	end

	local Vector = Vector2.new(Offset.X.Offset, Offset.Y.Offset).Unit
	local Normalized = UDim2.new(0, Vector.X * OffsetAmount, 0, Vector.Y * OffsetAmount)
	return Normalized
end

local TotalPoints = 0

function SkillTreeController:LoadBranch(Branch: Branch, ParentBranch: Branch?, Tree: Branch, InitialPosition: UDim2?)
	local Node = NodeTemplate:Clone()
	Node.Name = Branch.Name
	Node.Frame.TextLabel.Text = Branch.Name
	Node.Parent = Content
	Node.Frame.ImageColor3 = Tree.Color

	TotalPoints += Branch.PointsRequired or 0

	if ParentBranch and not self:IsSkillUnlocked(Branch.Name) then
		Node.ImageColor3 = Color3.fromRGB(85, 85, 85)
	end

	local Interligation

	if ParentBranch then
		task.wait(0.05)
		local ParentNodeInstance: ImageButton = Content:FindFirstChild(ParentBranch.Name)

		local NormalSize = Node.Size
		Node.Size = UDim2.fromOffset(0, 0)
		Node.Position = ParentNodeInstance:GetAttribute("FinalPosition")
		local FinalPosition = ParentNodeInstance:GetAttribute("FinalPosition") + self:GetPositionOffset(Branch.Position)
		if Branch.Passive then
			NormalSize = MultUdim2(NormalSize, 0.85)

			Node.Image = "rbxassetid://73039894467555"
			Node.Frame.Image = "rbxassetid://73039894467555"
		end

		TweenService:Create(Node, TweenInfo.new(0.25), { Size = NormalSize }):Play()
		TweenService:Create(Node, TweenInfo.new(0.5), { Position = FinalPosition, Size = NormalSize }):Play()
		Node:SetAttribute("FinalPosition", FinalPosition)

		Interligation = InterligationTemplate:Clone()
		Interligation.Parent = Content

		Interligation.Name = Branch.Name .. "Interligation"

		if ParentBranch and not self:IsSkillUnlocked(Branch.Name) then
			Interligation.ImageColor3 = Color3.fromRGB(85, 85, 85)
		end

		Interligation.Size = UDim2.fromOffset(DEFAULT_SCALE / 3, 0)

		task.delay(0.5, function()
			TweenService:Create(Interligation, TweenInfo.new(1), {
				Size = UDim2.fromOffset(DEFAULT_SCALE / 3, DEFAULT_SCALE * 8),
			}):Play()
		end)

		local p1 = Node:GetAttribute("FinalPosition")
		local p2 = ParentNodeInstance:GetAttribute("FinalPosition")

		local heightDiff = UdimToVector(p1).X - UdimToVector(p2).X
		heightDiff = -heightDiff / math.abs(heightDiff)
		local ry = math.asin((UdimToVector(p1) - UdimToVector(p2)).Unit.Y)
		Interligation.Rotation = (math.deg(-ry)) * heightDiff + 90

		if Branch.Position == "Backward" or Branch.Position == "Forward" then
			Interligation.Rotation = 0
		end

		Interligation.Position = MultUdim2(Node:GetAttribute("FinalPosition"), 0.5)
			+ MultUdim2(ParentNodeInstance:GetAttribute("FinalPosition"), 0.5)

		Interligation.Visible = true
	else
		Node:SetAttribute("FinalPosition", InitialPosition)
		Node.Position = InitialPosition
	end

	Node.Activated:Connect(function()
		HotbarController:LoadHotbar(false, false)
		if SelectedNodeName == Branch.Name then
			if SkillTreeService:UnlockNode(SelectedNodeName) then
				Node.ImageColor3 = Color3.fromRGB(255, 255, 255)
				if Interligation then
					Interligation.ImageColor3 = Color3.fromRGB(255, 255, 255)
				end
				self:CheckUnlockButton()
			end
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
		Description.SkillName.Text = Branch.Name

		Description.Visible = true

		self:CheckUnlockButton()
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

	print(TotalPoints)
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

	UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
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
			scale: number,
			velocity: number,
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
			for _, key in Pressing do
				local vec = map[key]
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

	for i, v: GuiButton in Content:GetChildren() do
		if v:IsA("GuiButton") then
			v.MouseButton1Up:Connect(function()
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end)
		end
	end
end

local threads = {}
function SkillTreeController:UpdateTree()
	for _, v in Content:GetChildren() do
		if not v:IsA("UIScale") then
			v:Destroy()
		end
	end

	for Index, Tree in Trees do
		local NumberOfTrees = #Trees

		-- Calculate the offset based on the index and number of trees
		local OffsetX = (Index - (NumberOfTrees + 1) / 2) * 0.35 -- Adjust 0.1 for spacing between trees

		-- Set the initial position, spreading outwards horizontally from the center
		local InitialPosition = UDim2.new(0.5 + OffsetX, 0, 0.8, 0)

		table.insert(
			threads,
			task.spawn(function()
				SkillTreeController:LoadTree(Tree, InitialPosition)
			end)
		)
	end
end

function SkillTreeController:UnlockSkillButton()
	if SelectedNodeName then
		if Description.TextButton.Visible and Description.TextButton.Text == "Equip" then
			HotbarController:LoadHotbar(true, true)
		elseif SkillTreeService:UnlockNode(SelectedNodeName) then
			local Node = Content:FindFirstChild(SelectedNodeName)
			if Node then
				Node.ImageColor3 = Color3.fromRGB(255, 255, 255)
			end
			local Interligation = Content:FindFirstChild(SelectedNodeName .. "Interligation")
			if Interligation then
				Interligation.ImageColor3 = Color3.fromRGB(255, 255, 255)
			end
			self:CheckUnlockButton()
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
	
end

return SkillTreeController
