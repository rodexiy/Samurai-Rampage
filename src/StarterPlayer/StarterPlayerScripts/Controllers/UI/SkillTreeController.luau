local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.SkillTreeConfig)
local Progression = require(ReplicatedStorage.Shared.SkillTreeProgression)

local SkillTreeController = Knit.CreateController({ Name = "SkillTreeController" })
local Player = Players.LocalPlayer
local NodesInfo = Progression.Index(Config.Trees)
local SkillTreeService
local HotbarController
local SceneController
local MenuController
local SkillTree: ScreenGui
local Description: Frame
local DescriptionText: TextLabel
local SkillNameLabel: TextLabel
local UnlockButton: ImageButton
local UnlockLabel: TextLabel
local PointsLabel: TextLabel
local SelectedNodeName: string? = nil
local Trees: { any } = {}
local UnlockedFolder: Folder?
local Unlocking = false
local ROOT_RADIUS = 42
local RING_SPACING = 32

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
	local NodeInfo = SelectedNodeName and NodesInfo[SelectedNodeName]
	if not NodeInfo then
		UnlockButton.Visible = false
		return
	end

	local Allowed, Reason = Progression.CanUnlock(self:GetLocalProgress(), NodeInfo.Name, NodesInfo)
	UnlockButton.Visible = not self:IsSkillUnlocked(NodeInfo.Name)
	UnlockButton.Active = Allowed
	UnlockButton.AutoButtonColor = Allowed
	UnlockLabel.Text = if Allowed
		then "Unlock - " .. NodeInfo.PointsRequired .. " " .. NodeInfo.Stat .. " points"
		else NodeInfo.PointsRequired .. " " .. NodeInfo.Stat .. " points"
	local ShowReason = not Allowed
		and not self:IsSkillUnlocked(NodeInfo.Name)
		and Reason ~= "Unlock the previous skill first."
	DescriptionText.Text = NodeInfo.Description .. (if ShowReason and Reason then "\n\n" .. Reason else "")
end

function SkillTreeController:GetLocalProgress(): { [string]: any }
	local Data = { Stats = {}, UnlockedNodes = {}, OtherSkills = {} }
	for _, Stat in Config.Names do
		Data.Stats[Stat] = { Level = Player:GetAttribute(Stat .. "Level") or 0 }
	end

	local Folder = Player:FindFirstChild("UnlockedNodes")
	if Folder then
		for _, Node in Folder:GetChildren() do
			if NodesInfo[Node.Name] then
				local Skills = if Node:GetAttribute("OtherSkill") then Data.OtherSkills else Data.UnlockedNodes
				table.insert(Skills, Node.Name)
			end
		end
	end

	return Data
end

function SkillTreeController:RefreshPoints()
	if not SkillTree then
		return
	end

	local Info = SelectedNodeName and (NodesInfo[SelectedNodeName] or Config.Trees[SelectedNodeName])
	PointsLabel.Text = if Info
		then "AVAILABLE POINTS: " .. tostring(Player:GetAttribute(Info.Stat .. "SkillPoints") or 0)
		else "AVAILABLE POINTS: 0"
	for _, Stat in Config.Names do
		SceneController:SetNodeState(Stat, true, true, Player:GetAttribute(Stat .. "SkillPoints") or 0)
	end
	self:CheckUnlockButton()
end

function SkillTreeController:RefreshNodes()
	if not SkillTree then
		return
	end

	local Data = self:GetLocalProgress()
	local Learned = {}
	for _, Stat in Config.Names do
		Learned[Stat] = true
	end
	for Name in NodesInfo do
		Learned[Name] = self:IsSkillUnlocked(Name)
		local Allowed = Progression.CanUnlock(Data, Name, NodesInfo)
		SceneController:SetNodeState(Name, Learned[Name], Allowed)
	end
	SceneController:SetConnectionState(Learned)
	self:RefreshPoints()
end

function SkillTreeController:GetTrees()
	table.clear(Trees)
	for _, Name in SkillTreeService:GetTreesName() do
		if Config.Trees[Name] then
			table.insert(Trees, Config.Trees[Name])
		end
	end
end

