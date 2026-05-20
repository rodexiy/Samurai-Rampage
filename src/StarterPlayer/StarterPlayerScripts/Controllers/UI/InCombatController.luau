local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InCombatController = Knit.CreateController({
	Name = "InCombatController",
})

local Player = game.Players.LocalPlayer
local PlayerGui
local Hud
local InCombat

function InCombatController.KnitInit() end

function InCombatController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Hud = PlayerGui:WaitForChild("Hud")
	InCombat = Hud:WaitForChild("InCombat")

	Player:GetAttributeChangedSignal("InCombat"):Connect(function()
		InCombat.Enabled = Player:GetAttribute("InCombat") or false
	end)
end

return InCombatController
