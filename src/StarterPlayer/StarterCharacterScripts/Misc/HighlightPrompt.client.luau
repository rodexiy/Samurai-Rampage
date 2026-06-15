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
local WorldPromptUI = game.ReplicatedStorage.Assets.Billboards.PickablePrompt:Clone()
WorldPromptUI.Name = "WorldPickablePrompt"
WorldPromptUI.Enabled = false
WorldPromptUI.Parent = PlayerGui

local SCREEN_PROMPT_POSITION = UDim2.new(0.5, 0, 0.9, 0)

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

local PromptScale = PromptLabel:WaitForChild("PromptScale")
local KeyBadge = PromptLabel:WaitForChild("KeyBadge")
local KeyStroke = KeyBadge:WaitForChild("KeyStroke")
local KeyLabel = KeyBadge:WaitForChild("KeyLabel")
local Content = PromptLabel:WaitForChild("Content")
local ActionLabel = Content:WaitForChild("ActionLabel")
local ObjectLabel = Content:WaitForChild("ObjectLabel")
local ObjectGradient = ObjectLabel:WaitForChild("ObjectGradient")
local RarityLabel = Content:WaitForChild("RarityLabel")

local WorldPromptLabel = WorldPromptUI:WaitForChild("TextLabel")
local WorldPromptScale = WorldPromptLabel:WaitForChild("PromptScale")
local WorldKeyBadge = WorldPromptLabel:WaitForChild("KeyBadge")
local WorldKeyStroke = WorldKeyBadge:WaitForChild("KeyStroke")
local WorldKeyLabel = WorldKeyBadge:WaitForChild("KeyLabel")
local WorldContent = WorldPromptLabel:WaitForChild("Content")
local WorldActionLabel = WorldContent:WaitForChild("ActionLabel")
local WorldObjectLabel = WorldContent:WaitForChild("ObjectLabel")
local WorldObjectGradient = WorldObjectLabel:WaitForChild("ObjectGradient")
local WorldRarityLabel = WorldContent:WaitForChild("RarityLabel")




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
end

local function ApplyPromptAppearance(Prompt: ProximityPrompt, Key: string)
	local Colors = GetRarityColors(Prompt)
	local Rarity = Prompt:GetAttribute("Rarity") or "Common"
	local IsPickable = Prompt:GetAttribute("Pickable") == true or Prompt:GetAttribute("callback") == "Pick"
	local DisplayName = Prompt:GetAttribute("DisplayName") or Prompt.ObjectText
	local ActivePromptScale = if IsPickable then WorldPromptScale else PromptScale
	local ActiveKeyLabel = if IsPickable then WorldKeyLabel else KeyLabel
	local ActiveActionLabel = if IsPickable then WorldActionLabel else ActionLabel
	local ActiveObjectLabel = if IsPickable then WorldObjectLabel else ObjectLabel
	local ActiveRarityLabel = if IsPickable then WorldRarityLabel else RarityLabel
	local ActiveKeyStroke = if IsPickable then WorldKeyStroke else KeyStroke
	local ActiveObjectGradient = if IsPickable then WorldObjectGradient else ObjectGradient

	if DisplayName == "" and Prompt.Parent then
		DisplayName = Prompt.Parent.Name
	end

	ActiveKeyLabel.Text = Key:gsub("Button", "")
	ActiveActionLabel.Text = string.upper(Prompt.ActionText ~= "" and Prompt.ActionText or "Interact")
	ActiveObjectLabel.Text = DisplayName
	ActiveRarityLabel.Text = string.upper(Rarity)
	ActiveRarityLabel.TextColor3 = Colors.Primary
	ActiveRarityLabel.Visible = IsPickable or Prompt:GetAttribute("Rarity") ~= nil

	local RarityGradient = ColorSequence.new(Colors.Primary, Colors.Secondary)
	ActiveKeyStroke.Color = Colors.Primary
	ActiveObjectGradient.Color = RarityGradient

	ResetHoldProgress()
	ActivePromptScale.Scale = 0.92
	TweenService:Create(ActivePromptScale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
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

local function IsPickablePrompt(Prompt: ProximityPrompt): boolean
	return Prompt:GetAttribute("Pickable") == true or Prompt:GetAttribute("callback") == "Pick"
end

local function ShowPromptUI(Prompt: ProximityPrompt)
	if IsPickablePrompt(Prompt) then
		local TargetPart = GetPromptTargetPart(Prompt)
		if TargetPart then
			WorldPromptUI.Adornee = TargetPart
			ProximityPromptUI.Enabled = false
			WorldPromptUI.Enabled = true
			return
		end
	end

	WorldPromptUI.Enabled = false
	WorldPromptUI.Adornee = nil
	PromptLabel.Position = SCREEN_PROMPT_POSITION
	ProximityPromptUI.Enabled = true
end

local function HidePromptUI()
	ProximityPromptUI.Enabled = false
	WorldPromptUI.Enabled = false
	WorldPromptUI.Adornee = nil
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

	if IsPickablePrompt(Prompt) then
		return
	end

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

	CurrentPrompt = prompt
	ShowPromptUI(prompt)
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
		if IsPickablePrompt(prompt) then
			PromptHighlight.Adornee = GetPromptTargetPart(prompt)
		end
		PromptHighlight.Parent = HighlightParent

		DestroyingCache[PromptHighlight] = prompt.Destroying:Once(function()
			PromptHighlight:Destroy()
			DestroyPromptBeam(prompt)
			if CurrentPrompt == prompt then
				CurrentPrompt = nil
				HidePromptUI()
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

local function EndButtonHold()
	if not HeldPrompt then
		return
	end

	HeldPrompt:InputHoldEnd()
	HeldPrompt = nil
end

local function BindPromptButton(Button: TextButton)
	Button.MouseButton1Down:Connect(function()
		if not CurrentPrompt or HeldPrompt then
			return
		end

		HeldPrompt = CurrentPrompt
		HeldPrompt:InputHoldBegin()
	end)

	Button.MouseButton1Up:Connect(EndButtonHold)
	Button.Destroying:Connect(EndButtonHold)
end

BindPromptButton(PromptLabel)
BindPromptButton(WorldPromptLabel)

UserInputService.InputEnded:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
		EndButtonHold()
	end
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
		local ActivePromptScale = if IsPickablePrompt(prompt) then WorldPromptScale else PromptScale
		TweenService:Create(ActivePromptScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.94,
		}):Play()
		task.delay(0.12, function()
			if not CurrentPrompt then
				HidePromptUI()
			end
		end)
	end
end)
