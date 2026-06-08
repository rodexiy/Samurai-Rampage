local Knit = require(game.ReplicatedStorage.Packages.Knit)

local CarryService
local InteractionService
local InteractionController
local LoadedServices = false

Knit.OnStart():andThen(function()
	CarryService = Knit.GetService("CarryService")
	InteractionService = Knit.GetService("InteractionService")
	InteractionController = Knit.GetController("InteractionController")
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

local DestroyingCache = {}
local Collector = require(game.ReplicatedStorage.Shared.Collector)

local Connections = Collector.new()

local CurrentPrompt = nil
local PromptBeams = {}

local BEAM_NAME = "PromptBeam"
local TARGET_ATTACHMENT_NAME = "PromptBeamTargetAttachment"
local CHARACTER_ATTACHMENT_NAME = "PromptBeamCharacterAttachment"

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
	Beam.Name = BEAM_NAME
	Beam.Attachment0 = TargetAttachment
	Beam.Attachment1 = CharacterAttachment
	Beam.Color = ColorSequence.new(Color3.fromRGB(255, 233, 188))
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
	PromptLabel.Text = `'` .. Key .. `' ` .. prompt.ActionText
	CurrentPrompt = prompt
	CreatePromptBeam(prompt)
	if not GetPromptHighlight(prompt) then
		local PromptHighlight = Instance.new("Highlight")
		PromptHighlight.Name = "PromptHighlight"
		PromptHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
		PromptHighlight.FillTransparency = 0.85
		PromptHighlight.OutlineColor = Color3.fromRGB(250, 250, 250)
		PromptHighlight.FillColor = Color3.fromRGB(250, 250, 250)
		PromptHighlight.OutlineTransparency = 0
		PromptHighlight.Parent = HighlightParent

		DestroyingCache[PromptHighlight] = prompt.Destroying:Once(function()
			PromptHighlight:Destroy()
			DestroyPromptBeam(prompt)
			ProximityPromptUI.Enabled = false
		end)
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

PromptLabel.Activated:Connect(function()
	InteractionController.ButtonTriggered(CurrentPrompt, Player)
	InteractionService:Interact(CurrentPrompt, CurrentPrompt:GetAttribute("callback"))
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	local Model = GetPromptModel(prompt)
	if not Model then
		DestroyPromptBeam(prompt)
		return
	end

	ProximityPromptUI.Enabled = false
	CurrentPrompt = nil
	DestroyPromptBeam(prompt)
	local PromptHighlight = GetPromptHighlight(prompt)

	if PromptHighlight then
		TweenService:Create(PromptHighlight, TweenInfo.new(0.5), { FillTransparency = 1, OutlineTransparency = 1 })
			:Play()

		task.wait(0.5)
		PromptHighlight:Destroy()
	end

	if PromptHighlight and DestroyingCache[PromptHighlight] then
		DestroyingCache[PromptHighlight]:Disconnect()
		DestroyingCache[PromptHighlight] = nil
	end
end)
