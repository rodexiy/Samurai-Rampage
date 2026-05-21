local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

for _, ui in game.ReplicatedStorage.Assets.UIS:GetChildren() do
	if ui:IsA("ScreenGui") then
		ui:Clone().Parent = StarterGui
	end
end

for _, ui in game.ReplicatedStorage.Assets.UIS:GetChildren() do
	if ui:IsA("ScreenGui") and not PlayerGui:FindFirstChild(ui.Name) then
		ui:Clone().Parent = PlayerGui
	end
end

task.spawn(function()
	local StarterGui = game:GetService("StarterGui")

	repeat
		local success = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)

			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		task.wait()
	until success
end)

local Knit = require(game.ReplicatedStorage.Packages.Knit)

for _, v in script:GetDescendants() do
	if v:IsA("ModuleScript") and v.Name:match("Controller$") then
		require(v)
	end
end

local Camera = workspace.CurrentCamera
-- Camera.FieldOfView = 75

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))
Cmdr:SetActivationKeys({})

repeat
	task.wait()
until Player:GetAttribute("Loaded")
Knit.Start({ ServicePromises = false }):catch(warn):await()
print("[KNIT]: Client started!")

local LoadingService = Knit.GetService("LoadingService")
LoadingService:KnitClientLoaded()
