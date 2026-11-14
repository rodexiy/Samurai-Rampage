local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local MenuController = Knit.CreateController({
	Name = "MenuController",
})

local Player = Players.LocalPlayer
local PlayerGui: PlayerGui
local Menus: ScreenGui
local Hud: ScreenGui
local EnabledTable = {}
local HotbarController
local HudFocused = false
local FocusedHud: ScreenGui? = nil
local SavedHudStates: { [ScreenGui]: boolean } = {}
local HudConnections: { [ScreenGui]: RBXScriptConnection } = {}
local SavedPromptEnabled: boolean?
local PromptMenus: { [ScreenGui]: boolean } = setmetatable({}, {__mode = "k"})

local StandaloneHudNames = {
	Compass = true,
	StoryCompass = true,
	Actions = true,
	QuestTargetsGui = true,
}

local function IsStandaloneHud(Gui: Instance): boolean
	return Gui:IsA("ScreenGui") and (StandaloneHudNames[Gui.Name] == true or Gui.Name:sub(1, 6) == "Topbar")
end

local function FocusHudGui(Gui: ScreenGui)
	if not HudFocused then
		return
	end

	if SavedHudStates[Gui] == nil then
		SavedHudStates[Gui] = Gui.Enabled
		HudConnections[Gui] = Gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if HudFocused and Gui ~= FocusedHud and Gui.Enabled then
				Gui.Enabled = false
			end
		end)
	end

	Gui.Enabled = Gui == FocusedHud
end

function MenuController:SetHudFocus(Active: boolean, VisibleHud: ScreenGui?)
	HudFocused = Active
	FocusedHud = VisibleHud

	if not Active then
		for Gui, Connection in HudConnections do
			Connection:Disconnect()
			if Gui.Parent then
				Gui.Enabled = SavedHudStates[Gui]
			end
		end

		table.clear(HudConnections)
		table.clear(SavedHudStates)
		return
	end

	if not Hud or not PlayerGui then
		return
	end

	for _, Gui in Hud:QueryDescendants("ScreenGui") do
		FocusHudGui(Gui)
	end

	for _, Gui in PlayerGui:GetChildren() do
		if IsStandaloneHud(Gui) then
			FocusHudGui(Gui :: ScreenGui)
		end
	end
end

function MenuController:GetMenu(MenuName: string): ScreenGui?
	if not Menus then
		return nil
	end

	if MenuName == "Inventory" then
		MenuName = "MainMenu"
	end

	if MenuName == "MainMenu" then
		return (PlayerGui:FindFirstChild("MainMenu") or Menus:FindFirstChild(MenuName)) :: ScreenGui?
	end

	return Menus:FindFirstChild(MenuName) :: ScreenGui?
end

local function UpdatePromptAvailability()
	local MainMenu = MenuController:GetMenu("MainMenu")
	local MenuOpen = MainMenu ~= nil and MainMenu.Enabled
	for _, Menu in Menus:GetChildren() do
		if Menu:IsA("ScreenGui") and Menu.Enabled then
			MenuOpen = true
			break
		end
	end

	if MenuOpen then
		if SavedPromptEnabled == nil then
			SavedPromptEnabled = ProximityPromptService.Enabled
		end

		ProximityPromptService.Enabled = false
	elseif SavedPromptEnabled ~= nil then
		ProximityPromptService.Enabled = SavedPromptEnabled
		SavedPromptEnabled = nil
	end
end

local function BindPromptMenu(Menu: Instance)
	if not Menu:IsA("ScreenGui") or PromptMenus[Menu] then
		return
	end

	PromptMenus[Menu] = true
	Menu:GetPropertyChangedSignal("Enabled"):Connect(UpdatePromptAvailability)
	UpdatePromptAvailability()
end

