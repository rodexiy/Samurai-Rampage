local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local FearController = Knit.CreateController({ Name = "FearController" })
local Player = Players.LocalPlayer
local CameraController
local Correction: ColorCorrectionEffect?
local Transition: Tween?
local BrightnessPulse: Tween?
local FearLevel = 0

local function StopBrightnessPulse()
	if BrightnessPulse then
		BrightnessPulse:Cancel()
		BrightnessPulse = nil
	end
end

local function UpdateFear(Level: number)
	FearLevel = Level
	local Darkness = 0.2 * math.sqrt(math.clamp(Level / 50, 0, 1))
	local ShakeStrength = math.clamp((Level - 25) / 50, 0, 1)
	CameraController:SetFearShake(ShakeStrength)
	if not Correction then
		return
	end

	if Transition then
		Transition:Cancel()
	end

	local Desaturated = Level >= 80
	local PulseBrightness = Level > 90
	if not PulseBrightness then
		StopBrightnessPulse()
	end

	local Goals: { [string]: number } = { Saturation = if Desaturated then -1 else 0 }
	if not PulseBrightness or not BrightnessPulse then
		Goals.Brightness = if PulseBrightness then -0.1 else -Darkness
	end

	Transition = TweenService:Create(Correction, TweenInfo.new(0.35, Enum.EasingStyle.Sine), Goals)
	if PulseBrightness and not BrightnessPulse then
		local Effect = Correction
		Transition.Completed:Once(function(State: Enum.PlaybackState)
			if State ~= Enum.PlaybackState.Completed or Correction ~= Effect or FearLevel <= 90 or BrightnessPulse then
				return
			end

			BrightnessPulse = TweenService:Create(
				Effect,
				TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Brightness = 0.1 }
			)
			BrightnessPulse:Play()
		end)
	end
	Transition:Play()
end

local function BindCamera()
	-- Camera-local effects survive LightLoader replacing the active Lighting preset.
	StopBrightnessPulse()
	if Transition then
		Transition:Cancel()
		Transition = nil
	end
	if Correction then
		Correction:Destroy()
	end

	Correction = Instance.new("ColorCorrectionEffect")
	Correction.Name = "FearColorCorrection"
	Correction.Parent = workspace.CurrentCamera
	UpdateFear(FearLevel)
end

function FearController.KnitInit()
	CameraController = Knit.GetController("CameraController")
end

function FearController.KnitStart()
	local FearService = Knit.GetService("FearService")
	FearService.FearChanged:Connect(UpdateFear)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(BindCamera)

	BindCamera()
	UpdateFear(Player:GetAttribute("Fear") or 0)
end

return FearController
