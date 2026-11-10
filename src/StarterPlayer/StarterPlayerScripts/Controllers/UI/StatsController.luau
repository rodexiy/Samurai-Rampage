local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Items = require(ReplicatedStorage.Shared.Index.Items)
local Progression = require(ReplicatedStorage.Shared.StatProgression)
local StatService

type Progress = {
	Level: number,
	XP: number,
	XPRequired: number,
}

type AttributeView = {
	LevelBar: Frame,
	XPBar: Frame,
	CurrentLevel: TextLabel,
	CurrentXP: TextLabel,
	MaxLevel: TextLabel,
	XPRequired: TextLabel,
}

local StatsController = Knit.CreateController({
	Name = "StatsController",
})

local MAX_LEVEL = Progression.MaxLevel
local BAR_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local AttributeNames = Progression.Names
local ProgressHelp = Progression.Help
local EquipmentTypes = { "Head", "Face", "Torso", "Legs", "Back", "Eyes", "Waist", "Prosthetic", "Artifact" }
local OtherStats = {
	{ Key = "SwordDamage", Name = "Weapon Damage" },
	{ Key = "MaxHealth", Name = "Max Health" },
	{ Key = "MaxStamina", Name = "Max Stamina" },
	{ Key = "MaxPosture", Name = "Max Posture" },
	{ Key = "WeaponResistance", Name = "Weapon Resistance", Suffix = "%" },
	{ Key = "ArtifactResistance", Name = "Artifact Resistance", Suffix = "%" },
	{ Key = "WalkSpeed", Name = "Walk Speed" },
	{ Key = "RunSpeed", Name = "Run Speed" },
	{ Key = "Regeneration", Name = "Health Regen", Suffix = "% /s" },
}

local Player = Players.LocalPlayer
local MainMenu: ScreenGui
local Panel: Frame
local Info: TextLabel
local HoveredQuestion: ImageButton? = nil
local Visible = false
local Character: Model? = nil
local CharacterConnection: RBXScriptConnection? = nil
local Views: { [string]: AttributeView } = {}
local ProgressValues: { [string]: Progress } = {}
local OtherLabels: { [string]: TextLabel } = {}
local WatchedAttributes = {
	SwordDamage = true,
	MaxHealth = true,
	MaxStamina = true,
	MaxPosture = true,
	DefaultWalkSpeed = true,
	RunningWalkSpeed = true,
	RunSpeedMultiplier = true,
	RunSpeedIncrease = true,
	Regeneration = true,
	StatWeaponResistance = true,
	Weapon = true,
	LeftWeapon = true,
}

local function FormatNumber(Value: number): string
	return (string.format("%.1f", Value):gsub("%.0$", ""))
end

local function GetNumber(Source: Instance, Name: string, Default: number): number
	local Value = Source:GetAttribute(Name)
	return if typeof(Value) == "number" then Value else Default
end

local function SetFill(Bar: Frame, Ratio: number, Animated: boolean)
	local Size = UDim2.fromScale(1, Ratio)
	if Animated then
		TweenService:Create(Bar, BAR_TWEEN, { Size = Size }):Play()
	else
		Bar.Size = Size
	end
end

local function BindBarLabel(Bar: Frame, Label: TextLabel)
	local OriginalPosition = Label.Position

	local function UpdatePosition()
		local Top = Bar.Position.Y.Scale - Bar.Size.Y.Scale * Bar.AnchorPoint.Y
		local Y = math.clamp(Top + OriginalPosition.Y.Scale, 0, 1 - Label.Size.Y.Scale)
		Label.Position = UDim2.new(OriginalPosition.X.Scale, OriginalPosition.X.Offset, Y, OriginalPosition.Y.Offset)
	end

	Bar:GetPropertyChangedSignal("Size"):Connect(UpdatePosition)
	UpdatePosition()
end

local function GetEquipmentResistance(CurrentCharacter: Model, Attribute: string): number
	local Total = if Attribute == "WeaponResistance" then GetNumber(CurrentCharacter, "StatWeaponResistance", 0) else 0
	for _, Slot in EquipmentTypes do
		local ItemName = CurrentCharacter:GetAttribute(Slot)
		local Item = if typeof(ItemName) == "string" then Items[ItemName] else nil
		if Item then
			Total += Item[Attribute] or 0
		end
	end

	return Total
end

