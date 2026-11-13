-- Run against the production config, grid module, and item index in Studio.
return function(Config: any, Grid: any, Items: { [string]: any }): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function CheckSize(Name: string, Width: number, Height: number)
		local Size = Config.GetSize(Items[Name])
		Check(Size.Width == Width and Size.Height == Height, "Incorrect footprint for " .. Name)
	end

	local function CheckLayout(Entries: { any }, Columns: number, MinimumRows: number, Uniform: boolean?): any
		local Layout = Grid.Arrange(Entries, Columns, MinimumRows, Uniform)
		Check(#Layout.Placements == #Entries, "Every item must receive a placement")
		Check(Layout.Rows >= MinimumRows, "The grid must preserve its minimum height")
		local Occupied = {}

		for Index, Placement in Layout.Placements do
			Check(Placement.Column >= 1 and Placement.Column + Placement.Width - 1 <= Columns, "Item crosses a column boundary")
			Check(Placement.Row >= 1 and Placement.Row + Placement.Height - 1 <= Layout.Rows, "Item crosses a row boundary")
			local Size = if Uniform then Config.DefaultSize else Config.GetSize(Entries[Index])
			local Width = if Placement.Rotated then Size.Height else Size.Width
			local Height = if Placement.Rotated then Size.Width else Size.Height
			Check(Placement.Width == Width and Placement.Height == Height, "Packing must preserve the footprint")

			for Row = Placement.Row, Placement.Row + Placement.Height - 1 do
				for Column = Placement.Column, Placement.Column + Placement.Width - 1 do
					local Key = tostring(Row) .. ":" .. tostring(Column)
					Check(not Occupied[Key], "Items must never overlap")
					Occupied[Key] = true
				end
			end
		end

		return Layout
	end

	for Name, Item in Items do
		if Item.Type == "Katana" then
			CheckSize(Name, 6, 1)
		elseif Item.Class == "Equipable" and (Item.Type == "Head" or Item.Type == "Torso" or Item.Type == "Legs") then
			CheckSize(Name, 2, 2)
		elseif Item.Class == "Resource" then
			CheckSize(Name, 1, 1)
		end
	end

	CheckSize("OniMask", 2, 1)
	CheckSize("HannyaMask", 2, 2)
	CheckSize("Tanegashima", 6, 2)
	CheckSize("Bow", 2, 4)
	CheckSize("Pickaxe", 3, 2)
	CheckSize("Shovel", 1, 4)
	CheckSize("RedGlasses", 2, 1)
	CheckSize("Coffin", 2, 4)

	local Override = Config.GetSize({Name = "BasicKatana", Class = "Weapon", Type = "Katana", InventorySize = {Width = 3, Height = 2}})
	Check(Override.Width == 3 and Override.Height == 2, "Explicit item footprint must override category defaults")
	local Unknown = Config.GetSize({Name = "FutureItem"})
	Check(Unknown.Width == 1 and Unknown.Height == 1, "Unconfigured items must default to one cell")

	local Empty = CheckLayout({}, 8, 6)
	Check(Empty.Rows == 6, "An empty backpack must remain 8 by 6")
	local Stack = table.clone(Items.IronOre)
	Stack.Stack = 999
	local Stacked = CheckLayout({Stack}, 8, 6)
	Check(Stacked.Placements[1].Width == 1 and Stacked.Placements[1].Height == 1, "Stack quantity must not enlarge an item")

	local Mixed = {Items.BasicKatana, Items.BasicKatana, Items.SamuraiHelmet, Items.IronOre, Items.OniMask, Items.HannyaMask, Items.PolicePants}
	local MixedLayout = CheckLayout(Mixed, 8, 6)
	Check(MixedLayout.Placements[3].Column == 7 and MixedLayout.Placements[3].Row == 1, "A 2 by 2 helmet must fill the gap beside two katanas")
	local RepeatLayout = Grid.Arrange(Mixed, 8, 6)
	for Index, Placement in MixedLayout.Placements do
		local Repeated = RepeatLayout.Placements[Index]
		Check(Repeated.Column == Placement.Column and Repeated.Row == Placement.Row, "Repeated rendering must keep a deterministic layout")
	end

	local Rotated = table.clone(Items.BasicKatana)
	Rotated.Rotated = true
	local RotatedLayout = CheckLayout({Rotated, Items.SamuraiHelmet, Items.IronOre}, 8, 6)
	Check(RotatedLayout.Placements[1].Width == 1 and RotatedLayout.Placements[1].Height == 6, "Rotation must swap footprint axes")
	CheckLayout(Mixed, 8, 6, true)

	local ManyKatanas = {}
	for _ = 1, 12 do
		table.insert(ManyKatanas, Items.BasicKatana)
	end
	local Overflow = CheckLayout(ManyKatanas, 8, 6)
	Check(Overflow.Rows == 12, "Grid height must account for shape fragmentation, not just item count or total area")

	local AllItems = {}
	local Names = {}
	for Name in Items do
		table.insert(Names, Name)
	end
	table.sort(Names)
	for _, Name in Names do
		table.insert(AllItems, Items[Name])
	end
	CheckLayout(AllItems, 8, 6)

	local Random = Random.new(4291)
	for _ = 1, 20 do
		local Entries = {}
		for _ = 1, 35 do
			table.insert(Entries, AllItems[Random:NextInteger(1, #AllItems)])
		end
		CheckLayout(Entries, 8, 6)
	end

	local Success = pcall(function()
		Grid.Arrange({Items.BasicKatana}, 5, 6)
	end)
	Check(not Success, "An item wider than the grid must not be silently shrunk")

	return tostring(Checks) .. " inventory grid checks passed"
end
