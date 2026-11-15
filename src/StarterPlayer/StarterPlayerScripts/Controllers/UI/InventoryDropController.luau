local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryDropping = require(ReplicatedStorage.Shared.Utils.InventoryDropping)
local InventoryDropController = Knit.CreateController({ Name = "InventoryDropController" })
local InventoryController
local InventoryDragController
local InventoryModalController
local Confirmation: Frame
local Description: TextLabel
local TypeAmount: TextBox
local AmountBar: Frame
local Slider: Frame
local AmountSelected: TextLabel
local Start: TextLabel
local Half: TextLabel
local All: TextLabel
local HalfDisplay: Frame
local Pending: { Name: string, Stack: number }?
local Selected = 1
local UpdatingText = false
local SliderInput: InputObject?

function InventoryDropController:IsOpen(): boolean
	return Pending ~= nil
end

function InventoryDropController:CanDrop(Name: string): boolean
	return InventoryDropping.CanDrop(InventoryController:GetInventoryItem(Name))
end

function InventoryDropController:SetAmount(Amount: number)
	if not Pending then
		return
	end
	Selected = InventoryDropping.ClampAmount(Amount, Pending.Stack)
	UpdatingText = true
	TypeAmount.Text = tostring(Selected)
	UpdatingText = false
	AmountSelected.Text = tostring(Selected)
	local Fraction = if Pending.Stack > 1 then (Selected - 1) / (Pending.Stack - 1) else 0
	Slider.Position = UDim2.new(Fraction, 0, Slider.Position.Y.Scale, Slider.Position.Y.Offset)
end

function InventoryDropController:SetPointer(Position: Vector2)
	if not Pending or Pending.Stack == 1 or AmountBar.AbsoluteSize.X <= 0 then
		return
	end
	local Main = Confirmation:FindFirstAncestorWhichIsA("ScreenGui")
	local Inset = if Main and not Main.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero
	local Fraction = math.clamp((Position.X - Inset.X - AmountBar.AbsolutePosition.X) / AmountBar.AbsoluteSize.X, 0, 1)
	self:SetAmount(math.round(1 + Fraction * (Pending.Stack - 1)))
end

function InventoryDropController:BindButtons()
	local Buttons = Confirmation:WaitForChild("Buttons") :: Frame
	for _, Name in { "Drop", "Cancel" } do
		local Button = Buttons:WaitForChild(Name) :: ImageButton
		Button.Active = true
		Button.Interactable = true
		Button:SetAttribute("callback", nil)
		Button.Activated:Connect(function()
			if Name == "Drop" then
				self:Confirm()
			else
				self:Cancel()
			end
		end)
	end
end

function InventoryDropController:BindSlider()
	for _, Control in { AmountBar, Slider, AmountSelected } do
		Control.InputBegan:Connect(function(Input: InputObject)
			if not Pending or Pending.Stack == 1 then
				return
			end
			if
				Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				SliderInput = Input
				self:SetPointer(Vector2.new(Input.Position.X, Input.Position.Y))
			end
		end)
	end
end

function InventoryDropController:BindPresets()
	for _, Label in { Start, Half, All } do
		Label.InputBegan:Connect(function(Input: InputObject)
			if not Pending or Pending.Stack == 1 then
				return
			end
			if
				Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				self:SetAmount(
					if Label == Start then 1 elseif Label == All then Pending.Stack else math.floor(Pending.Stack / 2)
				)
			end
		end)
	end
end

function InventoryDropController:BindTextBox()
	TypeAmount.ClearTextOnFocus = false
	TypeAmount:GetPropertyChangedSignal("Text"):Connect(function()
		if UpdatingText or not Pending then
			return
		end
		-- An empty value must remain editable while replacing the previous quantity.
		local Amount = tonumber(TypeAmount.Text)
		if Amount then
			self:SetAmount(Amount)
		elseif TypeAmount.Text ~= "" then
			self:SetAmount(Selected)
		end
	end)
	TypeAmount.FocusLost:Connect(function()
		self:SetAmount(tonumber(TypeAmount.Text) or Selected)
	end)
