local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SettingsController = Knit.CreateController({
	Name = "SettingsController",
})

local SettingsService

local Player = Players.LocalPlayer
local PlayerGui
local Menu
local SettingsUI

local Toggles = {
	[true] = Color3.fromRGB(0, 255, 0),
	[false] = Color3.fromRGB(255, 0, 0),
}

local function SetSettingLabel(Setting: Instance, Text: string)
	for _, Descendant in Setting:QueryDescendants("GuiObject") do
		if (Descendant:IsA("TextLabel") or Descendant:IsA("TextButton")) and Descendant.Name ~= "Toggle" then
			Descendant.Text = Text
			return
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
	elseif SettingName == "Birds" or SettingName == "ClothCut" or SettingName == "SmartBone" then
		local Gameplay = SettingsUI:FindFirstChild("Gameplay", true)
		if not Gameplay then
			return
		end

		local Template = Gameplay:FindFirstChild("LagCompensation") :: ImageButton?
		if not Template then
			return
		end

		local Environment = SettingsUI:FindFirstChild("Environment", true) :: Frame?
		if not Environment then
			Environment = Gameplay:Clone() :: Frame
			Environment.Name = "Environment"
			Environment.AutomaticSize = Enum.AutomaticSize.Y
			Environment.Size = UDim2.fromScale(1, 0)
			local Layout = Environment:FindFirstChildWhichIsA("UIListLayout")
			if Layout then
				Layout.Padding = UDim.new(0, 4)
				Layout.SortOrder = Enum.SortOrder.LayoutOrder
			end
			for _, Child in Environment:GetChildren() do
				if Child:IsA("GuiButton") or Child:IsA("UIAspectRatioConstraint") then
					Child:Destroy()
				end
			end
			local Title = Environment:FindFirstChild("1 Title") :: TextLabel?
			if Title then
				Title.Text = "\u{2022} Environment"
				Title.Size = UDim2.new(1, 0, 0, 32)
			end
			Environment.Parent = Gameplay.Parent
		end

		local Setting = Template:Clone()
		Setting.Name = SettingName
		Setting.Size = UDim2.new(1, 0, 0, 42)
		Setting.LayoutOrder = if SettingName == "Birds" then 1 elseif SettingName == "ClothCut" then 2 else 3
		SetSettingLabel(Setting, if SettingName == "ClothCut" then "Cloth Cut" else SettingName)
		Setting.Parent = Environment
	end
end

function SettingsController:LoadSettings()
	for SettingName, SettingValue in SettingsService:GetSettings() do
		SettingsController:EnsureSettingButton(SettingName)

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
end

function SettingsController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Menu = PlayerGui:WaitForChild("Menu")
	SettingsUI = Menu:WaitForChild("Settings")

	SettingsController:LoadSettings()

	SettingsController:BindSettingsChange()
end

return SettingsController
