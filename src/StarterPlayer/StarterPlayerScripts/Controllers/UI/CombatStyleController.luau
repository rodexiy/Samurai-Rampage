local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local CombatStyleController = Knit.CreateController({ Name = "CombatStyleController" })
local Player = Players.LocalPlayer
local FightingStyle: TextLabel?
local SwordStyle: TextLabel?

local function Refresh()
	local Style = Player:GetAttribute("FightingStyle")

	if FightingStyle then
		FightingStyle.Text = "FIGHTING STYLE: " .. (if typeof(Style) == "string" and Style ~= "" then Style else "None")
	end
	if SwordStyle then
		SwordStyle.Text = "SWORD STYLE: " .. tostring(Player:GetAttribute("SwordStyle") or "Beginner")
	end
end

function CombatStyleController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	local Menu = PlayerGui:WaitForChild("Menu")
	local Meditate = Menu:WaitForChild("Meditate") :: ScreenGui
	FightingStyle = Meditate:FindFirstChild("FightingStyle") :: TextLabel?
	SwordStyle = Meditate:FindFirstChild("SwordStyle") :: TextLabel?
	Player:GetAttributeChangedSignal("FightingStyle"):Connect(Refresh)
	Player:GetAttributeChangedSignal("SwordStyle"):Connect(Refresh)
	Meditate:GetPropertyChangedSignal("Enabled"):Connect(Refresh)
	Refresh()
end

return CombatStyleController