function SkillTreeController:SelectNode(Name: string)
	local Info = NodesInfo[Name] or Config.Trees[Name]
	if not Info then
		return
	end

	HotbarController:LoadHotbar(false, false)
	if NodesInfo[Name] then
		SceneController:FocusNode(Name)
	else
		SceneController:CancelFocus()
	end
	if SelectedNodeName == Name then
		self:UnlockSkillButton()
		return
	end

	SelectedNodeName = Name
	SceneController:Select(Name)
	SkillNameLabel.Text = Name
	SkillNameLabel.TextColor3 = Config.Trees[Info.Stat].Color
	DescriptionText.Text = Info.Description
		.. (if not Info.PointsRequired then "\n\nPoints belong to this attribute only." else "")
	Description.Visible = true
	self:RefreshPoints()
end

local function GetNodeDepth(Name: string, Depths: { [string]: number }): number
	if Depths[Name] then
		return Depths[Name]
	end

	local Info = NodesInfo[Name]
	if not Info then
		return 0
	end

	local Depth = GetNodeDepth(Info.Previous, Depths)
	for _, Required in Info.RequiresAll or {} do
		Depth = math.max(Depth, GetNodeDepth(Required, Depths))
	end
	for _, Required in Info.RequiresAny or {} do
		Depth = math.max(Depth, GetNodeDepth(Required, Depths))
	end
	Depths[Name] = Depth + 1

	return Depths[Name]
end

local function RadialPosition(Angle: number, Radius: number): Vector3
	return Vector3.new(math.sin(Angle), 0, -math.cos(Angle)) * Radius
end

function SkillTreeController:LoadRadialTree(Tree: any, Angle: number, Sector: number)
	SceneController:AddNode(Tree.Name, RadialPosition(Angle, ROOT_RADIUS), Tree.Color, true, Tree.Name)
	local Depths: { [string]: number } = {}
	local Rings: { [number]: { any } } = {}
	for Name, Info in NodesInfo do
		if Info.Stat == Tree.Name then
			local Depth = GetNodeDepth(Name, Depths)
			Rings[Depth] = Rings[Depth] or {}
			table.insert(Rings[Depth], Info)
		end
	end

	for Depth, Ring in Rings do
		table.sort(Ring, function(Left: any, Right: any): boolean
			if Left.Layout.X == Right.Layout.X then
				return Left.Name < Right.Name
			end
			return Left.Layout.X < Right.Layout.X
		end)
		for Index, Info in Ring do
			local Offset = if #Ring > 1 then (Index - (#Ring + 1) / 2) / (#Ring - 1) * Sector * 0.65 else 0
			local Position = RadialPosition(Angle + Offset, ROOT_RADIUS + Depth * RING_SPACING)
			SceneController:AddNode(Info.Name, Position, Tree.Color, false, Tree.Name)
		end
	end
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
		for _, Required in Requirements do
			SceneController:AddConnection(Required, Name)
		end
	end
end

