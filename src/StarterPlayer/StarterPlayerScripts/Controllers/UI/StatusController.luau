local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local StatusController = Knit.CreateController({
	Name = "StatusController",
})

local Player = game.Players.LocalPlayer
local Character

local PlayerGui
local Hud
local DamageGui

local Tween1
local Tween2
local DamageTransparency = 1
local lastDmgTick = 0

function easeOutQuart(x: number)
	return x * x * x
end

local PreviousHealth
function StatusController:UpdateHealth()
	if not PreviousHealth then
		PreviousHealth = Character:GetAttribute("MaxHealth")
	end

	local NewHealth = Character:GetAttribute("Health")

	DamageTransparency = (NewHealth / (Character:GetAttribute("MaxHealth") * 0.5))

	local CanvasGroup = DamageGui.CanvasGroup :: CanvasGroup
	local DamageTF = TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

	if PreviousHealth > NewHealth then
		local Difference = PreviousHealth - NewHealth
		local Multiplier = (1 / Difference) * (easeOutQuart(DamageTransparency))

		task.spawn(function()
			Tween1 = TweenService:Create(CanvasGroup, DamageTF, { GroupTransparency = Multiplier })
			Tween2 =
				TweenService:Create(CanvasGroup, DamageTF, { GroupTransparency = easeOutQuart(DamageTransparency) })

			Tween1:Play()
			task.wait(0.15)
			if tick() - lastDmgTick >= 0.1 then
				Tween2:Play()
			end
		end)
	else
		TweenService:Create(CanvasGroup, DamageTF, { GroupTransparency = easeOutQuart(DamageTransparency) }):Play()
	end

	PreviousHealth = NewHealth
end

function StatusController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Hud = PlayerGui:WaitForChild("Hud")
	DamageGui = Hud:WaitForChild("Damage")

	Character = Player.Character
	Player.CharacterAdded:Connect(function(character)
		Character = character
		PreviousHealth = nil
	end)
end

return StatusController
