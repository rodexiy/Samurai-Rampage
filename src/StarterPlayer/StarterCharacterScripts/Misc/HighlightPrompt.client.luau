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

ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType)
	local Model = prompt.Parent

	local Key

	if UserInputService.GamepadEnabled then
		Key = prompt.GamepadKeyCode.Name
	else
		Key = prompt.KeyboardKeyCode.Name
	end

	if Model:FindFirstChild("PromptHighlight") then
		Model:FindFirstChild("PromptHighlight"):Destroy()
	end

	ProximityPromptUI.Enabled = true
	PromptLabel.Text = `'` .. Key .. `' ` .. prompt.ActionText
	CurrentPrompt = prompt
	if not Model:FindFirstChild("PromptHighlight") then
		local PromptHighlight = Instance.new("Highlight")
		PromptHighlight.Name = "PromptHighlight"
		PromptHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
		PromptHighlight.FillTransparency = 0.1
		PromptHighlight.OutlineColor = Color3.fromRGB(250, 250, 250)
		PromptHighlight.FillColor = Color3.fromRGB(250, 250, 250)
		PromptHighlight.OutlineTransparency = 0.1
		PromptHighlight.Parent = Model

		TweenService
			:Create(PromptHighlight, TweenInfo.new(0.5), { FillTransparency = 0.75, OutlineTransparency = 0.75 })
			:Play()

		DestroyingCache[PromptHighlight] = prompt.Destroying:Once(function()
			PromptHighlight:Destroy()
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
	local Model = prompt.Parent
	if not Model then
		return
	end

	ProximityPromptUI.Enabled = false
	CurrentPrompt = nil
	local PromptHighlight = Model:FindFirstChild("PromptHighlight")

	if PromptHighlight then
		TweenService:Create(PromptHighlight, TweenInfo.new(0.5), { FillTransparency = 1, OutlineTransparency = 1 })
			:Play()

		task.wait(0.5)
		PromptHighlight:Destroy()
	end

	if DestroyingCache[PromptHighlight] then
		DestroyingCache[PromptHighlight]:Disconnect()
	end
end)
