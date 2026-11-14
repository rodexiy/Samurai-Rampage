-- Run with production UI controllers and a temporary inventory backend in Studio.
local RunService = game:GetService("RunService")

return function(Controller: any, Main: ScreenGui, Context: any): string
	local Checks = 0
	local Canvas = Main.Inventory.BackpackPanel.ScrollWrapper.Scroll.GridCanvas
	local Content = Canvas.ItemsLayer
	local Scroll = Main.Inventory.BackpackPanel.ScrollWrapper.Scroll
	local References = {}
	local Changes = 0
	local Connections = {}

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Settle()
		for _ = 1, 3 do
			RunService.RenderStepped:Wait()
		end
	end

	for _, Button in Content:GetChildren() do
		local Viewport = Button.Visual.ViewportFrame
		References[Button.Name] = {Button = Button, Viewport = Viewport, Model = Viewport:FindFirstChildWhichIsA("Model"), Camera = Viewport.CurrentCamera}
		table.insert(Connections, Viewport.ChildAdded:Connect(function()
			Changes += 1
		end))
		table.insert(Connections, Viewport.ChildRemoved:Connect(function()
			Changes += 1
		end))
	end
	table.insert(Connections, Content.ChildAdded:Connect(function()
		Changes += 1
	end))
	table.insert(Connections, Content.ChildRemoved:Connect(function()
		Changes += 1
	end))

	local function CheckReferences()
		for Name, Original in References do
			local Button = Content:FindFirstChild(Name)
			local Placement = Context.Layout.Positions[Name]
			Check(Button == Original.Button, "Layout updates must reuse the button for " .. Name)
			Check((Button:GetAttribute("Style") or ""):find("-Button", 1, true) ~= nil, "Grid feedback must opt out of the generic geometry-changing button style")
			Check(Button.Size == UDim2.fromScale(Placement.Width / Context.Layout.Columns, Placement.Height / Context.Layout.Rows), "Item size must keep its current footprint for " .. Name)
			Check(Button.Visual.ViewportFrame == Original.Viewport, "Layout updates must reuse the viewport for " .. Name)
			Check(Original.Viewport:FindFirstChildWhichIsA("Model") == Original.Model, "Layout updates must reuse the model for " .. Name)
			Check(Original.Viewport.CurrentCamera == Original.Camera, "Layout updates must reuse the camera for " .. Name)
		end
		Check(Changes == 0, "Moving items must not create or destroy inventory entries or viewport children")
	end

	local Calls = Context.GetInventoryCalls
	Controller:Select(Content.SamuraiHelmet, Context.Items.SamuraiHelmet)
	Scroll.CanvasPosition = Vector2.new(0, 50)
	Settle()
	local ScrollPosition = Scroll.CanvasPosition
	local Selected = Controller:GetSelected()
	local Snapshot = Context.CopyLayout()
	Snapshot.Revision += 1
	Snapshot.Positions.BasicKatana = {Column = 1, Row = 8, Width = 6, Height = 1, Rotated = false}
	Context.EmitLayout(Snapshot)
	Settle()
	Check(Content.BasicKatana:GetAttribute("Row") == 8, "Layout event must move the existing item")
	Check(Controller:GetSelected() == Selected and Main.Inventory.ItemInfo.Visible, "Moving an item must preserve selection and details")
	Check(Scroll.CanvasPosition == ScrollPosition, "Moving an item must preserve scroll position")
	CheckReferences()

	Snapshot = Context.CopyLayout()
	Snapshot.Revision += 1
	Snapshot.Positions.BasicKatana = {Column = 8, Row = 4, Width = 1, Height = 6, Rotated = true}
	Context.EmitLayout(Snapshot)
	Settle()
	Check(Content.BasicKatana:GetAttribute("Rotated") and Content.BasicKatana:GetAttribute("Height") == 6, "Rotation must update the same entry")
	CheckReferences()

	local Old = Context.CopyLayout()
	Old.Revision -= 1
	Old.Positions.BasicKatana = {Column = 1, Row = 1, Width = 6, Height = 1, Rotated = false}
	Check(Controller:ApplyLayout(Old), "Stale layout must be handled without a full reload")
	Check(Content.BasicKatana:GetAttribute("Rotated"), "Stale result must not roll back a newer layout")

	Snapshot = Context.CopyLayout()
	Snapshot.Revision += 1
	Snapshot.Rows = 6
	Snapshot.Positions.BasicKatana = {Column = 1, Row = 6, Width = 6, Height = 1, Rotated = false}
	Context.EmitLayout(Snapshot)
	Settle()
	Check(Content.BasicKatana:GetAttribute("Row") == 6 and not Content.BasicKatana:GetAttribute("Rotated"), "Resizing must update placements and reverse rotation")
	CheckReferences()
	Check(Context.GetInventoryCalls == Calls, "Layout updates must not fetch or reload the inventory")

	for _, Connection in Connections do
		Connection:Disconnect()
	end
	Controller:Unselect()
	return tostring(Checks) .. " incremental inventory UI checks passed"
end
