local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SoundEffectController = Knit.CreateController({
	Name = "SoundEffectController",
})

function SoundEffectController:PlaySoundEffect(Name: string | Sound, newInstance: boolean?, Parent: Instance?)
	local Sound: Sound
	if Name and typeof(Name) ~= "string" then
		Sound = Name
	else
		Sound = SoundService:FindFirstChild(Name, true)
	end

	if Sound then
		if not newInstance then
			task.defer(function()
				Sound:Play()
			end)

			return Sound	
		else
			local NewSound = Sound:Clone()

			NewSound.Name = HttpService:GenerateGUID(false)
			NewSound.Parent = Parent or Sound.Parent

			if not NewSound.IsLoaded then
				repeat
					task.wait()
				until NewSound.IsLoaded
			end

			task.defer(function()
				NewSound:Play()
				Debris:AddItem(NewSound, NewSound.TimeLength + 0.25)
			end)

			return NewSound
		end
	end
end

function SoundEffectController:AddPitchEffect(Sound: Sound, min: number, max: number)
	if not Sound then
		return
	end
	local Pitch = Sound:FindFirstChildWhichIsA("PitchShiftSoundEffect", true) or Instance.new("PitchShiftSoundEffect")
	Pitch.Octave = math.random(min * 1000, max * 1000) / 1000
	Pitch.Parent = Sound
end

function SoundEffectController:PlayRandomFromFolder(
	FolderName: string | Folder,
	newInstance: boolean?,
	Parent: Instance?
)
	local Folder: Folder = FolderName
	if typeof(FolderName) == "string" then
		Folder = SoundService:FindFirstChild(FolderName, true)
	end

	if not Folder:IsA("Folder") then
		return
	end

	if Folder then
		local Sounds = Folder:GetChildren()
		local Sound = Sounds[math.random(1, #Sounds)]

		SoundEffectController:PlaySoundEffect(Sound, newInstance, Parent)
	end
end

function SoundEffectController.KnitInit() end

function SoundEffectController.KnitStart() end

return SoundEffectController
