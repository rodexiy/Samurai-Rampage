return function(CreateController: (any) -> any, CreateEffects: (any) -> any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local Sounds = {}
	local Effects = CreateEffects({
		Instance = { new = function(): any
			local Sound = { Ended = { Once = function() end } }
			function Sound:Play()
				table.insert(Sounds, self.SoundId)
			end
			return Sound
		end },
	})
	local Attributes = { BowEquipped = false, WeaponEquipped = true }
	local Character = {
		Parent = true, PrimaryPart = {},
		GetAttribute = function(_Self: any, Name: string): any
			return Attributes[Name]
		end,
	}
	local Delays = {}
	local Harness = CreateController({
		Character = Character, Effects = Effects,
		Task = { delay = function(Duration: number, Callback: () -> ())
			table.insert(Delays, { Duration = Duration, Callback = Callback })
		end },
		Workspace = { GetServerTimeNow = function(): number
			return 100
		end },
	})
	Harness.Schedule(107, "Tanegashima")
	Check(#Sounds == 0 and Delays[1].Duration == 7, "Wait for reload completion before playing the sound")
	Delays[1].Callback()
	Check(#Sounds == 1 and Sounds[1] == "rbxassetid://160608684",
		"Play the reload sound with the musket removed and the sword equipped")

	Harness.Schedule(107, "Tanegashima")
	Harness.Schedule(109, "Tanegashima")
	Delays[2].Callback()
	Check(#Sounds == 1, "A newer reload cancels an obsolete completion callback")
	Delays[3].Callback()
	Check(#Sounds == 2, "The newest reload still completes normally")
	Harness.Schedule(107, "Tanegashima")
	Attributes.Died = true
	Delays[4].Callback()
	Check(#Sounds == 2, "Do not play reload completion after death")
	Attributes.Died = false
	Harness.Schedule(107, "Tanegashima")
	Harness.SetCharacter(nil)
	Delays[5].Callback()
	Check(#Sounds == 2, "Do not play a previous character's reload after respawn")

	return string.format("Tanegashima reload sound: %d checks passed", Checks)
end
