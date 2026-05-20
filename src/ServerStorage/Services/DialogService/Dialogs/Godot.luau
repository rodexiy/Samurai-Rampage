local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TetsuService = Knit.GetService("TetsuService")
local ItemService = Knit.GetService("ItemService")
local InventoryService = Knit.GetService("InventoryService")

local ores = {
	["Coal"] = 5,
	["IronOre"] = 10,
	["GoldOre"] = 25,
}

local function GetOres(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	local Item = Character:FindFirstChildWhichIsA("Tool")
	if not Item then
		return
	end
	if ores[Item.Name] == nil then
		return
	end

	return ores[Item.Name] * Item:GetAttribute("Stack"), Item
end

local Godot = {
	Normal = {
		[1] = {
			npcName = "Godot",
			npcText = "Hello, how can i help you?",
			answers = {
				[1] = {
					text = "I want to sell some ores..",
					nextDialog = 2,
					validateAnswer = function(Player)
						return GetOres(Player) ~= nil
					end,
				},
				[2] = { text = "..." },
			},
		},

		[2] = {
			npcName = "Godot",
			npcText = "",
			customText = function(Player: Player)
				local Total = GetOres(Player)
				return "I can buy what you have for " .. (Total or 0) .. " Tetsu"
			end,
			answers = {
				[1] = {
					text = "ok",
					callback = function(player)
						local Total, Item = GetOres(player)
						if not Total or not Item then
							return
						end

						InventoryService:RemoveItemFromPlayer(player, Item.Name, Item:GetAttribute("Stack"))
						TetsuService:AddTetsu(player, Total)
					end,
				},
				[2] = { text = "..." },
			},
		},

		priority = 0,
	},
}

return Godot
