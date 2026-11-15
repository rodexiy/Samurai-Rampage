local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryDeletion = require(ReplicatedStorage.Shared.Utils.InventoryDeletion)

type ItemData = { [string]: any }
type PendingDeletion = { Name: string, Stack: number }

local InventoryDeleteController = Knit.CreateController({ Name = "InventoryDeleteController" })
local InventoryController
local InventoryDragController
local InventoryModalController
local Main: ScreenGui?
local Inventory: Frame?
local Confirmation: Frame?
local Description: TextLabel?
local Pending: PendingDeletion?

function InventoryDeleteController:IsOpen(): boolean
	return Pending ~= nil
end

function InventoryDeleteController:CanDelete(Name: string): boolean
	return InventoryDeletion.CanDelete(InventoryController:GetInventoryItem(Name))
end

function InventoryDeleteController:Configure(Gui: ScreenGui, Panel: Frame)
	Main, Inventory = Gui, Panel
	Confirmation = Panel:WaitForChild("DeleteConfirmation") :: Frame
	Description = Confirmation:WaitForChild("Description") :: TextLabel
	Confirmation.Visible = false
	local Buttons = Confirmation:WaitForChild("Buttons") :: Frame
	local Delete = Buttons:WaitForChild("Delete") :: ImageButton
	local Cancel = Buttons:WaitForChild("Cancel") :: ImageButton
	Delete.Active = true
	Delete.Interactable = true
	Cancel.Active = true
	Cancel.Interactable = true
	Delete:SetAttribute("callback", nil)
	Cancel:SetAttribute("callback", nil)
	Delete.Activated:Connect(function()
		self:Confirm()
	end)
	Cancel.Activated:Connect(function()
		self:Cancel()
	end)
end

function InventoryDeleteController:Begin(Name: string)
	if not Main or not Inventory or not Confirmation or not Description or not InventoryController:IsOpen() then
		return
	end
	local Item = InventoryController:GetInventoryItem(Name)
	if not Item or not InventoryDeletion.CanDelete(Item) then
		return
	end

	self:Cancel()
	InventoryDragController:Cancel()
	InventoryController:Unselect()
	Pending = { Name = Name, Stack = Item.Stack }
	Description.Text = "ARE YOU SURE YOU WANT TO DELETE " .. (Item.DisplayName or Item.Name) .. "?"
	InventoryModalController:Open(Confirmation, function()
		self:Cancel()
	end)
end

function InventoryDeleteController:Cancel()
	Pending = nil
	if Confirmation then
		InventoryModalController:Close(Confirmation)
	end
end

function InventoryDeleteController:ValidatePending(): boolean
	if not Pending then
		return false
	end
	local Item = InventoryController:GetInventoryItem(Pending.Name)
	if
		not Item
		or not InventoryController:IsOpen()
		or not InventoryDeletion.CanDelete(Item)
		or Item.Stack ~= Pending.Stack
	then
		self:Cancel()
		return false
	end

	return true
end

function InventoryDeleteController:Confirm()
	if not self:ValidatePending() or not Pending then
		return
	end
	local Revision = InventoryController:GetInventoryRevision()
	local Request: ItemData = { Kind = "Delete", Name = Pending.Name, Stack = Pending.Stack, Revision = Revision }
	self:Cancel()
	if Revision ~= nil then
		InventoryDragController:SubmitAction(Request)
	end
end

function InventoryDeleteController.KnitInit()
	InventoryController = Knit.GetController("InventoryController")
	InventoryDragController = Knit.GetController("InventoryDragController")
	InventoryModalController = Knit.GetController("InventoryModalController")
end

return InventoryDeleteController
