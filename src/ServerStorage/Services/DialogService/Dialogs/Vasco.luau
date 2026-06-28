local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TetsuService = Knit.GetService("TetsuService")
local InventoryService = Knit.GetService("InventoryService")
local QuestService = Knit.GetService("QuestService")
local TutorialService = Knit.GetService("TutorialService")
local AlertService = Knit.GetService("AlertService")

local WOOD_ITEM_NAME = "WoodLog"
local WOOD_PER_BUNDLE = 5
local TETSU_PER_BUNDLE = 50
local MAKING_A_KATANA_MISSION = "TalkWithBlacksmith"
local MAKING_A_KATANA_STEPS = {
	"TalkWithBlacksmith",
	"MineResources",
	"TalkWithLumberjack",
	"ChopWood",
	"ReturnToGodot",
	"CraftKatana",
	"TalkWithGodotAfterKatana",
}

local function IsMakingAKatanaMissionActive(Player: Player): boolean
	if TutorialService:IsMissionCompleted(Player, MAKING_A_KATANA_MISSION) then
		return false
	end

	for _, StepName in MAKING_A_KATANA_STEPS do
		if TutorialService:IsMissionStep(Player, MAKING_A_KATANA_MISSION, StepName) then
			return true
		end
	end

	return false
end

local function GetWoodStack(Player: Player): number
	local Item = InventoryService:GetPlayerItemByName(Player, WOOD_ITEM_NAME)
	return if Item then Item.Stack or 0 else 0
end

local function GetWoodSale(Player: Player): (number, number)
	local Stack = GetWoodStack(Player)
	local Bundles = math.floor(Stack / WOOD_PER_BUNDLE)
	local WoodToSell = Bundles * WOOD_PER_BUNDLE

	return WoodToSell, Bundles * TETSU_PER_BUNDLE
end

local function GetTetsuForWoodAmount(Amount: number): number
	return math.floor(Amount / WOOD_PER_BUNDLE) * TETSU_PER_BUNDLE
end

local function GetWoodSaleForAmount(Player: Player, Amount: number): (number, number)
	if GetWoodStack(Player) < Amount then
		return 0, 0
	end

	return Amount, GetTetsuForWoodAmount(Amount)
end

local function SellWood(Player: Player, Amount: number?)
	if IsMakingAKatanaMissionActive(Player) then
		AlertService:AlertPlayer(Player, "Finish Making a Katana before selling wood to Vasco.", "Error")
		return
	end

	local WoodToSell, Tetsu
	if Amount then
		WoodToSell, Tetsu = GetWoodSaleForAmount(Player, Amount)
	else
		WoodToSell, Tetsu = GetWoodSale(Player)
	end

	if WoodToSell <= 0 then
		AlertService:AlertPlayer(Player, "You don't have enough Wood Logs to sell.", "Error")
		return
	end

	InventoryService:RemoveItemFromPlayer(Player, WOOD_ITEM_NAME, WoodToSell)
	TetsuService:AddTetsu(Player, Tetsu)
	AlertService:AlertPlayer(Player, "Vasco bought " .. WoodToSell .. " Wood Logs for " .. Tetsu .. " Tetsu.", "Success")
end

return {
	TalkWithBlacksmith = {
		[1] = {
			npcName = "Vasco",
			npcText = "Who is you?, I never saw you before.",
			answers = {
				[1] = {
					text = "",
					customText = function(Player)
						return "My name is "
							.. Player.Name
							.. ", My boat sank and Godot helped me, im here to get some wood for him. He said you can give me an axe."
					end,
					nextDialog = 2,
				},
			},
		},

		[2] = {
			npcName = "Vasco",
			npcText = "He is a chill guy, here, take this axe. Also I can buy some wood of you, come back later, but dont expect too much money.",
			answers = {
				[1] = {
					text = "Thank you.",
					callback = function(Player)
						QuestService:CallQuestFunction(Player, "StartWoodcutting")
					end,
				},
			},
		},

		priority = 100,
		validation = function(Player)
			return TutorialService:IsMissionStep(Player, "TalkWithBlacksmith", "TalkWithLumberjack")
		end,
	},

	MineResources = {
		[1] = {
			npcName = "Vasco",
			npcText = "Godot sent you, huh? Finish mining the iron and coal first. Come back when he points you my way, and I'll help with the wood.",
			answers = {
				[1] = { text = "Alright, I'll keep mining." },
			},
		},

		priority = 50,
		validation = function(Player)
			return TutorialService:IsMissionStep(Player, "TalkWithBlacksmith", "MineResources")
		end,
	},

	Normal = {
		[1] = {
			npcName = "Vasco",
			npcText = "Got wood to sell? I pay 50 Tetsu for every 5 Wood Logs.",
			answers = {
				[1] = {
					text = "I want to sell Wood Logs.",
					nextDialog = 2,
					validateAnswer = function(Player)
						if IsMakingAKatanaMissionActive(Player) then
							return false
						end

						local WoodToSell = GetWoodSale(Player)
						return WoodToSell > 0
					end,
				},
				[2] = { text = "Maybe later." },
			},
		},

		[2] = {
			npcName = "Vasco",
			npcText = "",
			customText = function(Player: Player)
				local WoodToSell, Tetsu = GetWoodSale(Player)
				return "I can buy up to " .. WoodToSell .. " Wood Logs for " .. Tetsu .. " Tetsu."
			end,
			answers = {
				[1] = {
					text = "",
					customText = function()
						return "Sell 5 Wood Logs [" .. GetTetsuForWoodAmount(5) .. " Tetsu]"
					end,
					callback = function(Player)
						SellWood(Player, 5)
					end,
				},
				[2] = {
					text = "",
					customText = function()
						return "Sell 25 Wood Logs [" .. GetTetsuForWoodAmount(25) .. " Tetsu]"
					end,
					callback = function(Player)
						SellWood(Player, 25)
					end,
				},
				[3] = {
					text = "",
					customText = function()
						return "Sell 50 Wood Logs [" .. GetTetsuForWoodAmount(50) .. " Tetsu]"
					end,
					callback = function(Player)
						SellWood(Player, 50)
					end,
				},
				[4] = {
					text = "",
					customText = function(Player: Player)
						local WoodToSell, Tetsu = GetWoodSale(Player)
						return "Sell all (" .. WoodToSell .. " Wood Logs) [" .. Tetsu .. " Tetsu]"
					end,
					callback = SellWood,
				},
				[5] = { text = "Never mind." },
			},
		},

		priority = 0,
	},
}
