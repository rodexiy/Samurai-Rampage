local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryModalController = Knit.CreateController({ Name = "InventoryModalController" })
local InventoryController
local HotbarController
local Main: ScreenGui
local Inventory: Frame
local Current: Frame?
local OnCancel: (() -> ())?
local HiddenPanels: { [GuiObject]: boolean } = {}

function InventoryModalController:Configure(Gui: ScreenGui, Panel: Frame)
	Main, Inventory = Gui, Panel
end

function InventoryModalController:IsOpen(): boolean
	return Current ~= nil
end

function InventoryModalController:Cancel()
	if OnCancel then
		OnCancel()
	end
end

function InventoryModalController:Open(Panel: Frame, Cancel: () -> ())
	self:Cancel()
	Current, OnCancel = Panel, Cancel

	local function Hide(Child: GuiObject)
		HiddenPanels[Child] = Child.Visible
		Child.Visible = false
	end
	for _, Child in Inventory:GetChildren() do
		if Child:IsA("GuiObject") and Child ~= Panel then
			Hide(Child)
		end
	end
	for _, Child in Main:GetChildren() do
		if Child:IsA("Frame") and Child ~= Inventory and Child.Name ~= "Bg" then
			Hide(Child)
		end
	end
	HotbarController:SetInventoryModalHidden(true)
	Panel.Visible = true
end

function InventoryModalController:Close(Panel: Frame)
	Panel.Visible = false
	if Current ~= Panel then
		return
	end
	Current, OnCancel = nil, nil

	for Child, Visible in HiddenPanels do
		if Child.Parent then
			Child.Visible = Visible
		end
	end
	table.clear(HiddenPanels)
	HotbarController:SetInventoryModalHidden(false)
	InventoryController:UpdateContent()
end

function InventoryModalController.KnitInit()
	InventoryController = Knit.GetController("InventoryController")
	HotbarController = Knit.GetController("HotbarController")
end

function InventoryModalController.KnitStart()
	UserInputService.InputBegan:Connect(function(Input: InputObject)
		if Input.KeyCode == Enum.KeyCode.Tab or Input.KeyCode == Enum.KeyCode.Escape then
			InventoryModalController:Cancel()
		end
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		InventoryModalController:Cancel()
	end)
end

return InventoryModalController