function MenuController:CloseAllMenus()
	HotbarController:CancelSlotSelection()

	for _, Menu in Menus:GetChildren() do
		if Menu:IsA("ScreenGui") then
			if Menu.Name == "Dialog" then
				continue
			end
			Menu.Enabled = false
		end
	end

	local MainMenu = self:GetMenu("MainMenu")
	if MainMenu then
		MainMenu.Enabled = false
	end
end

function MenuController:OpenMenu(MenuName: string, Force: boolean?)
	local Character = Player.Character
	if not Character or Character:GetAttribute("Died") then
		return
	end

	if Character:GetAttribute("Meditating") and not Force then
		return
	end

	local Dialog = Menus:FindFirstChild("Dialog") :: ScreenGui?
	if Dialog and Dialog.Enabled and not Force then
		return
	end

	local Menu = self:GetMenu(MenuName)
	if not Menu then
		return
	end

	HotbarController:CancelSlotSelection()

	if Menu.Enabled and not Force then
		self:CloseAllMenus()
		return
	end

	if not Force then
		self:CloseAllMenus()
	end

	Menu.Enabled = true
end

function MenuController:SetHudDefaultEnabled()
	for MenuName, Enabled in pairs(EnabledTable) do
		local Gui = Hud:FindFirstChild(MenuName) :: ScreenGui?
		if Gui then
			Gui.Enabled = Enabled or Gui:FindFirstChild("Enabler") ~= nil
		end
	end
end

function MenuController:DisableHud()
	for _, Menu in Hud:GetChildren() do
		Menu.Enabled = false
	end
end

function MenuController:DisableMenu()
	HotbarController:CancelSlotSelection()

	for _, Menu in Menus:GetChildren() do
		Menu.Enabled = false
	end

	local MainMenu = self:GetMenu("MainMenu")
	if MainMenu then
		MainMenu.Enabled = false
	end
end

function MenuController.KnitInit()
	HotbarController = Knit.GetController("HotbarController")
end

function MenuController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	Menus = PlayerGui:WaitForChild("Menu") :: ScreenGui
	Hud = PlayerGui:WaitForChild("Hud") :: ScreenGui

	for _, Menu in Menus:GetChildren() do
		BindPromptMenu(Menu)
	end
	local MainMenu = MenuController:GetMenu("MainMenu")
	if MainMenu then
		BindPromptMenu(MainMenu)
	end
	Menus.ChildAdded:Connect(BindPromptMenu)
	Menus.ChildRemoved:Connect(UpdatePromptAvailability)
	UpdatePromptAvailability()

	local Shortcut = (Hud:FindFirstChild("MainMenuShortcut") or Hud:WaitForChild("Level")) :: ScreenGui
	Shortcut.Name = "MainMenuShortcut"
	local ShortcutContent = Shortcut:WaitForChild("content") :: ImageLabel
	for _, Child in ShortcutContent:GetChildren() do
		if Child:IsA("GuiObject") and Child.Name ~= "OpenInventory" then
			Child:Destroy()
		end
	end
	ShortcutContent.ImageTransparency = 1
	ShortcutContent.BackgroundTransparency = 1

	local OpenInventory = ShortcutContent:WaitForChild("OpenInventory") :: TextButton
	OpenInventory.Activated:Connect(function()
		MenuController:OpenMenu("MainMenu")
	end)

	for _, Menu in Hud:GetChildren() do
		if Menu:IsA("ScreenGui") then
			EnabledTable[Menu.Name] = Menu.Enabled or Menu:FindFirstChild("Enabler") ~= nil
		end
	end

	Hud.DescendantAdded:Connect(function(Child: Instance)
		if Child:IsA("ScreenGui") then
			FocusHudGui(Child)
		end
	end)
	PlayerGui.ChildAdded:Connect(function(Child: Instance)
		if IsStandaloneHud(Child) then
			FocusHudGui(Child :: ScreenGui)
		elseif Child.Name == "MainMenu" then
			BindPromptMenu(Child)
		end
	end)
end

return MenuController
