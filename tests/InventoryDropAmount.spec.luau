-- Run against production controllers and a clone of the designer's UI.
return function(Drop: any, Delete: any, Main: ScreenGui, Context: any): string
	local Checks = 0
	local Frame = Main.Inventory.DropAmount
	local Bar = Frame.AmountBar
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local function Open(Stack: number)
		Context.Items.Apple = { Name = "Apple", DisplayName = "Apple", Stack = Stack }
		Main.Enabled = true
		Drop:Begin("Apple")
	end

	Open(9)
	Check(Drop:IsOpen() and Frame.Visible and Main.Bg.Visible, "Drop must open with the background visible")
	Check(not Main.Inventory.BackpackPanel.Visible and Context.ModalHidden, "Drop must hide background content")
	Check(Frame.Buttons.Drop.Active and Frame.Buttons.Drop.Interactable, "Drop must receive button activation")
	Check(Frame.Description.Text:find("Apple", 1, true) ~= nil, "Description must identify the item")
	Check(Bar.Start.Text == "1" and Bar.Half.Text == "4" and Bar.All.Text == "9", "Markers must reflect the stack")
	Check(Bar.Half.Visible and Bar.HalfDisplay.Visible, "Half markers must be available for larger stacks")
	Check(Frame.TypeAmount.Text == "1" and Bar.Slider.AmountSelected.Text == "1", "Selection starts at one")
	Drop:SetAmount(5)
	Check(
		Frame.TypeAmount.Text == "5" and Bar.Slider.AmountSelected.Text == "5",
		"Slider selection must update both values"
	)
	Check(Bar.Slider.Position.X.Scale == 0.5, "Slider midpoint must represent the middle selectable quantity")
	Frame.TypeAmount.Text = "9"
	task.wait()
	Check(Bar.Slider.AmountSelected.Text == "9" and Bar.Slider.Position.X.Scale == 1, "Typing must update the slider")
	Frame.TypeAmount.Text = "999"
	task.wait()
	Check(Frame.TypeAmount.Text == "9", "Typing above the owned stack must clamp")
	Frame.TypeAmount.Text = "0"
	task.wait()
	Check(Frame.TypeAmount.Text == "1", "Typing below one must clamp")
	Frame.TypeAmount.Text = "3.7"
	task.wait()
	Check(Frame.TypeAmount.Text == "3", "Fractional input must select whole items")
	Frame.TypeAmount.Text = "invalid"
	task.wait()
	Check(Frame.TypeAmount.Text == "3", "Invalid input must preserve the last valid quantity")
	Drop:Cancel()
	Check(not Drop:IsOpen() and #Context.Sent == 0, "Cancel must leave inventory untouched")
	Check(Main.Inventory.BackpackPanel.Visible and not Context.ModalHidden, "Cancel must restore background content")

	Open(1)
	Check(
		not Frame.TypeAmount.TextEditable and not Bar.Active and not Bar.Slider.Active,
		"Single items disable selectors"
	)
	Drop:SetAmount(99)
	Check(Frame.TypeAmount.Text == "1" and Bar.Slider.AmountSelected.Text == "1", "Single-item quantity stays at one")
	Drop:Cancel()
	Open(2)
	Check(not Bar.Half.Visible and not Bar.HalfDisplay.Visible, "Two-item stacks must hide both half markers")
	Check(
		Frame.TypeAmount.TextEditable and Bar.Slider.Active and Bar.All.Text == "2",
		"Two-item stacks permit quantity selection"
	)
	Drop:Cancel()
	Open(10)
	Check(Bar.Half.Text == "5" and Bar.Half.Visible and Bar.HalfDisplay.Visible, "Reopening must restore half markers")
	Drop:SetAmount(4)
	Drop:Confirm()
	Check(#Context.Sent == 1 and Context.Sent[1].Kind == "Drop", "Confirmation must send exactly one drop")
	Check(
		Context.Sent[1].Amount == 4 and Context.Sent[1].Stack == 10 and Context.Sent[1].Revision == 7,
		"Request must capture selected amount, stack and revision"
	)
	Drop:Confirm()
	Check(#Context.Sent == 1 and not Drop:IsOpen(), "Double confirmation must not drop twice")

	Open(3)
	Context.Key(Enum.KeyCode.Tab)
	Check(not Drop:IsOpen(), "Tab must cancel the drop")
	Open(3)
	Context.ChangeTab("Skills")
	Check(not Drop:IsOpen(), "Changing tabs must cancel the drop")
	Open(3)
	Main.Enabled = false
	task.wait()
	Check(not Drop:IsOpen(), "Closing the inventory must cancel the drop")
	Open(3)
	Context.Items.Apple.Stack = 4
	Check(not Drop:ValidatePending() and not Drop:IsOpen(), "External quantity changes must invalidate confirmation")
	Open(3)
	Delete:Begin("Apple")
	Check(
		not Drop:IsOpen() and Delete:IsOpen() and Main.Inventory.DeleteConfirmation.Visible,
		"Opening delete must cancel drop"
	)
	Drop:Begin("Apple")
	Check(
		Drop:IsOpen() and not Delete:IsOpen() and not Main.Inventory.DeleteConfirmation.Visible,
		"Opening drop must cancel delete"
	)
	Drop:Cancel()
	Context.Items.Apple = nil
	Drop:Begin("Apple")
	Check(not Drop:IsOpen() and #Context.Sent == 1, "Unowned items must not open confirmation")
	return tostring(Checks) .. " drop amount UI checks passed"
end
