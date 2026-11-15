-- Run the inventory controller with cloned UI and isolated server snapshots.
return function(Controller: any, Main: ScreenGui, Context: any): string
	local Checks = 0
	local Content = Main.Inventory.BackpackPanel.ScrollWrapper.Scroll.GridCanvas.ItemsLayer
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local First = Content:FindFirstChild("Apple") :: ImageButton
	local Item = table.clone(Context.Entries[1])
	Item.Id, Item.Stack = "Apple:test-second", 8
	table.insert(Context.Entries, Item)
	Context.Layout.Positions[Item.Id] = { Column = 5, Row = 1, Width = 1, Height = 1, Rotated = false }
	Context.Layout.Revision += 1
	Context.EmitInventory()
	task.wait()
	local Second = Content:FindFirstChild(Item.Id) :: ImageButton
	Check(First and Second and First ~= Second, "Two stacks of the same item must render as separate buttons")
	Check(
		First:GetAttribute("Name") == Second:GetAttribute("Name") and Second:GetAttribute("Id") == Item.Id,
		"Buttons must retain definition names and independent stack identities"
	)
	Check(First.Quantity.Text == "3x" and Second.Quantity.Text == "8x", "Each stack must show its own quantity")
	Check(Controller:GetInventoryItem(Item.Id).Stack == 8, "Selection lookup must resolve the requested stack")
	local Viewport = Second:FindFirstChildWhichIsA("ViewportFrame", true)
	local Camera = Viewport and Viewport.CurrentCamera
	local Creates = Context.Creates
	Item.Stack = 7
	Context.EmitInventory()
	task.wait()
	Check(
		Content:FindFirstChild(Item.Id) == Second and Content:FindFirstChild("Apple") == First,
		"Quantity changes must preserve both buttons"
	)
	Check(Second.Quantity.Text == "7x" and First.Quantity.Text == "3x", "Quantity changes must affect only their stack")
	Check(
		Context.Creates == Creates and (not Viewport or Viewport.CurrentCamera == Camera),
		"Quantity updates must not rebuild stack models or cameras"
	)
	local Snapshot = table.clone(Context.Layout)
	Snapshot.Positions = table.clone(Context.Layout.Positions)
	Snapshot.Positions[Item.Id] = { Column = 5, Row = 4, Width = 1, Height = 1, Rotated = false }
	Snapshot.Revision += 1
	Check(Controller:ApplyLayout(Snapshot), "Independent stack movement must accept the updated snapshot")
	Check(
		Second:GetAttribute("Row") == 4 and First:GetAttribute("Row") == 1,
		"Moving one stack must not move the other"
	)
	table.remove(Context.Entries, #Context.Entries)
	Context.Layout = Snapshot
	Context.Layout.Positions[Item.Id] = nil
	Context.Layout.Revision += 1
	Context.EmitInventory()
	task.wait()
	Check(
		not Content:FindFirstChild(Item.Id) and Content:FindFirstChild("Apple") == First,
		"Removing a stack must preserve sibling buttons"
	)
	return tostring(Checks) .. " multiple-stack UI checks passed"
end
