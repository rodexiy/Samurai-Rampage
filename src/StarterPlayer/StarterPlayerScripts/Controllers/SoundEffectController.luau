local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SoundEffectController = Knit.CreateController({
	Name = "SoundEffectController",
})

function SoundEffectController:PlaySoundEffect(Name: string | Sound, newInstance: boolean?, Parent: Instance?): Sound?
	local Sound: Sound?
	if Name and typeof(Name) ~= "string" then
		Sound = Name
	else
		Sound = SoundService:FindFirstChild(Name, true) :: Sound?
	end

	if Sound then
		if not newInstance then
			task.defer(function()
				Sound:Play()
			end)

			return Sound	
		else
			local NewSound = Sound:Clone()
			if Parent and Parent:IsA("Model") then
				Parent = Parent.PrimaryPart or Parent:FindFirstChildWhichIsA("BasePart") or Parent
			end

			NewSound.Name = HttpService:GenerateGUID(false)
			NewSound.Parent = Parent or Sound.Parent

			local function PlayWhenLoaded()
				if NewSound.Parent then
					NewSound:Play()
				end
			end

			NewSound.Ended:Once(function()
				NewSound:Destroy()
			end)
			if NewSound.IsLoaded then
				task.defer(PlayWhenLoaded)
			else
				NewSound.Loaded:Once(PlayWhenLoaded)
				task.delay(15, function()
					if NewSound.Parent and not NewSound.IsLoaded then
						NewSound:Destroy()
					end
				end)
			end
			if NewSound.Looped then
				Debris:AddItem(NewSound, 30)
			end

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
): Sound?
	local Folder: Folder? = if typeof(FolderName) == "Instance" then FolderName :: Folder else nil
	if typeof(FolderName) == "string" then
		Folder = SoundService:FindFirstChild(FolderName, true) :: Folder?
	end

	if not Folder or not Folder:IsA("Folder") then
		return
	end

	local Sounds: { Sound } = {}
	for _, Child in Folder:GetChildren() do
		if Child:IsA("Sound") then
			table.insert(Sounds, Child)
		end
	end
	if #Sounds == 0 then
		return nil
	end

	return self:PlaySoundEffect(Sounds[math.random(1, #Sounds)], newInstance, Parent)
end

function SoundEffectController.KnitInit() end

function SoundEffectController.KnitStart() end

return SoundEffectController
