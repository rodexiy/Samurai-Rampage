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

function TetsuController:UpdateTestu(TetsuAmount)
	local TetsuAmount = TetsuAmount or TetsuService:GetTetsu()
	if not PreviousTetsu then
		PreviousTetsu = TetsuAmount
	end
	TetsuDisplay.Text = TetsuAmount

	local Difference = TetsuAmount - PreviousTetsu
	if Difference > 0 then
		TetsuController:Log(Difference)
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

	TetsuService.TetsuUpdated:Connect(function(TetsuAmount)
		TetsuController:UpdateTestu(TetsuAmount)
	end)

	TetsuController:UpdateTestu()
end

return TetsuController
