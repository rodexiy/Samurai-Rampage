local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BowConfig = require(ReplicatedStorage.Shared.BowConfig)
local BowFocusController = Knit.CreateController({ Name = "BowFocusController" })

local Gui: ScreenGui? = nil
local Group: CanvasGroup? = nil
local Fade: Tween? = nil
local Active = false

local function UpdateVisibility()
	if not Gui or not Group then
		return
	end

	if Fade then
		Fade:Cancel()
	end
	if Active then
		Gui.Enabled = true
		Group.Visible = true
	end

	local Tween = TweenService:Create(Group, TweenInfo.new(BowConfig.FocusFovTransitionTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		GroupTransparency = if Active then 0 else 1,
	})
	Fade = Tween
	Tween.Completed:Once(function(State: Enum.PlaybackState)
		if Fade ~= Tween or State ~= Enum.PlaybackState.Completed then
			return
		end

		Fade = nil
		if not Active and Group then
			Group.Visible = false
		end
	end)
	Tween:Play()
end

function BowFocusController:SetActive(Enabled: boolean)
	if Active == Enabled then
		return
	end

	Active = Enabled
	UpdateVisibility()
end

function BowFocusController.KnitStart()
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local Hud = PlayerGui:WaitForChild("Hud") :: ScreenGui
	Gui = Hud:WaitForChild("Focus") :: ScreenGui
	Group = Gui:WaitForChild("CanvasGroup") :: CanvasGroup
	Group.GroupTransparency = 1
	Group.Visible = false
	UpdateVisibility()
end

return BowFocusController
