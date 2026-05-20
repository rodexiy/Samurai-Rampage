local Knit = require(game.ReplicatedStorage.Packages.Knit)
local TetsuService = Knit.GetService("TetsuService")
local DataService = Knit.GetService("DataService")

local Kwon = {
	Normal = {
		[1] = {
			npcName = "Kwon",
			npcText = "...",
			answers = {
				{ text = "This soup looks good.", nextDialog = 2 },
				{ text = "I've never seen you around here before.", nextDialog = 4 },
				{ text = "Jinx?", nextDialog = 10 },
				{ text = "..." },
			},
		},

		[2] = {
			npcName = "Kwon",
			npcText = "This place makes the best soups in the world—spicy but delicious, with the perfect balance.",
			answers = {
				{
					text = "What's in it?",
					nextDialog = 3,
				},
				{
					text = "...",
				},
			},
		},

		[3] = {
			npcName = "Kwon",
			npcText = "Miso, chili, tofu, mushrooms, green onions, and some spices.",
			answers = {
				{
					text = "Maybe I'll order a bowl...",
				},
			},
		},

		[4] = {
			npcName = "Kwon",
			npcText = "And I see plenty of samurais like you around here.",
			answers = {
				{ text = "Like me?", nextDialog = 5 },
				{ text = "..." },
			},
		},

		[5] = {
			npcName = "Kwon",
			npcText = "Who do whatever they feel like, always looking for endless battles.",
			answers = {
				{
					text = "Maybe. But every battle, no matter how long, has an end. And what happens after that?",
					nextDialog = 6,
				},
			},
		},

		[6] = {
			npcName = "Kwon",
			npcText = "The battle never truly ends, but what defines a warrior is what they do between the strikes.",
			answers = {
				{
					text = "Are you a Samurai?",
					nextDialog = 7,
				},
			},
		},

		[7] = {
			npcName = "Kwon",
			npcText = "Almost that.",
			answers = {
				{
					text = "Maybe one day we'll face each other.",
					nextDialog = 8,
				},
			},
		},

		[8] = {
			npcName = "Kwon",
			npcText = "(Laughs) Yeah, maybe.",
			answers = {
				{
					text = "*Pay a soup for Kwon [25 Tetsu]*",

					validateAnswer = function(Player)
						local PlayerData = DataService:GetData(Player)
						PlayerData.NPCs.PaidSoupForKwon = false

						if PlayerData.NPCs.PaidSoupForKwon then
							return false
						end

						local Tetsu = TetsuService:GetTetsu(Player)
						if Tetsu >= 25 then
							return true
						end
						return false
					end,

					callback = function(Player)
						local PlayerData = DataService:GetData(Player)

						local Tetsu = TetsuService:GetTetsu(Player)
						if Tetsu >= 25 then
							PlayerData.NPCs.PaidSoupForKwon = true
							TetsuService:RemoveTetsu(Player, 25)
							return true
						end

						return false
					end,

					nextDialog = 9,
				},
				{
					text = "...",
				},
			},
		},

		[9] = {
			npcName = "Kwon",
			npcText = "(Laughs) I don't remember the last time someone did something like that for me… Thank you.",
			answers = {
				{
					text = "...",
				},
			},
		},

		[10] = {
			npcName = "Kwon",
			npcText = "Pronouncing that name in public is like opening your own throat. Do you want me to finish the job for you?",
			answers = {
				{
					text = "I want to know where I can find them.",
					nextDialog = function(Player)
						local PlayerData = DataService:GetData(Player)
						if not PlayerData.NPCs.PaidSoupForKwon then
							return 11
						end
						return 12
					end,
				},
			},
		},

		[11] = {
			npcName = "Kwon",
			npcText = "If you need to ask, you're already too far from them... or close enough that you won't be able to go back.",
			answers = {
				{
					text = "...",
				},
			},
		},

		[12] = {
			npcName = "Kwon",
			npcText = "If you really want to find them, go to the lost temple in the forest. But whatever you seek there, ask yourself if it's worth your life.",
			answers = {
				{
					text = "I have nothing left to lose.",
					nextDialog = 13,
				},
			},
		},

		[13] = {
			npcName = "Kwon",
			npcText = "But don't be fooled by the seals. They are not just protection... they are a warning.",
			answers = {
				{
					text = "...",
				},
			},
		},

		priority = 0,
	},
}

return Kwon