local function GetOtherValue(CurrentCharacter: Model, Key: string): number?
	if Key == "WeaponResistance" or Key == "ArtifactResistance" then
		return GetEquipmentResistance(CurrentCharacter, Key)
	end

	if Key == "WalkSpeed" or Key == "RunSpeed" then
		local Speed = GetNumber(CurrentCharacter, "DefaultWalkSpeed", 12)
		if Key == "RunSpeed" then
			Speed = GetNumber(CurrentCharacter, "RunningWalkSpeed", 24)
				* GetNumber(CurrentCharacter, "RunSpeedMultiplier", 1)
				+ GetNumber(CurrentCharacter, "RunSpeedIncrease", 0)
		end

		if not CurrentCharacter:GetAttribute("Weapon") and not CurrentCharacter:GetAttribute("LeftWeapon") then
			Speed *= 1.2
		end

		return Speed
	end

	local Value = CurrentCharacter:GetAttribute(Key)
	if typeof(Value) ~= "number" then
		return nil
	end

	return if Key == "Regeneration" then Value * 100 else Value
end

function StatsController:RenderProgress(Name: string, Animated: boolean)
	local View = Views[Name]
	local Data = ProgressValues[Name]
	if not View or not Data then
		return
	end

	local IsMax = Data.Level == MAX_LEVEL
	SetFill(View.LevelBar, Data.Level / MAX_LEVEL, Animated)
	SetFill(View.XPBar, if IsMax then 1 else Data.XP / Data.XPRequired, Animated)
	View.CurrentLevel.Text = "LVL " .. Data.Level
	View.MaxLevel.Text = "LVL " .. MAX_LEVEL
	View.CurrentXP.Text = if IsMax then "MAX" else FormatNumber(Data.XP)
	View.XPRequired.Text = FormatNumber(Data.XPRequired)
	View.XPRequired.Visible = not IsMax
end

-- Updates presentation only; earning XP and saving levels belong to the server.
function StatsController:SetProgress(Name: string, Level: number, XP: number, XPRequired: number)
	if not ProgressValues[Name] then
		return
	end

	local Required = math.max(1, XPRequired)
	ProgressValues[Name] = {
		Level = math.clamp(math.floor(Level), 0, MAX_LEVEL),
		XP = math.clamp(XP, 0, Required),
		XPRequired = Required,
	}

	if Panel and Panel.Visible and MainMenu.Enabled then
		self:RenderProgress(Name, true)
	end
end

function StatsController:ReadProgress(Name: string)
	self:SetProgress(
		Name,
		GetNumber(Player, Name .. "Level", 0),
		GetNumber(Player, Name .. "XP", 0),
		GetNumber(Player, Name .. "XPRequired", Progression.GetXPRequired(Name, 0))
	)
end

function StatsController:UpdateProgress(Progress: { [string]: Progress })
	for Name, Data in Progress do
		self:SetProgress(Name, Data.Level, Data.XP, Data.XPRequired)
	end
end

function StatsController:RefreshOtherStats()
	if not Panel or not Panel.Visible or not MainMenu.Enabled then
		return
	end

	for _, Stat in OtherStats do
		local Value = if Character then GetOtherValue(Character, Stat.Key) else nil
		local Text = if Value ~= nil then FormatNumber(Value) .. (Stat.Suffix or "") else "--"
		OtherLabels[Stat.Key].Text = Stat.Name .. ": " .. Text
	end
end

function StatsController:HideInfo()
	HoveredQuestion = nil
	if Info then
		Info.Visible = false
	end
end

function StatsController:ShowInfo(Question: ImageButton, Name: string)
	if not Panel or not Panel.Visible or not MainMenu.Enabled or not ProgressHelp[Name] then
		return
	end

	HoveredQuestion = Question
	Info.Text = Name:upper() .. "\n" .. ProgressHelp[Name]
	Info.Visible = true

	local HalfWidth = Info.AbsoluteSize.X / 2
	local X = Question.AbsolutePosition.X + Question.AbsoluteSize.X / 2 - Panel.AbsolutePosition.X
	local Y = Question.AbsolutePosition.Y + Question.AbsoluteSize.Y - Panel.AbsolutePosition.Y + 8
	X = math.clamp(X, HalfWidth, math.max(HalfWidth, Panel.AbsoluteSize.X - HalfWidth))
	Info.Position = UDim2.fromOffset(X, Y)
end

function StatsController:SetVisible(Enabled: boolean)
	Visible = Enabled
	if not Enabled then
		self:HideInfo()
	end

	if not Panel then
		return
	end

	Panel.Visible = Enabled
	if Enabled then
		for _, Name in AttributeNames do
			self:RenderProgress(Name, false)
		end

		self:RefreshOtherStats()
	end
end

