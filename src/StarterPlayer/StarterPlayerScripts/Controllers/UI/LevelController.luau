local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local LevelController = Knit.CreateController({
	Name = "LevelController",
})

local LevelService

local Player = game.Players.LocalPlayer
local PlayerGui
local Hud
local LevelUI
local Content
local Exp
local Level
local LevelDark
local ExpBar
local Bar

local LevelFunctions = require(game.ReplicatedStorage.Shared.LevelFunctions)

local SpecTemplate
local SpecDefaultSize = UDim2.fromScale(0.03, 0.03)
local MAX_SPECS = 50
local SpecsCache = {}
local SpecConnections = {}

local function GetFreeSpec()
	for _, spec in ipairs(SpecsCache) do
		if not spec.Visible then
			return spec
		end
	end
	return nil
end

function LevelController:ExperienceScreenSpecs(NewExp: number, OldExp: number)
	local Earned = math.abs(OldExp - NewExp)
	local ratio = (Earned / OldExp)
	local specCount = math.clamp(math.floor(MAX_SPECS * ratio), 2, MAX_SPECS)

	for i = 1, specCount do
		local Spec = GetFreeSpec()
		if not Spec then
			break
		end

		if SpecConnections[Spec] then
			SpecConnections[Spec]:Disconnect()
			SpecConnections[Spec] = nil
		end

		-- Spawn randomly on screen
		Spec.Position = UDim2.fromScale(math.random(100, 900) / 1000, math.random(100, 900) / 1000)
		Spec.Size = UDim2.fromScale(0, 0)
		Spec.ImageTransparency = 1
		Spec.Visible = true

		-- Pop-in (overshoot + fade-in)
		local sizeOvershoot = SpecDefaultSize
		local popTween = TweenService:Create(
			Spec,
			TweenInfo.new(math.random(20, 35) / 100, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = sizeOvershoot, ImageTransparency = 0 }
		)
		popTween:Play()

		-- Move to EXP bar with stagger
		task.delay(i * 0.01, function()
			local barCenter = ExpBar.AbsolutePosition + (ExpBar.AbsoluteSize / 2)
			local parentPos = LevelUI.AbsolutePosition
			local relativeCenter = barCenter - parentPos

			local OffsetX = math.random(-ExpBar.AbsoluteSize.X * 10, ExpBar.AbsoluteSize.X * 10) / 10
			local targetX = relativeCenter.X + OffsetX
			local targetY = relativeCenter.Y

			local moveTime = math.random(40, 70) / 100
			local moveTween = TweenService:Create(
				Spec,
				TweenInfo.new(moveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ Position = UDim2.fromOffset(targetX, targetY) }
			)

			moveTween.Completed:Connect(function()
				-- Fade out + shrink
				local fadeTween = TweenService:Create(
					Spec,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = UDim2.fromScale(0, 0), ImageTransparency = 1 }
				)
				fadeTween.Completed:Connect(function()
					Spec.Visible = false
					SpecConnections[Spec] = nil
				end)
				fadeTween:Play()
			end)
			SpecConnections[Spec] = moveTween.Completed
			moveTween:Play()
		end)
	end
end

local currentExpValue = Instance.new("NumberValue")
currentExpValue.Value = 0
local expConn

local OldExp = 0
function LevelController:UpdateUI(NewExp, LevelV)
	if OldExp and NewExp and OldExp > NewExp then
		OldExp = 0
	end
	if not NewExp then
		NewExp, LevelV = LevelService:GetExpLevel()
		OldExp = NewExp
	else
		LevelController:ExperienceScreenSpecs(NewExp, OldExp)
	end

	local ExpNeeded = LevelFunctions:GetPlayerLevelExpNeeded(LevelV)
	Level.Text = LevelV
	LevelDark.Text = LevelV

	local exp = math.clamp(NewExp / ExpNeeded, 0, 1)
	TweenService:Create(Bar, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(exp, 1),
	}):Play()

	if expConn then
		expConn:Disconnect()
	end

	local textTween =
		TweenService:Create(currentExpValue, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { Value = NewExp })
	textTween:Play()

	expConn = currentExpValue:GetPropertyChangedSignal("Value"):Connect(function()
		Exp.Text = math.round(currentExpValue.Value) .. "/" .. math.round(ExpNeeded)
	end)

	OldExp = NewExp
end

function LevelController.KnitInit()
	LevelService = Knit.GetService("LevelService")
end

function LevelController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Hud = PlayerGui:WaitForChild("Hud")
	LevelUI = Hud:WaitForChild("Level")
	Content = LevelUI:WaitForChild("content")
	Exp = Content:WaitForChild("Exp")
	Level = Content:WaitForChild("Level")
	LevelDark = Content:WaitForChild("LevelDark")
	ExpBar = Content:WaitForChild("ExpBar")
	Bar = ExpBar:WaitForChild("Bar")
	SpecTemplate = Content:WaitForChild("SpecTemplate")

	for i = 1, MAX_SPECS do
		local Spec = SpecTemplate:Clone()
		Spec.Name = "Spec" .. i
		Spec.Visible = false
		Spec.Parent = LevelUI
		table.insert(SpecsCache, Spec)
	end

	LevelService.ExpUpdated:Connect(function(Exp, Level)
		LevelController:UpdateUI(Exp, Level)
	end)

	LevelController:UpdateUI()
end

return LevelController
