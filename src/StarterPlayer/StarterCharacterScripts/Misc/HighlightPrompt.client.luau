local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Collector = require(ReplicatedStorage.Shared.Collector)
local Connections = Collector.new()
local ActivePromptConnections = Collector.new()

local CarryService
local LoadedServices = false

Knit.OnStart():andThen(function()
	CarryService = Knit.GetService("CarryService")
	LoadedServices = true
end)

local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local OwnerCharacter = Player.Character
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
local WorldPromptUI = ReplicatedStorage.Assets.Billboards.PickablePrompt:Clone()
WorldPromptUI.Name = "WorldPickablePrompt"
WorldPromptUI.Enabled = false
WorldPromptUI.Parent = PlayerGui

local SCREEN_PROMPT_POSITION = UDim2.fromScale(0.5, 0.9)

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

local PromptScale = PromptLabel:FindFirstChildWhichIsA("UIScale")
local KeyBadge = PromptLabel:WaitForChild("KeyBadge")
local KeyLabel = KeyBadge:WaitForChild("KeyLabel")
local Content = PromptLabel:WaitForChild("Content")
local ActionLabel = Content:WaitForChild("ActionLabel")
local ObjectLabel = Content:WaitForChild("ObjectLabel")
local ObjectGradient = ObjectLabel:WaitForChild("ObjectGradient")
local RarityLabel = Content:WaitForChild("RarityLabel")

local WorldPromptLabel = WorldPromptUI:WaitForChild("TextLabel")
local WorldPromptScale = WorldPromptLabel:FindFirstChildWhichIsA("UIScale")
local WorldKeyBadge = WorldPromptLabel:WaitForChild("KeyBadge")
local WorldKeyLabel = WorldKeyBadge:WaitForChild("KeyLabel")
local WorldContent = WorldPromptLabel:WaitForChild("Content")
local WorldActionLabel = WorldContent:WaitForChild("ActionLabel")
local WorldObjectLabel = WorldContent:WaitForChild("ObjectLabel")
local WorldObjectGradient = WorldObjectLabel:WaitForChild("ObjectGradient")
local WorldRarityLabel = WorldContent:WaitForChild("RarityLabel")




local PromptHighlights: { [ProximityPrompt]: Highlight } = {}
local CurrentPrompt: ProximityPrompt? = nil
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

local function StopHeldPrompt()
	if not HeldPrompt then
		return
	end

	local Prompt = HeldPrompt
	HeldPrompt = nil
	if Prompt.Parent then
		Prompt:InputHoldEnd()
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
	ActiveObjectGradient.Color = RarityGradient

	ResetHoldProgress()
	if ActivePromptScale then
		ActivePromptScale.Scale = 0.92
		TweenService:Create(ActivePromptScale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end
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
	return PromptHighlights[Prompt]
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

local function IsPromptSuppressed(): boolean
	return Player:GetAttribute("InDialog") == true
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

local function DestroyPromptHighlight(Prompt: ProximityPrompt, Fade: boolean?)
	local PromptHighlight = GetPromptHighlight(Prompt)
	if not PromptHighlight then
		return
	end

	PromptHighlights[Prompt] = nil

	if Fade and PromptHighlight.Parent then
		local Tween = TweenService:Create(
			PromptHighlight,
			TweenInfo.new(0.25),
			{ FillTransparency = 1, OutlineTransparency = 1 }
		)
		Tween.Completed:Once(function()
			PromptHighlight:Destroy()
		end)
		Tween:Play()
	else
		PromptHighlight:Destroy()
	end
end

local function HideActivePrompt(Fade: boolean?)
	ActivePromptConnections:DisconnectAll()
	local Prompt = CurrentPrompt
	CurrentPrompt = nil
	StopHeldPrompt()

	if Prompt then
		DestroyPromptBeam(Prompt)
		DestroyPromptHighlight(Prompt, Fade)
	end

	ResetHoldProgress()
	HidePromptUI()
end

local function CreatePromptBeam(Prompt: ProximityPrompt)
	DestroyPromptBeam(Prompt)

	local Character = Player.Character
	local RootPart = Character and Character.PrimaryPart
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

Connections:Add(Player:GetAttributeChangedSignal("InDialog"):Connect(function()
	if IsPromptSuppressed() then
		HideActivePrompt()
	end
end))

Connections:Add(ProximityPromptUI:GetPropertyChangedSignal("Enabled"):Connect(function()
	if ProximityPromptUI.Enabled then
		local Prompt = CurrentPrompt
		if not Prompt or not Prompt.Enabled or not Prompt:IsDescendantOf(workspace)
			or IsPromptSuppressed() or WorldPromptUI.Adornee ~= nil then
			ProximityPromptUI.Enabled = false
		end
	end
end))

Connections:Add(ProximityPromptService:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not ProximityPromptService.Enabled then
		HideActivePrompt()
	end
end))

