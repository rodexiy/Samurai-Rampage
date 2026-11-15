-- Run with the production controller, cloned UI, and isolated inventory events.
return function(Controller: any, Main: ScreenGui, Context: any): string
	local Checks = 0
	local Content = Main.Inventory.BackpackPanel.ScrollWrapper.Scroll.GridCanvas.ItemsLayer
	local Scroll = Main.Inventory.BackpackPanel.ScrollWrapper.Scroll
	local Apple = Content.Apple
	local Wood = Content.WoodLog
	local Katana = Content.BasicKatana
	local Viewport = Apple.Visual.ViewportFrame
	local Model = Viewport:FindFirstChildWhichIsA("Model")
	local Camera = Viewport.CurrentCamera
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local function Settle()
		task.wait(0.05)
	end
	local function Emit()
		Context.EmitInventory()
	end

	Controller:Select(Apple, Context.Entries[1])
	local Display = Main.Inventory.ItemInfo.Display:FindFirstChildWhichIsA("ViewportFrame")
	local SelectedModel = Display:FindFirstChildWhichIsA("Model")
	local Creates, Models, Calls, Cancels, Binds =
		Context.Creates, Context.Models, Context.Calls, Context.Cancels, Context.Binds
	Scroll.CanvasPosition = Vector2.new(0, 40)
	local ScrollPosition = Scroll.CanvasPosition
	Context.Entries[1].Stack = 4
	Emit()
	Settle()
	Check(Apple.Quantity.Text == "4x", "Stack changes must update the existing quantity label")
	Check(Main.Inventory.ItemInfo.BasicStats.Amount.Text == "4x", "Selected details must update their quantity")
	Check(
		Controller:GetSelected() == Apple and Display:FindFirstChildWhichIsA("Model") == SelectedModel,
		"Quantity updates must preserve selection and its preview model"
	)
	Check(
		Context.Creates == Creates and Context.Models == Models,
		"Quantity updates must not recreate buttons or models"
	)
	Check(
		Context.Cancels == Cancels and Context.Binds == Binds,
		"Quantity updates must preserve drag bindings and active interactions"
	)
	Check(Scroll.CanvasPosition == ScrollPosition, "Updates must preserve the scroll position")
	Check(
		Content.Apple == Apple and Content.WoodLog == Wood and Content.BasicKatana == Katana,
		"Unchanged inventory entries must keep their instances"
	)
	Check(
		Viewport:FindFirstChildWhichIsA("Model") == Model and Viewport.CurrentCamera == Camera,
		"Unchanged previews must retain their model and camera"
	)

	local Reconciles = Context.Reconciles
	Emit()
	Emit()
	Emit()
	Settle()
	Check(Context.Reconciles == Reconciles + 1, "Updates arriving together must reconcile once")
	Check(
		Context.Creates == Creates and Context.Models == Models and Context.Calls == Calls,
		"Duplicate events must not rebuild or fetch inventory"
	)

	Context.Layout.Hotbar = { ["0"] = "Apple", ["1"] = "WoodLog" }
	Emit()
	Settle()
	Check(
		Apple.EquipIndex.Text == "[0]" and Wood.EquipIndex.Text == "[1]",
		"Hotbar assignments must update badges from the received snapshot"
	)
	Check(
		Context.Creates == Creates and Context.Models == Models,
		"Hotbar assignments must not rebuild inventory previews"
	)
	Context.Layout.Hotbar = { ["1"] = "Apple", ["0"] = "WoodLog" }
	Emit()
	Settle()
	Check(
		Apple.EquipIndex.Text == "[1]" and Wood.EquipIndex.Text == "[0]",
		"Reordering the hotbar must update only its affected badges"
	)

	Context.AddItem("Bandage", 2, 4, 1)
	Emit()
	Settle()
	Check(Content:FindFirstChild("Bandage") ~= nil, "A newly acquired item must appear")
	Check(
		Context.Creates == Creates + 1 and Context.Models == Models + 1,
		"Adding one item must create exactly one entry and model"
	)
	Check(Content.Apple == Apple and Content.BasicKatana == Katana, "Adding an item must preserve existing entries")
	Context.RemoveItem("WoodLog")
	Emit()
	Settle()
	Check(
		Content:FindFirstChild("WoodLog") == nil and Wood.Parent == nil,
		"Removing an item must destroy its own entry"
	)
	Check(Content.Apple == Apple and Content.BasicKatana == Katana, "Removing an item must preserve other entries")
	Check(Controller:GetSelected() == Apple, "Adding or removing unrelated items must preserve selection")

	Main.Enabled = false
	Context.Entries[1].Stack = 6
	Emit()
	Main.Enabled = true
	Settle()
	Check(
		Content.Apple == Apple and Apple.Quantity.Text == "6x",
		"Reopening must reuse existing entries and apply cached changes"
	)
	Check(Context.Calls == Calls, "Reopening must not refetch an up-to-date inventory")

	local Cells = Scroll.GridCanvas.CellsLayer
	local FirstCell = Cells.Cell_01_01
	Context.Layout.Rows = 10
	Context.Layout.Revision += 1
	Emit()
	Settle()
	Check(
		Cells.Cell_01_01 == FirstCell and Cells:FindFirstChild("Cell_10_06") ~= nil,
		"Increasing capacity must add cells while retaining existing ones"
	)
	Context.Layout.Rows = 8
	Context.Layout.Revision += 1
	Emit()
	Settle()
	Check(
		Cells.Cell_01_01 == FirstCell and Cells:FindFirstChild("Cell_10_06") == nil,
		"Reducing capacity must remove only excess cells"
	)

	Context.Delay = 0.05
	Controller:UpdateContent(true)
	task.delay(0.01, function()
		Context.Entries[1].Stack = 8
		Emit()
	end)
	task.wait(0.12)
	Context.Delay = nil
	Check(Apple.Quantity.Text == "8x", "An older in-flight fetch must not overwrite a newer event")
	Check(
		Context.Creates == Creates + 1 and Context.Models == Models + 1,
		"Refreshing cached data must still preserve matching instances"
	)

	return tostring(Checks) .. " incremental inventory checks passed"
end
