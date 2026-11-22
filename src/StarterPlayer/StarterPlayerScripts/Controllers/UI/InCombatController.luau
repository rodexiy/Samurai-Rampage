local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local InCombatController = Knit.CreateController({
	Name = "InCombatController",
})

local Player = Players.LocalPlayer
local InCombat: ScreenGui
local CutsceneUIController

local function UpdateVisibility()
	CutsceneUIController:SetGuiEnabled(InCombat, Player:GetAttribute("InCombat") == true)
end

function InCombatController.KnitInit()
	CutsceneUIController = Knit.GetController("CutsceneUIController")
end

function InCombatController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	local Hud = PlayerGui:WaitForChild("Hud")
	InCombat = Hud:WaitForChild("InCombat") :: ScreenGui

	Player:GetAttributeChangedSignal("InCombat"):Connect(UpdateVisibility)
	UpdateVisibility()
end

return InCombatController
