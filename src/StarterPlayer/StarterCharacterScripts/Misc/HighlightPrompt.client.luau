local Knit = require(game.ReplicatedStorage.Packages.Knit)

local CarryService
local LoadedServices = false

Knit.OnStart():andThen(function()
	CarryService = Knit.GetService("CarryService")
	LoadedServices = true
end)

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

repeat
	task.wait()
until LoadedServices

local PlayerGui = Player:WaitForChild("PlayerGui")
local Hud = PlayerGui:WaitForChild("Hud")
local ProximityPromptUI = Hud:WaitForChild("ProximityPrompt")
local PromptLabel = ProximityPromptUI:WaitForChild("TextLabel")

local RARITY_COLORS = {
	Common = {
		Primary = Color3.fromRGB(238, 242, 247),
		Secondary = Color3.fromRGB(142, 154, 170),
	},
	Uncommon = {
		Primary = Color3.fromRGB(105, 255, 137),
		Secondary = Color3.fromRGB(23, 179, 93),
	},
	Rare = {
		Primary = Color3.fromRGB(86, 226, 255),
		Secondary = Color3.fromRGB(31, 111, 255),
	},
	Epic = {
		Primary = Color3.fromRGB(218, 147, 255),
		Secondary = Color3.fromRGB(128, 46, 255),
	},
	Legendary = {
		Primary = Color3.fromRGB(255, 224, 102),
		Secondary = Color3.fromRGB(255, 92, 46),
	},
}

local function GetRarityColors(Prompt: ProximityPrompt)
	return RARITY_COLORS[Prompt:GetAttribute("Rarity") or "Common"] or RARITY_COLORS.Common
end

local function GetOrCreate(ClassName: string, Name: string, Parent: Instance)
	local Existing = Parent:FindFirstChild(Name)
	if Existing and Existing.ClassName == ClassName then
		return Existing
	end
	if Existing then
		Existing:Destroy()
	end

	local Created = Instance.new(ClassName)
	Created.Name = Name
	Created.Parent = Parent
	return Created
end

PromptLabel.AnchorPoint = Vector2.new(0.5, 1)
PromptLabel.AutoButtonColor = false
PromptLabel.BackgroundColor3 = Color3.fromRGB(11, 14, 20)
PromptLabel.BackgroundTransparency = 0.08
PromptLabel.ClipsDescendants = true
PromptLabel.Position = UDim2.new(0.5, 0, 0.9, 0)
PromptLabel.Size = UDim2.fromOffset(390, 82)
PromptLabel.Text = ""
PromptLabel.TextTransparency = 1

local PromptCorner = GetOrCreate("UICorner", "PromptCorner", PromptLabel)
PromptCorner.CornerRadius = UDim.new(0, 12)

local PromptStroke = GetOrCreate("UIStroke", "PromptStroke", PromptLabel)
PromptStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
PromptStroke.Color = RARITY_COLORS.Common.Primary
PromptStroke.Thickness = 1.5
PromptStroke.Transparency = 0.35

local BackgroundGradient = GetOrCreate("UIGradient", "BackgroundGradient", PromptLabel)
BackgroundGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 34, 46)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 11, 16)),
})
BackgroundGradient.Rotation = 25

local PromptScale = GetOrCreate("UIScale", "PromptScale", PromptLabel)

local Accent = GetOrCreate("Frame", "Accent", PromptLabel)
Accent.BackgroundColor3 = Color3.new(1, 1, 1)
Accent.BorderSizePixel = 0
Accent.Position = UDim2.fromOffset(0, 0)
Accent.Size = UDim2.new(1, 0, 0, 4)

local AccentGradient = GetOrCreate("UIGradient", "AccentGradient", Accent)

local KeyBadge = GetOrCreate("Frame", "KeyBadge", PromptLabel)
KeyBadge.BackgroundColor3 = Color3.fromRGB(35, 41, 53)
KeyBadge.BackgroundTransparency = 0.08
KeyBadge.BorderSizePixel = 0
KeyBadge.Position = UDim2.fromOffset(14, 16)
KeyBadge.Size = UDim2.fromOffset(50, 50)

local KeyCorner = GetOrCreate("UICorner", "KeyCorner", KeyBadge)
KeyCorner.CornerRadius = UDim.new(0, 10)

