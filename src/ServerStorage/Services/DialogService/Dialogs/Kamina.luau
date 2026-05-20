local Kamina = {
	Normal = {
		[1] = {
			npcName = "Kamina",
			npcText = "How's it going, Samurai? Are you here for honor or credits?",
			answers = {
				{ text = "I'm here for work", nextDialog = 2 },
				{ text = "Honor", nextDialog = 4 },
				{ text = "Just looking for now.", nextDialog = 6 },
			},
		},

		[2] = {
			npcName = "Kamina",
			npcText = "Take a look at the board; see if any of the jobs interest you.",
			answers = {
				{ text = "Thank you.", nextDialog = 3 },
				{ text = "..." },
			},
		},

		[3] = {
			npcName = "Kamina",
			npcText = "Don't die, or rather, don't fail... Good luck, Samurai.",
			answers = {
				{ text = "..." },
			},
		},

		[4] = {
			npcName = "Kamina",
			npcText = "Playing noble in the mud, huh? Let's see how long that lasts.",
			answers = {
				{ text = "Honor is all that's left when the credits run out.", nextDialog = 5 },
				{ text = "..." },
			},
		},

		[5] = {
			npcName = "Kamina",
			npcText = "Tsk, I guess all samurais are the same after all.",
			answers = {
				{ text = "..." },
			},
		},

		[6] = {
			npcName = "Kamina",
			npcText = "Just looking won't pay your bills, if you even pay bills...",
			answers = {
				{ text = "..." },
			},
		},

		priority = 0,
	},
}

return Kamina