function StatsController:BindCharacter(NewCharacter: Model?)
	if CharacterConnection then
		CharacterConnection:Disconnect()
		CharacterConnection = nil
	end

	Character = NewCharacter
	if NewCharacter then
		CharacterConnection = NewCharacter.AttributeChanged:Connect(function(Name: string)
			if WatchedAttributes[Name] then
				self:RefreshOtherStats()
			end
		end)
	end

	self:RefreshOtherStats()
end

function StatsController.KnitInit()
	StatService = Knit.GetService("StatService")
end

function StatsController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	local Menus = PlayerGui:WaitForChild("Menu") :: ScreenGui
	MainMenu = (PlayerGui:FindFirstChild("MainMenu") or Menus:WaitForChild("MainMenu")) :: ScreenGui
	Panel = MainMenu:WaitForChild("Stats") :: Frame
	Info = Panel:WaitForChild("Info") :: TextLabel
	Info.AnchorPoint = Vector2.new(0.5, 0)
	Info.Size = UDim2.fromScale(0.3, 0.04)
	Info.AutomaticSize = Enum.AutomaticSize.Y
	Info.TextScaled = false
	Info.TextWrapped = true
	Info.TextSize = 32

	local Padding = Info:FindFirstChildWhichIsA("UIPadding") or Instance.new("UIPadding")
	Padding.PaddingLeft = UDim.new(0, 12)
	Padding.PaddingRight = UDim.new(0, 12)
	Padding.PaddingTop = UDim.new(0, 12)
	Padding.PaddingBottom = UDim.new(0, 12)
	Padding.Parent = Info

	StatsController:HideInfo()

	local Bars = Panel:WaitForChild("Bars") :: Frame

	for _, Name in AttributeNames do
		local Column = Bars:WaitForChild(Name) :: Frame
		local Question = Column:WaitForChild("Question") :: ImageButton
		Question.MouseEnter:Connect(function()
			StatsController:ShowInfo(Question, Name)
		end)
		Question.MouseLeave:Connect(function()
			if HoveredQuestion == Question then
				StatsController:HideInfo()
			end
		end)

		local LevelProgress = Column:WaitForChild("LevelProgress") :: Frame
		local XPProgress = Column:WaitForChild("ExpProgress") :: Frame
		local LevelTop = Column:WaitForChild("LevelTop") :: Frame
		Views[Name] = {
			LevelBar = LevelProgress:WaitForChild("Bar") :: Frame,
			XPBar = XPProgress:WaitForChild("Bar") :: Frame,
			CurrentLevel = LevelProgress:WaitForChild("CurrentLevel") :: TextLabel,
			CurrentXP = XPProgress:WaitForChild("CurrentExp") :: TextLabel,
			MaxLevel = LevelTop:WaitForChild("MaxLevel") :: TextLabel,
			XPRequired = LevelTop:WaitForChild("ExpNeeded") :: TextLabel,
		}
		local View = Views[Name]
		BindBarLabel(View.LevelBar, View.CurrentLevel)
		BindBarLabel(View.XPBar, View.CurrentXP)

		ProgressValues[Name] = { Level = 0, XP = 0, XPRequired = Progression.GetXPRequired(Name, 0) }

		StatsController:ReadProgress(Name)
	end

	local Other = Panel:WaitForChild("OtherStats") :: Frame
	local Template = Other:WaitForChild("Attribute") :: TextLabel
	Template.Visible = false
	for Index, Stat in OtherStats do
		local Label = Template:Clone()
		local AspectRatio = Label:FindFirstChildWhichIsA("UIAspectRatioConstraint")
		if AspectRatio then
			AspectRatio:Destroy()
		end

		Label.Name = Stat.Key
		Label.LayoutOrder = Index
		Label.Size = UDim2.new(1 / 3, -4, 1 / 3, -2)
		Label.Visible = true
		Label.Parent = Other
		OtherLabels[Stat.Key] = Label
	end

	for _, Slot in EquipmentTypes do
		WatchedAttributes[Slot] = true
	end

	MainMenu:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not MainMenu.Enabled then
			StatsController:HideInfo()
		end
	end)
	Panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not Panel.Visible then
			StatsController:HideInfo()
		end
	end)

	StatService.ProgressUpdated:Connect(function(Progress: { [string]: Progress })
		StatsController:UpdateProgress(Progress)
	end)
	StatsController:UpdateProgress(StatService:GetProgress())
	Player.CharacterAdded:Connect(function(NewCharacter: Model)
		StatsController:BindCharacter(NewCharacter)
	end)
	Player.CharacterRemoving:Connect(function(OldCharacter: Model)
		if Character == OldCharacter then
			StatsController:BindCharacter(nil)
		end
	end)

	StatsController:BindCharacter(Player.Character)
	StatsController:SetVisible(Visible)
end

return StatsController