local KeyStroke = GetOrCreate("UIStroke", "KeyStroke", KeyBadge)
KeyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
KeyStroke.Thickness = 1.5
KeyStroke.Transparency = 0.2

local KeyLabel = GetOrCreate("TextLabel", "KeyLabel", KeyBadge)
KeyLabel.BackgroundTransparency = 1
KeyLabel.Font = Enum.Font.GothamBold
KeyLabel.Size = UDim2.fromScale(1, 1)
KeyLabel.Text = "F"
KeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyLabel.TextScaled = true

local KeyTextConstraint = GetOrCreate("UITextSizeConstraint", "KeyTextConstraint", KeyLabel)
KeyTextConstraint.MaxTextSize = 22
KeyTextConstraint.MinTextSize = 9

local Content = GetOrCreate("Frame", "Content", PromptLabel)
Content.BackgroundTransparency = 1
Content.Position = UDim2.fromOffset(78, 10)
Content.Size = UDim2.new(1, -92, 1, -20)

local ActionLabel = GetOrCreate("TextLabel", "ActionLabel", Content)
ActionLabel.BackgroundTransparency = 1
ActionLabel.Font = Enum.Font.GothamBold
ActionLabel.Position = UDim2.fromOffset(0, 0)
ActionLabel.Size = UDim2.new(1, 0, 0, 15)
ActionLabel.Text = "INTERACT"
ActionLabel.TextColor3 = Color3.fromRGB(166, 177, 193)
ActionLabel.TextSize = 10
ActionLabel.TextXAlignment = Enum.TextXAlignment.Left

local ObjectLabel = GetOrCreate("TextLabel", "ObjectLabel", Content)
ObjectLabel.BackgroundTransparency = 1
ObjectLabel.Font = Enum.Font.GothamBold
ObjectLabel.Position = UDim2.fromOffset(0, 14)
ObjectLabel.Size = UDim2.new(1, 0, 0, 28)
ObjectLabel.Text = "Object"
ObjectLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ObjectLabel.TextSize = 21
ObjectLabel.TextTruncate = Enum.TextTruncate.AtEnd
ObjectLabel.TextXAlignment = Enum.TextXAlignment.Left

local ObjectGradient = GetOrCreate("UIGradient", "ObjectGradient", ObjectLabel)

local RarityLabel = GetOrCreate("TextLabel", "RarityLabel", Content)
RarityLabel.BackgroundTransparency = 1
RarityLabel.Font = Enum.Font.GothamMedium
RarityLabel.Position = UDim2.fromOffset(0, 43)
RarityLabel.Size = UDim2.new(1, 0, 0, 14)
RarityLabel.Text = "COMMON"
RarityLabel.TextSize = 10
RarityLabel.TextXAlignment = Enum.TextXAlignment.Left

local ProgressTrack = GetOrCreate("Frame", "ProgressTrack", PromptLabel)
ProgressTrack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ProgressTrack.BackgroundTransparency = 0.88
ProgressTrack.BorderSizePixel = 0
ProgressTrack.Position = UDim2.new(0, 0, 1, -3)
ProgressTrack.Size = UDim2.new(1, 0, 0, 3)

local ProgressFill = GetOrCreate("Frame", "ProgressFill", ProgressTrack)
ProgressFill.BackgroundColor3 = Color3.new(1, 1, 1)
ProgressFill.BorderSizePixel = 0
ProgressFill.Size = UDim2.fromScale(0, 1)

local ProgressGradient = GetOrCreate("UIGradient", "ProgressGradient", ProgressFill)

local DestroyingCache = {}
local CurrentPrompt = nil
local PromptBeams = {}

local BEAM_NAME = "PromptBeam"
local TARGET_ATTACHMENT_NAME = "PromptBeamTargetAttachment"
local CHARACTER_ATTACHMENT_NAME = "PromptBeamCharacterAttachment"

local HoldTween
local HeldPrompt

local function ResetHoldProgress()
	if HoldTween then
		HoldTween:Cancel()
		HoldTween = nil
	end
	ProgressFill.Size = UDim2.fromScale(0, 1)
end