end

function InventoryDropController:Configure(Panel: Frame)
	Confirmation = Panel:WaitForChild("DropAmount") :: Frame
	Description = Confirmation:WaitForChild("Description") :: TextLabel
	TypeAmount = Confirmation:WaitForChild("TypeAmount") :: TextBox
	AmountBar = Confirmation:WaitForChild("AmountBar") :: Frame
	Slider = AmountBar:WaitForChild("Slider") :: Frame
	AmountSelected = Slider:WaitForChild("AmountSelected") :: TextLabel
	Start = AmountBar:WaitForChild("Start") :: TextLabel
	Half = AmountBar:WaitForChild("Half") :: TextLabel
	All = AmountBar:WaitForChild("All") :: TextLabel
	HalfDisplay = AmountBar:WaitForChild("HalfDisplay") :: Frame
	Confirmation.Visible = false

	self:BindButtons()
	self:BindSlider()
	self:BindPresets()
	self:BindTextBox()
end

function InventoryDropController:Begin(Name: string)
	if not Confirmation or not InventoryController:IsOpen() then
		return
	end
	local Item = InventoryController:GetInventoryItem(Name)
	if not InventoryDropping.CanDrop(Item) then
		return
	end

	self:Cancel()
	InventoryDragController:Cancel()
	InventoryController:Unselect()
	Pending = { Name = Name, Stack = Item.Stack }
	Description.Text = "SELECT THE AMOUNT OF " .. (Item.DisplayName or Item.Name) .. " YOU WANT TO DROP"
	Start.Text = "1"
	All.Text = tostring(Item.Stack)
	Half.Text = tostring(math.max(1, math.floor(Item.Stack / 2)))
	Half.Visible = Item.Stack > 2
	HalfDisplay.Visible = Item.Stack > 2
	TypeAmount.TextEditable = Item.Stack > 1
	TypeAmount.Active = Item.Stack > 1
	for _, Control in { AmountBar, Slider, AmountSelected, Start, Half, All } do
		Control.Active = Item.Stack > 1
	end
	self:SetAmount(1)
	InventoryModalController:Open(Confirmation, function()
		self:Cancel()
	end)
end

function InventoryDropController:Cancel()
	Pending, SliderInput = nil, nil
	if Confirmation then
		TypeAmount:ReleaseFocus()
		InventoryModalController:Close(Confirmation)
	end
end

function InventoryDropController:ValidatePending(): boolean
	if not Pending then
		return false
	end
	local Item = InventoryController:GetInventoryItem(Pending.Name)
	if not InventoryController:IsOpen() or not InventoryDropping.CanDrop(Item) or Item.Stack ~= Pending.Stack then
		self:Cancel()
		return false
	end

	return true
end

function InventoryDropController:Confirm()
	if not self:ValidatePending() or not Pending then
		return
	end
	self:SetAmount(tonumber(TypeAmount.Text) or Selected)
	local Revision = InventoryController:GetInventoryRevision()
	local Request =
		{ Kind = "Drop", Name = Pending.Name, Stack = Pending.Stack, Amount = Selected, Revision = Revision }
	self:Cancel()
	if Revision ~= nil then
		InventoryDragController:SubmitAction(Request)
	end
end

function InventoryDropController.KnitInit()
	InventoryController = Knit.GetController("InventoryController")
	InventoryDragController = Knit.GetController("InventoryDragController")
	InventoryModalController = Knit.GetController("InventoryModalController")
end

function InventoryDropController.KnitStart()
	UserInputService.InputChanged:Connect(function(Input: InputObject)
		if SliderInput and (Input == SliderInput or Input.UserInputType == Enum.UserInputType.MouseMovement) then
			InventoryDropController:SetPointer(Vector2.new(Input.Position.X, Input.Position.Y))
		end
	end)
	UserInputService.InputEnded:Connect(function(Input: InputObject)
		if Input == SliderInput then
			SliderInput = nil
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		SliderInput = nil
	end)
end

return InventoryDropController
