local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TetsuController = Knit.CreateController({
	Name = "TetsuController",
})

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Player = game.Players.LocalPlayer
local PlayerGui
local Hud
local Tetsu
local content
local TetsuDisplay
local Template

local TetsuService
local SoundEffectController
local PreviousTetsu
local Info = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local MAX_SPECS = 50
local SpecsCache = {}
local SpecConnections = {}
local SpecDefaultSize = UDim2.fromScale(0.075, 0.075)

local function GetFreeSpec()
	for _, spec in ipairs(SpecsCache) do
		if not spec.Visible then
			return spec
		end
	end
	return nil
end

function TetsuController:Log(Amount)
	local Template = Template:Clone()

	Template.Position = TetsuDisplay.Position
		+ UDim2.fromScale(math.random(0, (TetsuDisplay.Size.X.Scale * 1000) / 2) / 1000, 0)
	Template.Visible = true
	Template.Name = "Log"
	Template.Text = if Amount > 0 then "+" .. Amount else "-" .. (math.abs(Amount))
	Template.Parent = content
	TweenService:Create(Template, Info, {
		Position = UDim2.fromScale(Template.Position.X.Scale, -0.85),
		TextTransparency = 1,
	}):Play()

	SoundEffectController:PlayRandomFromFolder("CoinsBagDrop", true)

	Debris:AddItem(Template, 2)
end

function TetsuController:TetsuScreenSpecs(NewTetsu: number, OldTetsu: number)
	local Earned = math.abs(OldTetsu - NewTetsu)
	local ratio = (Earned / OldTetsu)
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

		-- Move to the Tetsu coin with stagger
		task.delay(i * 0.01, function()
			local coinCenter = content.Coin.AbsolutePosition + (content.Coin.AbsoluteSize / 2)
			local relativeCenter = coinCenter - Tetsu.AbsolutePosition

			local OffsetX = math.random(-content.Coin.AbsoluteSize.X * 10, content.Coin.AbsoluteSize.X * 10) / 10
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

function TetsuController:UpdateTestu(TetsuAmount)
	local TetsuAmount = TetsuAmount or TetsuService:GetTetsu()
	if not PreviousTetsu then
		PreviousTetsu = TetsuAmount
	end
	TetsuDisplay.Text = TetsuAmount

	local Difference = TetsuAmount - PreviousTetsu
	if Difference > 0 then
		TetsuController:Log(Difference)
		TetsuController:TetsuScreenSpecs(TetsuAmount, PreviousTetsu)
	end
	PreviousTetsu = TetsuAmount
end

function TetsuController:KnitInit()
	TetsuService = Knit.GetService("TetsuService")
	SoundEffectController = Knit.GetController("SoundEffectController")
end
function TetsuController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Hud = PlayerGui:WaitForChild("Hud")
	Tetsu = Hud:WaitForChild("Tetsu")
	content = Tetsu:WaitForChild("content")
	TetsuDisplay = content:WaitForChild("TetsuDisplay")
	Template = content:WaitForChild("Template")
	local SpecTemplate = Tetsu.Specs

	TetsuService.TetsuUpdated:Connect(function(TetsuAmount)
		TetsuController:UpdateTestu(TetsuAmount)
	end)

	
	for i = 1, MAX_SPECS do
		local Spec = SpecTemplate:Clone()
		Spec.Name = "Spec" .. i
		Spec.Visible = false
		Spec.Parent = Tetsu
		table.insert(SpecsCache, Spec)
	end

	TetsuController:UpdateTestu()
end

return TetsuController