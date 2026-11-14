-- Run on the client with the production grid methods, a cloned panel, and isolated layout snapshots.
local RunService = game:GetService("RunService")

return function(Controller: any, Panel: Frame, SetLayout: (any) -> ()): string
	local Checks = 0
	local Scroll = Panel.ScrollWrapper.Scroll :: ScrollingFrame
	local Canvas = Scroll.GridCanvas :: Frame
	local Cells = Canvas.CellsLayer :: Frame
	local Layout = Cells:FindFirstChildWhichIsA("UIGridLayout") :: UIGridLayout

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Settle()
		for _ = 1, 3 do
			RunService.RenderStepped:Wait()
		end
	end

	local function CheckGeometry(Rows: number, DisplayRows: number)
		local CellWidth = Scroll.AbsoluteWindowSize.X / 6
		Check(math.abs(Canvas.AbsoluteSize.X - Scroll.AbsoluteWindowSize.X) < 1, "The grid must fill the scrolling window width")
		Check(math.abs(Canvas.AbsoluteSize.Y - CellWidth * DisplayRows) < 1, "Extra rows must increase content height instead of shrinking cells")
		Check(math.abs(Layout.AbsoluteCellSize.X - CellWidth) < 1, "Six columns must fill the window")
		Check(math.abs(Layout.AbsoluteCellSize.Y - CellWidth) < 1, "Cells must remain square")
		Check(math.abs(Scroll.AbsoluteCanvasSize.Y - Canvas.AbsoluteSize.Y) < 1, "The scrollable canvas must include every row")
		Check(#Cells:GetChildren() - 1 == 6 * Rows, "The selected capacity must create the expected cells")
	end

	Check(not Canvas:FindFirstChildWhichIsA("UIAspectRatioConstraint"), "The grid must not be constrained to fit the viewport height")
	Check(Scroll.ScrollingDirection == Enum.ScrollingDirection.Y and Scroll.ClipsDescendants, "Overflow must be clipped and scroll vertically")
	for _, Rows in {8, 12, 16, 100} do
		SetLayout({Columns = 6, Rows = Rows, Positions = {}, Overflow = {}})
		Controller:UpdateBackpackGrid({})
		Settle()
		CheckGeometry(Rows, Rows)
		Check(Scroll.AbsoluteCanvasSize.Y > Scroll.AbsoluteWindowSize.Y, "Larger backpacks must have a scrollable canvas")

		Scroll.CanvasPosition = Vector2.new(0, Scroll.AbsoluteCanvasSize.Y)
		Settle()
		local LastCell = Cells:FindFirstChild(string.format("Cell_%02d_06", Rows)) :: Frame
		local LastBottom = LastCell.AbsolutePosition.Y + LastCell.AbsoluteSize.Y
		local WindowBottom = Scroll.AbsolutePosition.Y + Scroll.AbsoluteWindowSize.Y
		Check(Scroll.CanvasPosition.Y > 0 and math.abs(LastBottom - WindowBottom) < 2, "Scrolling to the end must reveal the last row")
	end

	local Width = Canvas.AbsoluteSize.X
	Panel.Size = UDim2.fromOffset(Panel.AbsoluteSize.X * 0.8, Panel.AbsoluteSize.Y * 0.8)
	Settle()
	Check(math.abs(Canvas.AbsoluteSize.X - Width) > 1, "Resizing the panel must resize the grid")
	CheckGeometry(100, 100)

	SetLayout({Columns = 6, Rows = 8, Positions = {Owned = {Column = 1, Row = 1, Width = 1, Height = 1, Rotated = false}}, Overflow = {"Excess"}})
	Controller:UpdateBackpackGrid({{Name = "Owned", Class = "Resource"}, {Name = "Excess", Class = "Resource"}})
	Settle()
	CheckGeometry(8, 10)
	Check(Canvas.OverflowNotice.Visible, "Excess items must remain accessible below the backpack")
	Check(Scroll.CanvasPosition.Y <= Scroll.AbsoluteCanvasSize.Y - Scroll.AbsoluteWindowSize.Y + 1, "Reducing capacity must clamp the scroll position")

	return tostring(Checks) .. " inventory scrolling checks passed"
end
