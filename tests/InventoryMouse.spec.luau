-- Run on the client after Knit starts. Hotbar assignment is stubbed to avoid changing player data.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

return function(Knit: any): string
	local Player = Players.LocalPlayer
	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	local Menus = PlayerGui:WaitForChild("Menu") :: ScreenGui
	local Main = (PlayerGui:FindFirstChild("MainMenu") or Menus:WaitForChild("MainMenu")) :: ScreenGui
	local Close = Main:WaitForChild("Close") :: ImageButton
	local Camera = Knit.GetController("CameraController")
	local Menu = Knit.GetController("MenuController")
	local Hotbar = Knit.GetController("HotbarController")
	local InventoryService = Knit.GetService("InventoryService")
	local OriginalAssign = InventoryService.EquipToHotbar
	local OriginalLocked = Player:GetAttribute("MouseLocked")
	local OriginalMode = Player.CameraMode
	local OriginalEnabled = Main.Enabled
	local Checks = 0
	local Assignments = 0

	local function Settle()
		for _ = 1, 4 do
			RunService.RenderStepped:Wait()
		end
	end

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function CheckMouse(Unlocked: boolean, Behavior: Enum.MouseBehavior)
		Settle()
		Check(Camera:IsMouseUnlocked() == Unlocked, "UI cursor ownership does not match the active interaction")
		Check(UserInputService.MouseBehavior == Behavior, "Unexpected mouse behavior: " .. tostring(UserInputService.MouseBehavior))
	end

	InventoryService.EquipToHotbar = function(_Self: any, ItemName: string, Index: number)
		Check(ItemName == "Pickaxe" and Index == 1, "Hotbar confirmation must still assign the selected item and slot")
		Assignments += 1
	end

	local Success, Result = pcall(function()
		Menu:CloseAllMenus()
		Player.CameraMode = Enum.CameraMode.Classic
		Player:SetAttribute("MouseLocked", true)
		CheckMouse(false, Enum.MouseBehavior.LockCenter)
		Check(not Close.Modal, "Closed inventory must not keep a modal button")

		for _ = 1, 3 do
			Menu:OpenMenu("MainMenu", true)
			CheckMouse(true, Enum.MouseBehavior.Default)
			Check(Close.Modal and UserInputService.MouseIconEnabled, "Open inventory must expose an interactive cursor")
			Check(Player:GetAttribute("MouseLocked") == true, "Inventory must preserve shift lock preference")
			Menu:CloseAllMenus()
			CheckMouse(false, Enum.MouseBehavior.LockCenter)
			Check(not Close.Modal, "Closing inventory must release modal ownership")
		end

		Menu:OpenMenu("MainMenu", true)
		Hotbar:BeginSlotSelection("Pickaxe")
		CheckMouse(true, Enum.MouseBehavior.Default)
		Check(not Main.Enabled and Hotbar:IsSelectingSlot(), "Hotbar selection must replace inventory")
		Hotbar:ConfirmSlotSelection(1)
		CheckMouse(false, Enum.MouseBehavior.LockCenter)
		Check(Assignments == 1 and not Hotbar:IsSelectingSlot(), "Confirming must end hotbar selection")

		Hotbar:BeginSlotSelection("Pickaxe")
		CheckMouse(true, Enum.MouseBehavior.Default)
		Hotbar:CancelSlotSelection()
		CheckMouse(false, Enum.MouseBehavior.LockCenter)

		Player:SetAttribute("MouseLocked", false)
		Menu:OpenMenu("MainMenu", true)
		CheckMouse(true, Enum.MouseBehavior.Default)
		Menu:CloseAllMenus()
		CheckMouse(false, Enum.MouseBehavior.Default)
		Hotbar:BeginSlotSelection("Pickaxe")
		CheckMouse(true, Enum.MouseBehavior.Default)
		Hotbar:CancelSlotSelection()
		CheckMouse(false, Enum.MouseBehavior.Default)

		Menu:OpenMenu("MainMenu", true)
		Player:SetAttribute("MouseLocked", true)
		CheckMouse(true, Enum.MouseBehavior.Default)
		Menu:CloseAllMenus()
		CheckMouse(false, Enum.MouseBehavior.LockCenter)
		Menu:OpenMenu("MainMenu", true)
		Player:SetAttribute("MouseLocked", false)
		CheckMouse(true, Enum.MouseBehavior.Default)
		Menu:CloseAllMenus()
		CheckMouse(false, Enum.MouseBehavior.Default)

		Camera:SetForcedShiftLock("InventoryCursorTest", true)
		CheckMouse(false, Enum.MouseBehavior.LockCenter)
		Menu:OpenMenu("MainMenu", true)
		CheckMouse(true, Enum.MouseBehavior.Default)
		Hotbar:BeginSlotSelection("Pickaxe")
		CheckMouse(true, Enum.MouseBehavior.Default)
		Hotbar:CancelSlotSelection()
		CheckMouse(false, Enum.MouseBehavior.LockCenter)
		Camera:SetForcedShiftLock("InventoryCursorTest", false)
		CheckMouse(false, Enum.MouseBehavior.Default)

		Player.CameraMode = Enum.CameraMode.LockFirstPerson
		CheckMouse(false, Enum.MouseBehavior.LockCenter)
		Menu:OpenMenu("MainMenu", true)
		CheckMouse(true, Enum.MouseBehavior.Default)
		Menu:CloseAllMenus()
		CheckMouse(false, Enum.MouseBehavior.LockCenter)
	end)

	InventoryService.EquipToHotbar = OriginalAssign
	Camera:SetForcedShiftLock("InventoryCursorTest", false)
	Menu:CloseAllMenus()
	Player.CameraMode = OriginalMode
	Player:SetAttribute("MouseLocked", OriginalLocked)
	Main.Enabled = OriginalEnabled
	Settle()

	assert(Success, tostring(Result))
	return tostring(Checks) .. " inventory cursor checks passed"
end
