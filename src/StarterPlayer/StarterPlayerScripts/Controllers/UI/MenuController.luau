local Knit = require(game.ReplicatedStorage.Packages.Knit)

local MenuController = Knit.CreateController({
	Name = "MenuController",
})

local Player = game.Players.LocalPlayer
local PlayerGui
local Menus
local Hud
local EnabledTable = {}

function MenuController:CloseAllMenus()
	for _, Menu in Menus:GetChildren() do
		if Menu:IsA("ScreenGui") then
			if Menu.Name == "Dialog" then
				continue
			end
			Menu.Enabled = false
		end
	end
end

function MenuController:OpenMenu(MenuName: string, force: boolean)
	local Character = Player.Character

	if Character and Character:GetAttribute("Died") then
		return
	end

	if Player.Character:GetAttribute("Meditating") and not force then
		return
	end
	if Menus.Dialog.Enabled and not force then
		return
	end

	local Menu = Menus:FindFirstChild(MenuName)
	if (not Menu or Menu.Enabled) and not force then
		self:CloseAllMenus()
		return
	end
	if not force then
		self:CloseAllMenus()
	end

	Menu.Enabled = true
end

function MenuController:SetHudDefaultEnabled()
	for MenuName, Enabled in pairs(EnabledTable) do
		Hud[MenuName].Enabled = Enabled or Hud[MenuName]:FindFirstChild("Enabler")
	end
end

function MenuController:DisableHud()
	for _, Menu in Hud:GetChildren() do
		Menu.Enabled = false
	end
end

function MenuController:DisableMenu()
	for _, Menu in Menus:GetChildren() do
		Menu.Enabled = false
	end
end

function MenuController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Menus = PlayerGui:WaitForChild("Menu")
	Hud = PlayerGui:WaitForChild("Hud")

	for _, Menu in Hud:GetChildren() do
		EnabledTable[Menu.Name] = Menu.Enabled or Menu:FindFirstChild("Enabler")
	end
end

return MenuController
