-- Run the production deletion controller with cloned UI and isolated inputs/networking.
return function(Delete: any, Main: ScreenGui, Context: any): string
	local Checks = 0
	local Confirmation = Main.Inventory.DeleteConfirmation
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local function Open()
		Main.Enabled = true
		Delete:Begin("Apple")
		Check(Delete:IsOpen() and Confirmation.Visible, "A valid dropped item must open the confirmation")
	end
	Check(Confirmation.Buttons.Delete.Active and Confirmation.Buttons.Delete.Interactable, "Delete must receive activation even if its template is inactive")
	Check(Confirmation.Buttons.Cancel.Active and Confirmation.Buttons.Cancel.Interactable, "Cancel must receive activation even if its template is inactive")
	Open()
	Check(
		Confirmation.Description.Text == "ARE YOU SURE YOU WANT TO DELETE Apple?",
		"Confirmation must display the item's name"
	)
	for _, Panel in Main.Inventory:GetChildren() do
		if Panel:IsA("GuiObject") and Panel ~= Confirmation then
			Check(not Panel.Visible, "Inventory panels behind confirmation must be hidden")
		end
	end
	Check(Main.Bg.Visible, "The menu background must remain visible during confirmation")
	Check(not Main.DragLayer.Visible, "Other content frames must be hidden")
	Check(Main.Tabs.Visible and Main.Close.Visible, "Tabs and close must remain usable for cancellation")
	Check(Context.ModalHidden, "The hotbar must stay hidden while confirmation is open")
	Delete:Cancel()
	Check(
		not Delete:IsOpen() and not Confirmation.Visible and #Context.Sent == 0,
		"Cancel must close confirmation without a network request"
	)
	Check(
		Main.Inventory.BackpackPanel.Visible and Main.Inventory.Equipments.Visible and Main.Bg.Visible,
		"Cancel must restore the hidden panels"
	)
	Check(
		not Main.Inventory.ItemInfo.Visible and not Main.Stats.Visible,
		"Cancel must preserve panels that were already hidden"
	)
	Open()
	Delete:Confirm()
	Check(
		#Context.Sent == 1 and Context.Sent[1].Kind == "Delete" and Context.Sent[1].Name == "Apple",
		"Only Delete confirmation may send the deletion request"
	)
	Check(
		Context.Sent[1].Stack == 3 and Context.Sent[1].Revision == 7,
		"Confirmation must send the captured quantity and current layout revision"
	)
	Check(not Delete:IsOpen() and not Confirmation.Visible, "Confirm must close the frame")
	Delete:Confirm()
	Check(#Context.Sent == 1, "Double confirmation must not send a second deletion")
	Open()
	Context.Key(Enum.KeyCode.Tab)
	Check(not Delete:IsOpen() and #Context.Sent == 1, "Tab must cancel without deleting")
	Open()
	Main.Enabled = false
	task.wait()
	Check(
		not Delete:IsOpen() and not Confirmation.Visible and #Context.Sent == 1,
		"Closing the inventory must cancel without deleting"
	)
	Open()
	Context.ChangeTab("Skills")
	Check(not Delete:IsOpen() and #Context.Sent == 1, "Changing tabs must cancel without deleting")
	Open()
	Context.Items.Apple.Stack = 4
	Check(not Delete:ValidatePending() and not Delete:IsOpen(), "Quantity changes must cancel a stale confirmation")
	Check(#Context.Sent == 1, "Stale confirmation must not delete newly acquired items")
	Context.Items.Apple.Stack = 3
	Open()
	Context.Items.Apple = nil
	Check(
		not Delete:ValidatePending() and not Delete:IsOpen(),
		"Removing an item externally must cancel its confirmation"
	)
	Delete:Begin("Missing")
	Check(not Delete:IsOpen() and #Context.Sent == 1, "Unowned items must not open a deletion dialog")
	return tostring(Checks) .. " delete confirmation UI checks passed"
end
