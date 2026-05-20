local Fisherman = {
	Normal = {
		[1] = {
			npcName = "Fisherman",
			npcText = "Ah, young traveler... it's been a long time since I've seen such a curious spirit wander these lands. Perhaps you've come to unravel the mystery of the waterfall? There's something I need your help with.",
			answers = {
				{ text = "What exactly lies behind the waterfall?", nextDialog = 2 },
				{ text = "Actually, I just came to admire the view. But now you've got my attention.", nextDialog = 5 },
				{ text = "I don't have time for a fisherman's tales." },
			},
		},

		[2] = {
			npcName = "Fisherman",
			npcText = "A cavern, hidden in the shadows of the waterfall. Inside, there are three ancient statues, guardians of a forgotten secret. But the statues cannot be activated so easily... they require special fragments left behind by the ancient protectors of this place.",
			answers = {
				{ text = "Where can I find these fragments?", nextDialog = 3 },
				{ text = "Understood. Perhaps I'll investigate later.", nextDialog = 4 },
			},
		},

		[3] = {
			npcName = "Fisherman",
			npcText = "The fragments are in the hands of three guardians... powerful creatures that lurk in the nearby depths. Defeat them, collect the fragments, and offer them to the statues. They will reveal the path to the true passage.",
			answers = {
				{ text = "Alright, I'll go after the fragments.", nextDialog = 4 },
			},
		},

		[4] = {
			npcName = "Fisherman",
			npcText = "Remember, traveler: the secret behind the statues is not for the strong alone but also for the determined. Do not underestimate the guardians... and good luck.",
			answers = {
				{ text = "..." },
			},
		},

		[5] = {
			npcName = "Fisherman",
			npcText = "Heh, that's what this waterfall does. It deceives with its serene beauty but hides a mystery that calls to those who pay close attention. There's a cavern behind it, and inside are ancient statues guarding a secret far greater than it seems.",
			answers = {
				{ text = "How can I uncover this secret?", nextDialog = 6 },
			},
		},

		[6] = {
			npcName = "Fisherman",
			npcText = "To activate the statues, you'll need three fragments, each held by a powerful guardian. They roam the depths of this place, challenging anyone brave enough to face them. Defeat them, and the true path will be revealed.",
			answers = {
				{ text = "Alright, I'll go after the fragments.", nextDialog = 4 },
			},
		},

		priority = 0,
	},
}

return Fisherman
