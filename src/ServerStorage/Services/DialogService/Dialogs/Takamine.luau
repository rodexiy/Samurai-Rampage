local Knit = require(game.ReplicatedStorage.Packages.Knit)
local DataService = Knit.GetService("DataService")
local TetsuService = Knit.GetService("TetsuService")

local Takamine = {

	Normal = {
		[1] = {
			npcName = "Takamine",
			customText = function(Player: Player)
				local PlayerData = DataService:GetData(Player)
				local AmountToPay = PlayerData.Bounty * 0.75
				return "I see you have a bounty of "
					.. PlayerData.Bounty
					.. ", if you pay me "
					.. AmountToPay
					.. " Tetsu, I can get rid of it for you."
			end,
			answers = {
				[1] = {
					text = "Ok",

					callback = function(player)
						local PlayerData = DataService:GetData(player)
						local AmountToPay = PlayerData.Bounty * 0.75
						if TetsuService:HaveTetsu(player, AmountToPay) then
							TetsuService:RemoveTetsu(player, AmountToPay)
							PlayerData.Bounty = 0
							return 3
						end

						return 2
					end,
				},

				[2] = { text = "..." },
			},
		},

		[2] = {
			npcName = "Takamine",
			npcText = "You don't have enough Tetsu, come back when you have more.",
			answers = {
				[1] = { text = "..." },
			},
		},

		[3] = {
			npcName = "Takamine",
			npcText = "Now there is no bounty for your head.",
			answers = {
				[1] = { text = "..." },
			},
		},

		priority = 0,
	},

	NoBounty = {
		[1] = {
			npcName = "Takamine",
			npcText = "If you have a bounty, talk to me, I can help you.",
			answers = {
				[1] = { text = "..." },
			},
		},

		validation = function(Player)
			local PlayerData = DataService:GetData(Player)
			return PlayerData.Bounty <= 0
		end,

		priority = 1,
	},
}

return Takamine
