export type GridSize = {
	Width: number,
	Height: number,
}

export type ItemData = { [string]: any }

local InventoryConfig = {}

InventoryConfig.Columns = 6
InventoryConfig.DefaultBackpackTier = 1

InventoryConfig.Backpacks = {
	{ Name = "Starter", Rows = 8 },
	{ Name = "Medium", Rows = 12 },
	{ Name = "Large", Rows = 16 },
	{ Name = "Admin", Rows = 100 },
}

InventoryConfig.Rows = InventoryConfig.Backpacks[InventoryConfig.DefaultBackpackTier].Rows

InventoryConfig.DefaultSize = { Width = 1, Height = 1 }

InventoryConfig.ClassSizes = {
	Equipable = { Width = 2, Height = 2 },
	Resource = { Width = 1, Height = 1 },
	Artifact = { Width = 1, Height = 1 },
	Usable = { Width = 1, Height = 1 },
	Health = { Width = 1, Height = 1 },
}

InventoryConfig.TypeSizes = {
	Weapon = {
		Katana = { Width = 6, Height = 1 },
		Bow = { Width = 2, Height = 4 },
		Fists = { Width = 2, Height = 1 },
	},
	Equipable = {
		Head = { Width = 2, Height = 2 },
		Torso = { Width = 2, Height = 2 },
		Legs = { Width = 2, Height = 2 },
		Face = { Width = 2, Height = 1 },
		Eyes = { Width = 2, Height = 1 },
		Back = { Width = 2, Height = 3 },
		Prosthetic = { Width = 2, Height = 2 },
	},
	Usable = {
		Tool = { Width = 2, Height = 3 },
	},
}

InventoryConfig.ItemSizes = {
	OniMask = { Width = 2, Height = 1 },
	HannyaMask = { Width = 2, Height = 2 },
	Tanegashima = { Width = 6, Height = 2 },
	Coffin = { Width = 2, Height = 4 },
	WoodenBox = { Width = 2, Height = 3 },
	Flag = { Width = 2, Height = 3 },
	Axe = { Width = 2, Height = 3 },
	Pickaxe = { Width = 3, Height = 2 },
	Shovel = { Width = 1, Height = 4 },
	BuildingHammer = { Width = 2, Height = 2 },
	Handcuffs = { Width = 2, Height = 1 },
	TradingSign = { Width = 2, Height = 3 },
	PortableRug = { Width = 2, Height = 2 },
	LanternOfCinders = { Width = 1, Height = 2 },
}

function InventoryConfig.GetSize(Item: ItemData): GridSize
	local ClassTypes = InventoryConfig.TypeSizes[Item.Class]
	local Size = Item.InventorySize
		or InventoryConfig.ItemSizes[Item.Name]
		or (ClassTypes and ClassTypes[Item.Type])
		or InventoryConfig.ClassSizes[Item.Class]
		or InventoryConfig.DefaultSize

	return {
		Width = math.max(1, math.floor(Size.Width)),
		Height = math.max(1, math.floor(Size.Height)),
	}
end

return InventoryConfig
