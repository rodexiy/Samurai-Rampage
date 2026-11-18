-- Run production acquisition services with isolated profiles and the real grid module.
return function(Inventory: any, Grid: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end

	local function Key(Column: number, Row: number): string
		return tostring(Column) .. ":" .. tostring(Row)
	end

	local function Reset(Free: { [string]: boolean })
		Context.Data = {
			Inventory = {}, Equipped = {}, Hotbar = {}, Stances = {},
			Backpack = { Version = 1, Columns = 6, Rows = 8, Revision = 0, Positions = {} },
		}
		for Row = 1, 8 do
			for Column = 1, 6 do
				if Free[Key(Column, Row)] then
					continue
				end
				local Id = "Blocker:" .. Key(Column, Row)
				table.insert(Context.Data.Inventory, { Name = "Apple", Stack = 1, Id = Id })
				Context.Data.Backpack.Positions[Id] = { Column = Column, Row = Row, Width = 1, Height = 1, Rotated = false }
			end
		end
		Grid:GetLayout(Player)
	end

	local function Rectangle(Column: number, Row: number, Width: number, Height: number): { [string]: boolean }
		local Free = {}
		for Y = Row, Row + Height - 1 do
			for X = Column, Column + Width - 1 do
				Free[Key(X, Y)] = true
			end
		end

		return Free
	end

	local function Position(Name: string): any
		local Item = Inventory:GetRawPlayerItemByName(Player, Name)
		return Item and Grid:GetLayout(Player).Positions[Item.Id]
	end

	Reset(Rectangle(6, 1, 1, 6))
	local Count = #Context.Data.Inventory
	Check(Inventory:CanReceiveItem(Player, { Name = "BasicKatana", Stack = 1 }), "Capacity checks must accept a katana when only vertical space remains")
	Check(#Context.Data.Inventory == Count, "Capacity checks must not add items")
	Check(Inventory:GiveItemToPlayer(Player, { Name = "BasicKatana", Stack = 1 }) == 1, "Receiving must use the vertical gap")
	local Placement = Position("BasicKatana")
	Check(Placement and Placement.Rotated and Placement.Width == 1 and Placement.Height == 6, "The delivered katana must save its vertical footprint")
	Check(Placement.Column == 6 and Placement.Row == 1, "Delivery must preserve occupied cells and use the only free column")
	local Entries = Inventory:GetInventory(Player)
	for _, Item in Entries do
		if Item.Name == "BasicKatana" then
			Check(Item.Rotated and Item.InventoryPosition.Rotated, "The client snapshot must contain the saved rotation")
		end
	end
	Check(Position("BasicKatana").Rotated, "Refreshing the layout must retain automatic rotation")

	Reset(Rectangle(3, 2, 2, 3))
	Check(Inventory:GiveItemToPlayer(Player, { Name = "Pickaxe", Stack = 1 }) == 1, "A 3x2 tool must also fit a 2x3 gap")
	Placement = Position("Pickaxe")
	Check(Placement.Rotated and Placement.Width == 2 and Placement.Height == 3, "Rectangular tools must save the rotated dimensions")

	Reset(Rectangle(2, 4, 3, 2))
	Check(Inventory:GiveItemToPlayer(Player, { Name = "Flag", Stack = 1 }) == 1, "A 2x3 item must also fit a 3x2 gap")
	Placement = Position("Flag")
	Check(Placement.Rotated and Placement.Width == 3 and Placement.Height == 2, "Orientation fallback must work in both directions")

	local Free = Rectangle(6, 1, 1, 6)
	for Column = 1, 6 do
		Free[Key(Column, 1)] = true
	end
	Reset(Free)
	Check(Inventory:GiveItemToPlayer(Player, { Name = "BasicKatana", Stack = 1 }) == 1, "Prepare both available orientations")
	Check(not Position("BasicKatana").Rotated, "Delivery should prefer the normal orientation when it fits")

	Reset(Rectangle(5, 1, 2, 6))
	Check(Inventory:GiveItemToPlayer(Player, { Name = "BasicKatana", Stack = 2 }) == 2, "Multiple incoming copies must each search rotated positions")
	local Layout = Grid:GetLayout(Player)
	local Copies = 0
	for _, Item in Context.Data.Inventory do
		if Item.Name == "BasicKatana" then
			Copies += 1
			Check(Layout.Positions[Item.Id].Rotated, "Each physical copy must keep its own rotated placement")
		end
	end
	Check(Copies == 2 and #Layout.Overflow == 0, "Auto rotation must not merge physical copies or overflow the backpack")

	Reset({ ["1:1"] = true, ["3:1"] = true, ["5:1"] = true, ["2:3"] = true, ["4:3"] = true, ["6:3"] = true })
	Count = #Context.Data.Inventory
	Check(not Inventory:CanReceiveItem(Player, { Name = "BasicKatana", Stack = 1 }), "Disconnected free cells must not count as a fitting rectangle")
	Check(Inventory:GiveItemToPlayer(Player, { Name = "BasicKatana", Stack = 1 }) == 0 and #Context.Data.Inventory == Count, "Delivery must reject items when neither orientation fits")

	Reset(Rectangle(2, 2, 2, 2))
	Check(Inventory:GiveItemToPlayer(Player, { Name = "SamuraiHelmet", Stack = 1 }) == 1, "Square items should still fit normally")
	Check(not Position("SamuraiHelmet").Rotated, "Square items should keep their normal orientation")

	return tostring(Checks) .. " automatic item delivery rotation checks passed"
end
