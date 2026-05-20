local Lighting = game:GetService("Lighting")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SettingsController = Knit.CreateController({
	Name = "SettingsController",
})

local SettingsService

local Player = game.Players.LocalPlayer
local PlayerGui
local Menu
local SettingsUI

local Toggles = {
	[true] = Color3.fromRGB(0, 255, 0),
	[false] = Color3.fromRGB(255, 0, 0),
}

function SettingsController:LoadSettings()
	for SettingName, SettingValue in SettingsService:GetSettings() do
		local Setting = SettingsUI:FindFirstChild(SettingName, true)
		if not Setting then
			continue
		end
		Setting.Toggle.ImageColor3 = Toggles[SettingValue]

		Setting.Activated:Connect(function()
			SettingsService:Toggle(SettingName)
			Setting.Toggle.ImageColor3 = Toggles[SettingsService:GetSettings()[SettingName]]
		end)
	end
end

function SettingsController:RemoveTextures()
	local TextLabel = Instance.new("TextLabel")
	TextLabel.TextScaled = true
	TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	TextLabel.Size = UDim2.new(1, 0, 0.025, 0)
	TextLabel.Position = UDim2.new(0, 0, 0.1, 0)

	for _, Part in game.ReplicatedStorage:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.Material = Enum.Material.SmoothPlastic
		end
		task.wait()
	end

	local Parts = workspace:GetDescendants()
	local amount = #Parts
	TextLabel.Text = "0/" .. amount
	TextLabel.Parent = Player.PlayerGui:WaitForChild("Hud")

	for i, Part in Parts do
		TextLabel.Text = i .. "/" .. amount
		if Part:IsA("BasePart") then
			Part.Material = Enum.Material.SmoothPlastic
		end
		task.wait()
	end

	TextLabel:Destroy()
end

function SettingsController:BindSettingsChange()
	Lighting.GlobalShadows = Player:GetAttribute("Shadows")

	Player:GetAttributeChangedSignal("Shadows"):Connect(function()
		Lighting.GlobalShadows = Player:GetAttribute("Shadows")
	end)
end

function SettingsController.KnitInit()
	SettingsService = Knit.GetService("SettingsService")
end

function SettingsController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Menu = PlayerGui:WaitForChild("Menu")
	SettingsUI = Menu:WaitForChild("Settings")

	SettingsController:LoadSettings()

	SettingsController:BindSettingsChange()
end

return SettingsController
