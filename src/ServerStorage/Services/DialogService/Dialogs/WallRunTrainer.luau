local Knit = require(game.ReplicatedStorage.Packages.Knit)
local DataService = Knit.GetService("DataService")
local Players = game:GetService("Players")
local TetsuService = Knit.GetService("TetsuService")
local RenderService = Knit.GetService("RenderService")
local AlertService = Knit.GetService("AlertService")

local LearningThreads = {}

local FinishPosition = game.ReplicatedStorage.Assets.Quests.WallRun.Target.Position

local WallRunTrainer = {
	Normal = {
		[1] = {
			npcName = "WallRunTrainer",
			npcText = "Want to run on walls? I can teach you! I just want 5000 tetsu once you learn.",
			answers = {
				[1] = {
					text = "Deal.",
					callback = function(player)
						player:SetAttribute("LearningWallRun", true)
						RenderService:RenderForPlayer(player, "WallRunTrainer", "LoadQuest")
						if LearningThreads[player.UserId] then
							task.cancel(LearningThreads[player.UserId])
							LearningThreads[player.UserId] = nil
						end

						local function Learned()
							if TetsuService:RemoveTetsu(player, 5000) then
								AlertService:AlertPlayer(player, "You learned the skill of wallrunning!", "Success")
								RenderService:RenderForPlayer(player, "WallRunTrainer", "ExitQuest")
								player:SetAttribute("LearningWallRun", false)
							end
						end

						LearningThreads[player.UserId] = task.spawn(function()
							while true do
								if not player or not player.Parent or not player.Character then
									LearningThreads[player.UserId] = nil
									break
								end

								if (FinishPosition - player.Character:GetPivot().Position).Magnitude < 5 then
									LearningThreads[player.UserId] = nil
									Learned()

									break
								end

								task.wait(0.5)
							end
						end)
					end,
					validateAnswer = function(Player)
						return TetsuService:HaveTetsu(Player, 5000)
					end,
					nextDialog = 2,
				},

				[2] = { text = "..." },
			},
		},

		[2] = {
			npcName = "WallRunTrainer",
			npcText = "Use shift lock, jump and then press jump again with the character on the side of the wall to start wallrunning.",
			answers = {
				[1] = { text = "..." },
			},
		},

		priority = 0,
	},

	WithQuest = {
		[1] = {
			npcName = "WallRunTrainer",
			npcText = "How can i help you?",
			answers = {
				[1] = {
					text = "How do i wallrun?",
					nextDialog = 2,
				},

				[2] = {
					text = "I want to quit.",
					callback = function(player)
						RenderService:RenderForPlayer(player, "WallRunTrainer", "ExitQuest")
						task.cancel(LearningThreads[player.UserId])
						LearningThreads[player.UserId] = nil
						player:SetAttribute("LearningWallRun", false)
					end,
				},
			},
		},

		[2] = {
			npcName = "WallRunTrainer",
			npcText = "Use shift lock, jump and then press jump again with the character on the side of the wall to start wallrunning.",
			answers = {
				[1] = {
					text = "...",
				},
			},
		},

		validation = function(Player)
			return Player:GetAttribute("LearningWallRun")
		end,

		priority = 1,
	},

	Learned = {
		[1] = {
			npcName = "WallRunTrainer",
			npcText = "Congratulations! I don't have anything else to teach you.",
			answers = {
				[1] = {
					text = "...",
				},
			},
		},

		validation = function(Player)
			return false
		end,

		priority = 2,
	},
}

return WallRunTrainer