Connections:Add(ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	if IsPromptSuppressed() then
		HideActivePrompt()
		return
	end

	if not prompt.Enabled or not prompt:IsDescendantOf(workspace) or not ProximityPromptService.Enabled then
		return
	end

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

	HideActivePrompt()

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
			PromptHighlight.Adornee = prompt.Parent
		end
		PromptHighlight.Parent = HighlightParent
		PromptHighlights[prompt] = PromptHighlight
	end

	ActivePromptConnections:Add(prompt.Destroying:Once(function()
		if CurrentPrompt == prompt then
			HideActivePrompt()
		end
	end))
	ActivePromptConnections:Add(prompt.AncestryChanged:Connect(function()
		if CurrentPrompt == prompt and not prompt:IsDescendantOf(workspace) then
			HideActivePrompt()
		end
	end))
	ActivePromptConnections:Add(prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if CurrentPrompt == prompt and not prompt.Enabled then
			HideActivePrompt(true)
		end
	end))
end))

Connections:Add(ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
	if prompt ~= CurrentPrompt or prompt.HoldDuration <= 0 then
		return
	end

	ResetHoldProgress()
end))

Connections:Add(ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
	if prompt == CurrentPrompt then
		ResetHoldProgress()
	end
end))

Connections:Add(ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if prompt == CurrentPrompt then
		ResetHoldProgress()
	end
end))

local Camera = workspace.CurrentCamera
Connections:Add(CarryService.Carry:Connect(function()
	local PromptHighlight = Player.Character:FindFirstChild("Carried").Value:FindFirstChild("PromptHighlight")
	if PromptHighlight then
		PromptHighlight:Destroy()
	end

	Camera.CameraSubject = Player.Character:FindFirstChild("Carried").Value.PrimaryPart

	local CONN

	CONN = UserInputService.InputBegan:Connect(function(input: InputObject)
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
	Connections:Add(CONN)
end))

local function EndButtonHold()
	StopHeldPrompt()
end

local function BindPromptButton(Button: TextButton)
	Connections:Add(Button.MouseButton1Down:Connect(function()
		if not CurrentPrompt or HeldPrompt then
			return
		end

		HeldPrompt = CurrentPrompt
		HeldPrompt:InputHoldBegin()
	end))

	Connections:Add(Button.MouseButton1Up:Connect(EndButtonHold))
	Connections:Add(Button.Destroying:Connect(EndButtonHold))
end

BindPromptButton(PromptLabel)
BindPromptButton(WorldPromptLabel)

Connections:Add(UserInputService.InputEnded:Connect(function(Input: InputObject)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
		EndButtonHold()
	end
end))

Connections:Add(ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	if CurrentPrompt == prompt then
		HideActivePrompt(true)
		return
	end

	DestroyPromptBeam(prompt)
	DestroyPromptHighlight(prompt, true)
end))

local CleanedUp = false
local function Cleanup()
	if CleanedUp then
		return
	end

	CleanedUp = true
	Connections:DisconnectAll()
	HideActivePrompt()
	WorldPromptUI:Destroy()
end

Connections:Add(Player.CharacterRemoving:Connect(function(Character: Model)
	if Character == OwnerCharacter then
		Cleanup()
	end
end))
script.Destroying:Connect(Cleanup)

HidePromptUI()
