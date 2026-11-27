local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SettingsController = Knit.CreateController({
	Name = "SettingsController",
})

local SettingsService
local MenuController

local Player = Players.LocalPlayer
local PlayerGui: PlayerGui
local Menu: ScreenGui
local SettingsUI: ScreenGui

local Toggles = {
	[true] = Color3.fromRGB(0, 255, 0),
	[false] = Color3.fromRGB(255, 0, 0),
}

function SettingsController:LoadSettings()
	for SettingName, SettingValue in SettingsService:GetSettings() do
		local Setting = SettingsUI:FindFirstChild(SettingName, true) :: ImageButton?
		if not Setting then
			continue
		end

		local Toggle = Setting:FindFirstChild("Toggle") :: ImageButton?
		if not Toggle then
			continue
		end

		Toggle.ImageColor3 = Toggles[SettingValue]

		local function ToggleSetting()
			SettingsService:Toggle(SettingName)
			Toggle.ImageColor3 = Toggles[SettingsService:GetSettings()[SettingName]]
		end
		Setting.Activated:Connect(ToggleSetting)
		Toggle.Activated:Connect(ToggleSetting)
		Player:GetAttributeChangedSignal(SettingName):Connect(function()
			Toggle.ImageColor3 = Toggles[Player:GetAttribute(SettingName) == true]
		end)
	end
end

function SettingsController:RemoveTextures()
	local TextLabel = Instance.new("TextLabel")
	TextLabel.TextScaled = true
	TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	TextLabel.Size = UDim2.fromScale(1, 0.025)
	TextLabel.Position = UDim2.fromScale(0, 0.1)

	for _, Part in ReplicatedStorage:GetDescendants() do
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
	MenuController = Knit.GetController("MenuController")
end

function SettingsController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	Menu = PlayerGui:WaitForChild("Menu") :: ScreenGui
	SettingsUI = Menu:WaitForChild("Settings") :: ScreenGui

	local Background = SettingsUI:WaitForChild("background") :: Frame
	local Close = Background:WaitForChild("Close") :: ImageButton
	MenuController:BindCloseButton(Close, function()
		MenuController:CloseAllMenus()
	end)

	SettingsController:LoadSettings()

	SettingsController:BindSettingsChange()
end

return SettingsController
