return function(Migration: any, Items: { [string]: any }): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	for Name, Item in Items do
		Check(Item.Class ~= "Artifact", "Artifact items must leave the item catalog: " .. Name)
	end
	Check(Items.WindVault and Items.ThunderWrath and Items.Fireball, "Keep artifact ability definitions")
	Check(Items.ArtifactRemover ~= nil, "Keep the legacy paid consumable for existing owners and receipts")

	local Data = {
		Inventory = {
			{ Name = "WindStone", Id = "wind:1", Stack = 1 },
			{ Name = "WindStone", Id = "wind:2", Stack = 1 },
			{ Name = "ThunderHeart", Id = "heart", Stack = 1 },
			{ Name = "KagutsuchiEmblem", Stack = 1 },
			{ Name = "LightNagatama", Stack = 1 },
			{ Name = "RottenLotus", Stack = 1 },
			{ Name = "LanternOfCinders", Stack = 1 },
			{ Name = "Oil", Id = "Oil", Stack = 10 },
			{ Name = "WindVault", Id = "WindVault", Stack = 1 },
			{ Name = "ArtifactRemover", Id = "ArtifactRemover", Stack = 1 },
		},
		Hotbar = { ["0"] = "WindStone", ["1"] = "WindVault", ["2"] = "ThunderHeart" },
		HotbarStackIds = { ["0"] = "wind:2", ["1"] = "WindVault", ["2"] = "heart" },
		Backpack = {
			Revision = 3,
			Positions = { ["wind:1"] = {}, ["wind:2"] = {}, heart = {}, Oil = {} },
		},
		Artifact = "WindStone",
		UnlockedNodes = { "WindVault" },
		OtherSkills = { "Grapple" },
		Equipped = { Weapon = "BasicKatana" },
	}

	Check(Migration:Migrate(Data) == 7, "Remove every retired item stack, including repeated copies")
	Check(#Data.Inventory == 3 and Data.Inventory[1].Name == "Oil", "Preserve ordinary items and artifact skills")
	Check(Data.Hotbar["0"] == nil and Data.Hotbar["2"] == nil and Data.Hotbar["1"] == "WindVault",
		"Remove only retired hotbar names")
	Check(Data.HotbarStackIds["0"] == nil and Data.HotbarStackIds["2"] == nil, "Clear retired stack assignments")
	Check(Data.Backpack.Positions["wind:1"] == nil and Data.Backpack.Positions["wind:2"] == nil
		and Data.Backpack.Positions.heart == nil and Data.Backpack.Positions.Oil ~= nil, "Clean retired grid positions")
	Check(Data.Artifact == "WindStone" and Data.UnlockedNodes[1] == "WindVault" and Data.OtherSkills[1] == "Grapple",
		"Preserve bound artifacts and skill progression")
	Check(Data.Equipped.Weapon == "BasicKatana", "Preserve equipment")
	Check(Data.Backpack.Revision == 4, "Invalidate the changed backpack layout once")
	Check(Migration:Migrate(Data) == 0 and Data.Backpack.Revision == 4, "Repeated loads must be idempotent")

	local Legacy = { Inventory = { { Name = "ThunderHeart", Stack = 1 } }, Hotbar = { ["0"] = "ThunderHeart" } }
	Check(Migration:Migrate(Legacy) == 1 and Legacy.Hotbar["0"] == nil, "Handle profiles without optional grid and stack-ID data")

	return tostring(Checks) .. " artifact removal checks passed"
end