local function ApplyPromptAppearance(Prompt: ProximityPrompt, Key: string)
	local Colors = GetRarityColors(Prompt)
	local Rarity = Prompt:GetAttribute("Rarity") or "Common"
	local IsPickable = Prompt:GetAttribute("Pickable") == true or Prompt:GetAttribute("callback") == "Pick"
	local DisplayName = Prompt:GetAttribute("DisplayName") or Prompt.ObjectText

	if DisplayName == "" and Prompt.Parent then
		DisplayName = Prompt.Parent.Name
	end

	KeyLabel.Text = Key:gsub("Button", "")
	ActionLabel.Text = string.upper(Prompt.ActionText ~= "" and Prompt.ActionText or "Interact")
	ObjectLabel.Text = DisplayName
	RarityLabel.Text = string.upper(Rarity)
	RarityLabel.TextColor3 = Colors.Primary
	RarityLabel.Visible = IsPickable or Prompt:GetAttribute("Rarity") ~= nil

	local RarityGradient = ColorSequence.new(Colors.Primary, Colors.Secondary)
	AccentGradient.Color = RarityGradient
	KeyStroke.Color = Colors.Primary
	ObjectGradient.Color = RarityGradient
	ProgressGradient.Color = RarityGradient
	PromptStroke.Color = Colors.Primary

	ResetHoldProgress()
	PromptScale.Scale = 0.92
	TweenService:Create(PromptScale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

local function GetPromptModel(Prompt: ProximityPrompt)
	local Parent = Prompt.Parent
	if not Parent then
		return
	end

	return Parent
end

local function GetPromptHighlightParent(Prompt: ProximityPrompt): Instance?
	return Prompt.Parent
end

local function GetPromptHighlight(Prompt: ProximityPrompt): Highlight?
	local HighlightParent = GetPromptHighlightParent(Prompt)
	if not HighlightParent then
		return nil
	end

	return HighlightParent:FindFirstChild("PromptHighlight") :: Highlight?
end

local function GetPromptTargetPart(Prompt: ProximityPrompt): BasePart?
	local Parent = Prompt.Parent
	if not Parent then
		return nil
	end

	if Parent:IsA("Attachment") and Parent.Parent and Parent.Parent:IsA("BasePart") then
		return Parent.Parent
	end

	if Parent:IsA("BasePart") then
		return Parent
	end

	if Parent:IsA("Model") then
		return Parent.PrimaryPart or Parent:FindFirstChildWhichIsA("BasePart", true)
	end

	return Parent:FindFirstAncestorWhichIsA("BasePart")
end

local function DestroyPromptBeam(Prompt: ProximityPrompt)
	local BeamData = PromptBeams[Prompt]
	if not BeamData then
		return
	end

	PromptBeams[Prompt] = nil

	for _, InstanceToDestroy in BeamData do
		if InstanceToDestroy and InstanceToDestroy.Parent then
			InstanceToDestroy:Destroy()
		end
	end
end

local function CreatePromptBeam(Prompt: ProximityPrompt)
	DestroyPromptBeam(Prompt)

	local Character = Player.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	local TargetPart = GetPromptTargetPart(Prompt)
	if not RootPart or not TargetPart then
		return
	end

	local TargetAttachment = Instance.new("Attachment")
	TargetAttachment.Name = TARGET_ATTACHMENT_NAME
	TargetAttachment.Parent = TargetPart

	local CharacterAttachment = Instance.new("Attachment")
	CharacterAttachment.Name = CHARACTER_ATTACHMENT_NAME
	CharacterAttachment.Parent = RootPart

	local Beam = Instance.new("Beam")
	local Colors = GetRarityColors(Prompt)
	Beam.Name = BEAM_NAME
	Beam.Attachment0 = TargetAttachment
	Beam.Attachment1 = CharacterAttachment
	Beam.Color = ColorSequence.new(Colors.Primary, Colors.Secondary)
	Beam.FaceCamera = true
	Beam.LightEmission = 0.45
	Beam.LightInfluence = 0
	Beam.Segments = 12
	Beam.TextureSpeed = 1
	Beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	Beam.Width0 = 0.08
	Beam.Width1 = 0.02
	Beam.Parent = TargetPart

	PromptBeams[Prompt] = {
		Beam,
		TargetAttachment,
		CharacterAttachment,
	}
end

ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType)
	local Model = GetPromptModel(prompt)
	local HighlightParent = GetPromptHighlightParent(prompt)
	if not Model or not HighlightParent then
		return
	end

	local Key

	if UserInputService.GamepadEnabled then
		Key = prompt.GamepadKeyCode.Name
	else
		Key = prompt.KeyboardKeyCode.Name
	end

	local ExistingPromptHighlight = GetPromptHighlight(prompt)
	if ExistingPromptHighlight then
		ExistingPromptHighlight:Destroy()
	end

	ProximityPromptUI.Enabled = true
	CurrentPrompt = prompt
	ApplyPromptAppearance(prompt, Key)
	CreatePromptBeam(prompt)
	if not GetPromptHighlight(prompt) then
		local Colors = GetRarityColors(prompt)
		local PromptHighlight = Instance.new("Highlight")
		PromptHighlight.Name = "PromptHighlight"
		PromptHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
		PromptHighlight.FillTransparency = 0.85
		PromptHighlight.OutlineColor = Colors.Primary
		PromptHighlight.FillColor = Colors.Secondary
		PromptHighlight.OutlineTransparency = 0
		PromptHighlight.Parent = HighlightParent

		DestroyingCache[PromptHighlight] = prompt.Destroying:Once(function()
			PromptHighlight:Destroy()
			DestroyPromptBeam(prompt)
			if CurrentPrompt == prompt then
				CurrentPrompt = nil
				ProximityPromptUI.Enabled = false
				ResetHoldProgress()
			end
		end)
	end
