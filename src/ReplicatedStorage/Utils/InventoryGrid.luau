local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryConfig = require(ReplicatedStorage.Shared.InventoryConfig)

export type Placement = {
	Column: number,
	Row: number,
	Width: number,
	Height: number,
	Rotated: boolean,
}

export type Layout = {
	Placements: { Placement },
	Rows: number,
}

type Occupancy = { { boolean } }

local InventoryGrid = {}

function InventoryGrid.IsInteger(Value: any): boolean
	return typeof(Value) == "number" and Value == Value and math.abs(Value) < math.huge and Value % 1 == 0
end

function InventoryGrid.Placement(Item: InventoryConfig.ItemData, Column: number, Row: number, Rotated: boolean): Placement
	local Size = InventoryConfig.GetSize(Item)
	return {
		Column = Column,
		Row = Row,
		Width = if Rotated then Size.Height else Size.Width,
		Height = if Rotated then Size.Width else Size.Height,
		Rotated = Rotated,
	}
end

function InventoryGrid.Blockers(Positions: { [string]: Placement }, Candidate: Placement, Columns: number, Rows: number, Ignore: string?): ({ string }, boolean)
	local Outside = Candidate.Column < 1 or Candidate.Row < 1
		or Candidate.Column + Candidate.Width - 1 > Columns or Candidate.Row + Candidate.Height - 1 > Rows
	local Blockers = {}

	for Name, Other in Positions do
		if Name ~= Ignore and Candidate.Column < Other.Column + Other.Width and Other.Column < Candidate.Column + Candidate.Width
			and Candidate.Row < Other.Row + Other.Height and Other.Row < Candidate.Row + Candidate.Height then
			table.insert(Blockers, Name)
		end
	end

	return Blockers, Outside
end

function InventoryGrid.Fits(Positions: { [string]: Placement }, Candidate: Placement, Columns: number, Rows: number, Ignore: string?): boolean
	local Blockers, Outside = InventoryGrid.Blockers(Positions, Candidate, Columns, Rows, Ignore)
	return not Outside and #Blockers == 0
end

function InventoryGrid.FindPlacement(Item: InventoryConfig.ItemData, Positions: { [string]: Placement }, Columns: number, Rows: number, Preferred: Placement?): Placement?
	if Preferred then
		local Candidate = InventoryGrid.Placement(Item, Preferred.Column, Preferred.Row, Preferred.Rotated)
		if InventoryGrid.Fits(Positions, Candidate, Columns, Rows) then
			return Candidate
		end
	end

	for _, Rotated in {false, true} do
		local Candidate = InventoryGrid.Placement(Item, 1, 1, Rotated)
		for Row = 1, Rows - Candidate.Height + 1 do
			for Column = 1, Columns - Candidate.Width + 1 do
				Candidate.Column, Candidate.Row = Column, Row
				if InventoryGrid.Fits(Positions, Candidate, Columns, Rows) then
					return Candidate
				end
			end
		end
	end

	return nil
end

local function CanPlace(Grid: Occupancy, Column: number, Row: number, Width: number, Height: number): boolean
	for CellRow = Row, Row + Height - 1 do
		local OccupiedRow = Grid[CellRow]
		if OccupiedRow then
			for CellColumn = Column, Column + Width - 1 do
				if OccupiedRow[CellColumn] then
					return false
				end
			end
		end
	end

	return true
end

local function FindSpace(Grid: Occupancy, Columns: number, UsedRows: number, Width: number, Height: number): (number, number)
	for Row = 1, UsedRows do
		for Column = 1, Columns - Width + 1 do
			if CanPlace(Grid, Column, Row, Width, Height) then
				return Column, Row
			end
		end
	end

	return 1, UsedRows + 1
end

local function Occupy(Grid: Occupancy, Placement: Placement)
	for Row = Placement.Row, Placement.Row + Placement.Height - 1 do
		local OccupiedRow = Grid[Row] or {}
		Grid[Row] = OccupiedRow

		for Column = Placement.Column, Placement.Column + Placement.Width - 1 do
			OccupiedRow[Column] = true
		end
	end
end

function InventoryGrid.Arrange(Items: { InventoryConfig.ItemData }, Columns: number, MinimumRows: number, UniformSize: boolean?): Layout
	assert(Columns >= 1 and Columns % 1 == 0, "Inventory columns must be a positive integer")
	local Grid: Occupancy = {}
	local Placements: { Placement } = {}
	local UsedRows = 0

	for Index, Item in Items do
		local Size = if UniformSize then InventoryConfig.DefaultSize else InventoryConfig.GetSize(Item)
		local Rotated = not UniformSize and Item.Rotated == true
		local Width = if Rotated then Size.Height else Size.Width
		local Height = if Rotated then Size.Width else Size.Height
		assert(Width <= Columns, string.format("Item %s is wider than the inventory grid", Item.Name or tostring(Index)))

		local Column, Row = FindSpace(Grid, Columns, UsedRows, Width, Height)
		local Placement: Placement = { Column = Column, Row = Row, Width = Width, Height = Height, Rotated = Rotated }
		Occupy(Grid, Placement)
		Placements[Index] = Placement
		UsedRows = math.max(UsedRows, Row + Height - 1)
	end

	return { Placements = Placements, Rows = math.max(1, MinimumRows, UsedRows) }
end

return InventoryGrid