function SkillTreeController:UpdateTree()
	SceneController:Clear()
	local Sector = math.pi * 2 / math.max(#Trees, 1)
	for Index, Tree in Trees do
		self:LoadRadialTree(Tree, (Index - 1) * Sector, Sector)
	end
	self:DrawConnections()
	SceneController:Finish()
	SceneController:Select(SelectedNodeName)
	self:RefreshNodes()
end

local function MakeLabel(Name: string, Parent: Instance): TextLabel
	local Label = Instance.new("TextLabel")
	Label.Name = Name
	Label.BackgroundTransparency = 1
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.Font = Enum.Font.GothamMedium
	Label.TextSize = 14
	Label.ZIndex = 5
	Label.Parent = Parent
	return Label
end

function SkillTreeController:ConfigureInterface()
	SkillTree.DisplayOrder = 20
	-- The 3D screen also works with the reduced Studio template (Description only).
	for _, Name in { "Background", "Content", "NodeTemplate", "InterligationTemplate" } do
		local Legacy = SkillTree:FindFirstChild(Name)
		if Legacy and Legacy:IsA("GuiObject") then
			Legacy.Visible = false
		end
	end
	Description = SkillTree:WaitForChild("Description") :: Frame
	Description.Visible = false
	Description.Active = true
	SkillNameLabel = Description:WaitForChild("SkillName") :: TextLabel
	DescriptionText = Description:WaitForChild("Description") :: TextLabel
	UnlockButton = Description:WaitForChild("Button") :: ImageButton
	UnlockLabel = UnlockButton:WaitForChild("ItemType") :: TextLabel
	UnlockButton.Activated:Connect(function()
		self:UnlockSkillButton()
	end)

	local CloseButton = SkillTree:WaitForChild("Close") :: ImageButton
	CloseButton.Activated:Connect(function()
		SkillTree.Enabled = false

		local Character = Player.Character
		if Character and Character:GetAttribute("Meditating") then
			MenuController:OpenMenu("Meditate", true)
		end
	end)

	PointsLabel = Description:WaitForChild("AvailablePoints") :: TextLabel
	local Hint = MakeLabel("CameraHint", SkillTree)
	Hint.Position = UDim2.fromOffset(16, 70)
	Hint.Size = UDim2.new(1, -32, 0, 38)
	Hint.TextXAlignment = Enum.TextXAlignment.Left
	Hint.TextYAlignment = Enum.TextYAlignment.Top
	Hint.TextWrapped = true
	Hint.TextColor3 = Color3.fromRGB(150, 150, 175)
	Hint.TextSize = 12
	local function UpdateHint()
		Hint.Text = if UserInputService.TouchEnabled
			then "Drag to rotate | Two fingers to move/pinch | Tap to select"
			else "Left drag to move | Right drag to rotate | Scroll to zoom"
	end
	UpdateHint()
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(UpdateHint)

	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if SkillTree.Enabled then
			SkillTreeController:UpdateTree()
		end
	end)
end

function SkillTreeController:UnlockSkillButton()
	if
		not Unlocking
		and SelectedNodeName
		and Progression.CanUnlock(self:GetLocalProgress(), SelectedNodeName, NodesInfo)
	then
		Unlocking = true
		local Success = SkillTreeService:UnlockNode(SelectedNodeName)
		Unlocking = false
		if Success then
			self:RefreshNodes()
		end
	end
end

function SkillTreeController:Unselect()
	SelectedNodeName = nil
	SceneController:Select(nil)
	if Description then
		Description.Visible = false
	end
end

function SkillTreeController:GetSelected(): string?
	return SelectedNodeName
end

function SkillTreeController.KnitInit()
	SkillTreeService = Knit.GetService("SkillTreeService")
	HotbarController = Knit.GetController("HotbarController")
	SceneController = Knit.GetController("SkillTreeSceneController")
	MenuController = Knit.GetController("MenuController")
end

function SkillTreeController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	local Menu = PlayerGui:WaitForChild("Menu")
	SkillTree = Menu:WaitForChild("SkillTree") :: ScreenGui
	SceneController:Create(SkillTree, function(Name: string)
		SkillTreeController:SelectNode(Name)
	end)
	SkillTreeController:ConfigureInterface()
	SkillTreeController:GetTrees()

	local function Reload()
		SkillTreeController:GetTrees()
		if SkillTree.Enabled then
			SkillTreeController:UpdateTree()
		end
	end
	SkillTreeService.UpdateUI:Connect(Reload)
	local function BindCharacter(Character: Model)
		Character:GetAttributeChangedSignal("Race"):Connect(Reload)
		Character:GetAttributeChangedSignal("Artifact"):Connect(Reload)
	end
	if Player.Character then
		BindCharacter(Player.Character)
	end
	Player.CharacterAdded:Connect(BindCharacter)

	SkillTree:GetPropertyChangedSignal("Enabled"):Connect(function()
		SkillTreeController:Unselect()
		MenuController:SetHudFocus(SkillTree.Enabled)
		if SkillTree.Enabled then
			SkillTreeController:UpdateTree()
		else
			HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
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
	UnlockedFolder = Player:WaitForChild("UnlockedNodes") :: Folder
	UnlockedFolder.ChildAdded:Connect(function()
		SkillTreeController:RefreshNodes()
	end)
	UnlockedFolder.ChildRemoved:Connect(function()
		SkillTreeController:RefreshNodes()
	end)
	SkillTreeController:RefreshPoints()
	if SkillTree.Enabled then
		SkillTreeController:UpdateTree()
	end
end

return SkillTreeController