end)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
	if prompt ~= CurrentPrompt or prompt.HoldDuration <= 0 then
		return
	end

	ResetHoldProgress()
	HoldTween = TweenService:Create(
		ProgressFill,
		TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 1) }
	)
	HoldTween:Play()
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
	if prompt == CurrentPrompt then
		ResetHoldProgress()
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if prompt == CurrentPrompt then
		ResetHoldProgress()
	end
end)

local Camera = workspace.CurrentCamera
CarryService.Carry:Connect(function()
	local PromptHighlight = Player.Character:FindFirstChild("Carried").Value:FindFirstChild("PromptHighlight")
	if PromptHighlight then
		PromptHighlight:Destroy()
	end

	workspace.CurrentCamera.CameraSubject = Player.Character:FindFirstChild("Carried").Value.PrimaryPart

	local CONN

	CONN = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if input.KeyCode == Enum.KeyCode.C then
			CarryService.Release:Fire()
			CONN:Disconnect()
			if not Player.Character then
				return
			end
			local HeadSubject = Player.Character:FindFirstChild("HeadSubject")
			local Humanoid = Player.Character:FindFirstChild("Humanoid")
			if Player:GetAttribute("AnimationsInfluence") then
				if HeadSubject then
					Camera.CameraSubject = HeadSubject
				end
			else
				if Humanoid then
					Camera.CameraSubject = Humanoid
				end
			end
		end
	end)
end)

PromptLabel.MouseButton1Down:Connect(function()
	if not CurrentPrompt or HeldPrompt then
		return
	end

	HeldPrompt = CurrentPrompt
	HeldPrompt:InputHoldBegin()
end)

local function EndButtonHold()
	if not HeldPrompt then
		return
	end

	HeldPrompt:InputHoldEnd()
	HeldPrompt = nil
end

PromptLabel.MouseButton1Up:Connect(EndButtonHold)
PromptLabel.MouseLeave:Connect(EndButtonHold)

PromptLabel.Destroying:Connect(function()
	EndButtonHold()
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	local Model = GetPromptModel(prompt)
	if not Model then
		DestroyPromptBeam(prompt)
		return
	end

	DestroyPromptBeam(prompt)
	local PromptHighlight = GetPromptHighlight(prompt)

	if PromptHighlight then
		local HighlightTween =
			TweenService:Create(PromptHighlight, TweenInfo.new(0.25), { FillTransparency = 1, OutlineTransparency = 1 })
		HighlightTween:Play()
		HighlightTween.Completed:Once(function()
			if PromptHighlight.Parent then
				PromptHighlight:Destroy()
			end
		end)
	end

	if PromptHighlight and DestroyingCache[PromptHighlight] then
		DestroyingCache[PromptHighlight]:Disconnect()
		DestroyingCache[PromptHighlight] = nil
	end

	if CurrentPrompt == prompt then
		if HeldPrompt == prompt then
			EndButtonHold()
		end
		CurrentPrompt = nil
		ResetHoldProgress()
		TweenService:Create(PromptScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.94,
		}):Play()
		task.delay(0.12, function()
			if not CurrentPrompt then
				ProximityPromptUI.Enabled = false
			end
		end)
	end
end)
