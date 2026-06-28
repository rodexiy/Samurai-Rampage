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

local function SetSettingLabel(Setting: Instance, Text: string)
	for _, Descendant in Setting:GetDescendants() do
		if Descendant:IsA("TextLabel") or Descendant:IsA("TextButton") then
			if Descendant.Name ~= "Toggle" then
				Descendant.Text = Text
				return
			end
		end
	end
end

function SettingsController:EnsureSettingButton(SettingName: string)
	if SettingsUI:FindFirstChild(SettingName, true) then
		return
	end

	if SettingName == "OST" then
		local Template = SettingsUI:FindFirstChild("Ambience", true) or SettingsUI:FindFirstChild("Shadows", true)
		if not Template then
			return
		end

		local Setting = Template:Clone()
		Setting.Name = SettingName
		SetSettingLabel(Setting, SettingName)
		Setting.Parent = Template.Parent
	elseif SettingName == "Birds" then
		local Gameplay = SettingsUI:FindFirstChild("Gameplay", true)
		if not Gameplay then
			return
		end

		local Environment = Gameplay:Clone()
		Environment.Name = "Environment"

		local Title = Environment:FindFirstChild("1 Title")
		if Title and Title:IsA("TextLabel") then
			Title.Text = " • Environment"
		end

		local Setting = Environment:FindFirstChild("LagCompensation")
		if not Setting then
			Environment:Destroy()
			return
		end

		Setting.Name = SettingName
		SetSettingLabel(Setting, SettingName)
		Environment.Parent = Gameplay.Parent
	end
end

function SettingsController:LoadSettings()
	for SettingName, SettingValue in SettingsService:GetSettings() do
		SettingsController:EnsureSettingButton(SettingName)

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
