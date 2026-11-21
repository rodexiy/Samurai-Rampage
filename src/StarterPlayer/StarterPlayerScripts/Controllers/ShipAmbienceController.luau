local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local IntroCutsceneConfig = require(ReplicatedStorage.Shared.IntroCutsceneConfig)
local ShipAmbienceController = Knit.CreateController({ Name = "ShipAmbienceController" })

local Config = IntroCutsceneConfig.ShipAmbience
local RandomGenerator = Random.new()
local Active = false
local Revision = 0
local LastCreakIndex = 0
local SoundsFolder: Folder?
local NextCreak: thread?

local function CreateSound(Name: string, SoundId: string, Volume: number, Looped: boolean, Parent: Instance): Sound
	local Sound = Instance.new("Sound")
	Sound.Name = Name
	Sound.SoundId = SoundId
	Sound.Volume = Volume
	Sound.Looped = Looped
	Sound.Parent = Parent

	return Sound
end

local function PlayCreak(Token: number)
	if not Active or Token ~= Revision or not SoundsFolder then
		return
	end

	local Ids = Config.CreakSoundIds
	local Index = RandomGenerator:NextInteger(1, #Ids)
	if #Ids > 1 and LastCreakIndex > 0 then
		Index = RandomGenerator:NextInteger(1, #Ids - 1)
		if Index >= LastCreakIndex then
			Index += 1
		end
	end
	LastCreakIndex = Index
	local Sound = CreateSound("ShipCreak", Ids[Index], Config.CreakVolume, false, SoundsFolder)
	Sound.Ended:Once(function()
		Sound:Destroy()
	end)
	Sound.Destroying:Once(function()
		if not Active or Token ~= Revision then
			return
		end

		NextCreak = task.delay(RandomGenerator:NextNumber(Config.MinimumCreakInterval, Config.MaximumCreakInterval), function()
			NextCreak = nil
			PlayCreak(Token)
		end)
	end)
	Debris:AddItem(Sound, Config.MaximumCreakLifetime)
	Sound:Play()
end

function ShipAmbienceController:Start()
	if Active then
		return
	end

	Active = true
	Revision += 1
	LastCreakIndex = 0
	SoundsFolder = Instance.new("Folder")
	SoundsFolder.Name = "IntroShipAmbience"
	SoundsFolder.Parent = SoundService

	local Fire = CreateSound("ShipFire", Config.FireSoundId, Config.FireVolume, true, SoundsFolder)
	Fire:Play()
	PlayCreak(Revision)
end

function ShipAmbienceController:Stop()
	Active = false
	Revision += 1
	if NextCreak then
		task.cancel(NextCreak)
		NextCreak = nil
	end
	if SoundsFolder then
		SoundsFolder:Destroy()
		SoundsFolder = nil
	end
end

function ShipAmbienceController.KnitStart()
	task.spawn(function()
		local Sounds: { Sound } = {}
		for _, Id in Config.CreakSoundIds do
			table.insert(Sounds, CreateSound("CreakPreload", Id, 0, false, SoundService))
		end
		table.insert(Sounds, CreateSound("FirePreload", Config.FireSoundId, 0, false, SoundService))

		local Success, Error = pcall(function()
			ContentProvider:PreloadAsync(Sounds)
		end)
		for _, Sound in Sounds do
			Sound:Destroy()
		end
		if not Success then
			warn("Unable to preload ship ambience:", Error)
		end
	end)
end

return ShipAmbienceController
