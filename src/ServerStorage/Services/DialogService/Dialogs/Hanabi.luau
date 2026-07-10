local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DataService = Knit.GetService("DataService")
local QuestService = Knit.GetService("QuestService")
local SideQuestService = Knit.GetService("SideQuestService")

local QUEST_NAME = "HanabiBandage"
local HERBS_REQUIRED = 6
local BANDAGES_REQUIRED = 3

local function GetQuest(Player: Player)
	local PlayerData = DataService:GetData(Player)
	return PlayerData and PlayerData.Quest
end

local function GetActiveQuestName(Player: Player): string?
	local Quest = GetQuest(Player)
	return Quest and Quest.Name
end

local function IsHanabiQuestActive(Player: Player): boolean
	return GetActiveQuestName(Player) == QUEST_NAME
end

local function CanOfferQuest(Player: Player): boolean
	return SideQuestService:CanOfferQuest(Player, QUEST_NAME)
end

return {
	Normal = {
		[1] = {
			npcName = "Hanabi",
			npcText = "Could you help me for a moment? I am short on clean bandages, but the right herbs grow close by.",
			answers = {
				[1] = {
					text = "I can gather them.",
					actionType = "accept",
					callback = function(Player)
						if CanOfferQuest(Player) then
							QuestService:GiveQuest(Player, QUEST_NAME)
						end
					end,
				},
				[2] = { text = "Maybe later." },
			},
		},

		priority = 0,
		validation = CanOfferQuest,
	},

	TrainingLocked = {
		[1] = {
			npcName = "Hanabi",
			npcText = "Mikoto is expecting you for combat training. Come back once you have learned how to protect yourself.",
			answers = {
				[1] = { text = "I will." },
			},
		},

		priority = 5,
		validation = function(Player)
			return not SideQuestService:IsQuestUnlocked(Player, QUEST_NAME)
		end,
	},

	WithQuest = {
		[1] = {
			npcName = "Hanabi",
			npcText = "",
			customText = function(Player)
				local Quest = GetQuest(Player)
				if Quest and (Quest.HerbsGathered or 0) >= HERBS_REQUIRED then
					return "Those herbs will work. Craft them into " .. BANDAGES_REQUIRED .. " Bandages, please."
				end

				return "The Healing Herbs grow close to my shop. Bring back enough to make " .. BANDAGES_REQUIRED .. " Bandages."
			end,
			answers = {
				[1] = { text = "I will handle it." },
			},
		},

		priority = 20,
		validation = IsHanabiQuestActive,
	},

	Busy = {
		[1] = {
			npcName = "Hanabi",
			npcText = "You already have something important to finish. Come back when your hands are free.",
			answers = {
				[1] = { text = "Alright." },
			},
		},

		priority = 10,
		validation = function(Player)
			return GetActiveQuestName(Player) ~= nil and not IsHanabiQuestActive(Player)
		end,
	},

	Completed = {
		[1] = {
			npcName = "Hanabi",
			npcText = "Thank you for the bandages. Small kindnesses keep a village standing.",
			answers = {
				[1] = { text = "..." },
			},
		},

		priority = 30,
		validation = function(Player)
			return SideQuestService:IsQuestCompleted(Player, QUEST_NAME)
		end,
	},
}
