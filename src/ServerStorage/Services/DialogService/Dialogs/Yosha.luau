local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TetsuService = Knit.GetService("TetsuService")

local Yosha = {
	Normal = { -- dialog tree
		[1] = { -- sempre começa no index 1, branch
			npcName = "Yosha",
			npcText = "Hello, this is an example text, you are not supposed to see this.",
			answers = {
				[1] = {
					text = "uh, i am a developer",
					nextDialog = 2, -- proximo dialogo caso escolher a resposta 1
					validateAnswer = function(Player)
						-- checagem para resposta, retornar true caso possa responder.
						-- manter pelomenos 1 botão que encerra o dialogo
						return true
					end,
				},
				[2] = { text = "why not?", nextDialog = 3 },
				[3] = { text = "all right, bye.." },
			},

			AnchorHumanoid = false, -- atributo que define se o humanoid vai ou não estar ancorado, padrão true
		},

		[2] = { -- dialogo caso escolha a resposta 1
			npcName = "Yosha",
			npcText = "alr, take this tip then.",
			answers = {
				[1] = {
					text = "ok",
					nextDialog = 4,
					callback = function(player)
						TetsuService:AddTetsu(player, 1)

						player:SetAttribute("Talked", true)
					end,
				},
			},
		},

		[3] = {
			npcName = "Yosha",
			npcText = "cuz its for devs only",
			answers = {
				[1] = { text = "give me money", nextDialog = 5 },
			},
		},

		[4] = {
			npcName = "Yosha",
			npcText = "...",
			answers = {
				[1] = { text = "bro, you are broke💀" },
			},
		},

		[5] = {
			npcName = "Yosha",
			npcText = "no",
			answers = {
				[1] = { text = "..." },
			},
		},

		-- caso queria fazer alguma validação para receber essa arvore de dialogo, checar um item, atributo, etc
		validation = function(player)
			return true
		end,

		-- prioridade do dialogo, caso a validação de true em multiplos dialogos, será escolhido o com maior prioridade
		priority = 0,
	},

	Tipped = {
		[1] = { -- começa no index 1
			npcName = "Example npc",
			npcText = "Why are you still here?.",
			answers = {
				[1] = { text = "..." },
			},
		},

		priority = 1,

		validation = function(player)
			return player:GetAttribute("Talked")
		end,
	},
}

return Yosha
