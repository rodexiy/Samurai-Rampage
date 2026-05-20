local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SoundEffectService = Knit.CreateService({
	Name = "SoundEffectService",
})

function SoundEffectService:PlaySoundEffect(Name: string | Sound, newInstance: boolean?, Parent: Instance?)
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

			if Parent and Parent:IsA("Model") then
				Parent = Parent.PrimaryPart or Parent:FindFirstChildWhichIsA("BasePart") or Parent
			end

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

function SoundEffectService:AddPitchEffect(Sound: Sound, min: number, max: number)
	local Pitch = Instance.new("PitchShiftSoundEffect")
	Pitch.Octave = math.random(min * 1000, max * 1000) / 1000
	Pitch.Parent = Sound
end

function SoundEffectService:PlayRandomFromFolder(FolderName: string | Folder, newInstance: boolean?, Parent: Instance?)
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

		return SoundEffectService:PlaySoundEffect(Sound, newInstance, Parent)
	end
end

function SoundEffectService:CustomSwordWoosh(Attacker: Model, AttackName: string)
	if AttackName == "M1" then
		if Attacker:GetAttribute("SwordOnFire") then
			return SoundEffectService:PlayRandomFromFolder("FlameWoosh", true, Attacker)
		elseif Attacker:GetAttribute("ConfettiOnSword") then
			return SoundEffectService:PlayRandomFromFolder("ConfettiWoosh", true, Attacker)
		else
			return SoundEffectService:PlaySoundEffect("Swing", true, Attacker)
		end
	elseif AttackName == "M2" then
		if Attacker:GetAttribute("SwordOnFire") then
			return SoundEffectService:PlaySoundEffect("FlameWoosh_3", true, Attacker)
		elseif Attacker:GetAttribute("ConfettiOnSword") then
			return SoundEffectService:PlaySoundEffect("ConfettiWoosh_3", true, Attacker)
		else
			return SoundEffectService:PlaySoundEffect("Swing", true, Attacker)
		end
	end
end

function SoundEffectService.KnitInit() end

function SoundEffectService.KnitStart() end

return SoundEffectService
