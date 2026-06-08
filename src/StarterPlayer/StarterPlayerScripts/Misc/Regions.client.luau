local DEBUG_MODE = false

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local ZoneLibrary = require(ReplicatedStorage.Assets.Libraries.Zone)

local SoundRegions = ReplicatedStorage:FindFirstChild("SoundRegions")
if SoundRegions then
	SoundRegions.Parent = workspace
end

local LightingRegions = ReplicatedStorage:FindFirstChild("LightingRegions")
local NamedRegions = ReplicatedStorage:FindFirstChild("NamedRegions")
local OSTRegions = ReplicatedStorage:FindFirstChild("OSTRegions")

local SoundPackage = SoundService:WaitForChild("SoundServicePackage")
local Ambiences = SoundPackage:WaitForChild("Ambience")
local OSTFolder = SoundPackage:WaitForChild("OST")

local PlayingAmbiences = {}
local Tweens = {}
local OSTTweens = {}
local AmbienceTweens = {}
local InNamedRegions = {}

local FadeTime = 10
local OSTWaitTime = { 20, 45 }
local CombatCrossfade = 1

local CurrentRegion
local CurrentOST
local CurrentCombatOST
local CurrentAmbience
local CombatActive = false
local StopOST = false
local MusicActive = false

local function DebugPrint(...)
	if DEBUG_MODE then
		print(...)
	end
end

local function IsOSTEnabled()
	return Player:GetAttribute("OST") ~= false
end

local function FadeSound(sound, targetVolume, duration, tweenTable)
	if not sound then
		return
	end
	if tweenTable[sound] then
		tweenTable[sound]:Cancel()
	end
	local tween = TweenService:Create(sound, TweenInfo.new(duration), { Volume = targetVolume })
	tweenTable[sound] = tween
	tween:Play()
end

local function StopSound(sound, fade)
	if not sound then
		return
	end
	local duration = fade or FadeTime
	FadeSound(sound, 0, duration, OSTTweens)
	DebugPrint("[SOUND] Stopping:", sound.Name)
	task.delay(duration, function()
		if sound and sound.IsPlaying then
			sound:Stop()
		end
	end)
end

local function PauseSound(sound, fade)
	if not sound then
		return
	end
	local duration = fade or FadeTime
	DebugPrint("[SOUND] Pausing:", sound.Name)
	FadeSound(sound, 0, duration, OSTTweens)
	task.delay(duration, function()
		if sound and sound.IsPlaying then
			sound:Pause()
		end
	end)
end

local function ResumeSound(sound, fade)
	if not sound or not IsOSTEnabled() then
		return
	end
	DebugPrint("[SOUND] Resuming:", sound.Name)
	sound:Play()
	FadeSound(sound, sound:GetAttribute("DefaultVolume") or 0.8, fade or FadeTime, OSTTweens)
end

local function PlaySound(sound)
	if not sound or not IsOSTEnabled() then
		return
	end
	DebugPrint("[SOUND] Playing:", sound.Name)
	sound.TimePosition = 0
	sound.Looped = false
	sound.Volume = 0
	sound:Play()
	MusicActive = true
	FadeSound(sound, sound:GetAttribute("DefaultVolume") or 0.8, FadeTime, OSTTweens)
end

--// Stops all ambiences when OST/Combat starts
local function FadeAmbienceOut()
	DebugPrint("[AMBIENCE] Fading out ALL ambiences")

	for _, amb in ipairs(Ambiences:GetChildren()) do
		if amb:IsA("Sound") and amb.IsPlaying then
			FadeSound(amb, 0, 1, AmbienceTweens)
			task.delay(1, function()
				if amb and amb.IsPlaying then
					DebugPrint("[AMBIENCE] Stopped ambience:", amb.Name)
					amb:Stop()
				end
			end)
		end
	end

	CurrentAmbience = nil
end

local function FadeAmbienceIn(regionName)
	if CombatActive or MusicActive then
		return
	end
	if not CurrentRegion or CurrentRegion ~= regionName then
		return
	end
	local amb = Ambiences:FindFirstChild(regionName)
	if not amb then
		return
	end
	if not amb.IsPlaying then
		DebugPrint("[AMBIENCE] Starting ambience:", regionName)
		amb.Looped = true
		amb:Play()
	end
	FadeSound(amb, amb:GetAttribute("DefaultVolume") or 0.5, FadeTime, AmbienceTweens)
	CurrentAmbience = amb
end

local function RegionOSTLoop(regionName)
	if StopOST or not IsOSTEnabled() then
		return
	end
	local RegionFolder = OSTFolder:FindFirstChild(regionName)
	if not RegionFolder or #RegionFolder:GetChildren() == 0 then
		FadeAmbienceIn(regionName)
		return
	end

	while CurrentRegion == regionName and not CombatActive do
		if not IsOSTEnabled() then
			break
		end

		local song = RegionFolder:GetChildren()[math.random(1, #RegionFolder:GetChildren())]
		if not song then
			break
		end

		DebugPrint("[OST] Starting OST for region:", regionName, "→", song.Name)

		FadeAmbienceOut()
		CurrentOST = song:Clone()
		CurrentOST.Parent = SoundService
		PlaySound(CurrentOST)

		local ended = false
		CurrentOST.Ended:Connect(function()
			DebugPrint("[OST] Ended:", CurrentOST.Name)
			ended = true
		end)

		repeat
			task.wait(1)
		until ended or CombatActive or StopOST or CurrentRegion ~= regionName

		if ended and not CombatActive then
			DebugPrint("[OST] Finished playing, restoring ambience for:", regionName)
			StopSound(CurrentOST)
			MusicActive = false
			FadeAmbienceIn(regionName)
			task.wait(math.random(OSTWaitTime[1], OSTWaitTime[2]))
		end

		if CombatActive or StopOST or CurrentRegion ~= regionName then
			DebugPrint("[OST] Loop stopped due to combat/region change.")
			break
		end
	end
end

local function PlayCombatMusic(regionName)
	if not IsOSTEnabled() then
		FadeAmbienceIn(regionName)
		return
	end

	DebugPrint("[COMBAT] Combat music triggered in:", regionName)
	FadeAmbienceOut()
	if CurrentOST then
		PauseSound(CurrentOST, CombatCrossfade)
	end
	if CurrentCombatOST then
		StopSound(CurrentCombatOST, 0.2)
	end

	local combatFolder = OSTFolder:FindFirstChild(regionName .. "_Combat") or OSTFolder:FindFirstChild("DefaultCombat")
	if not combatFolder or #combatFolder:GetChildren() == 0 then
		return
	end

	local song = combatFolder:GetChildren()[math.random(1, #combatFolder:GetChildren())]
	DebugPrint("[COMBAT] Playing combat track:", song.Name)
	CurrentCombatOST = song:Clone()
	CurrentCombatOST.Parent = SoundService
	CurrentCombatOST.Volume = 0
	CurrentCombatOST:Play()
	MusicActive = true
	FadeSound(CurrentCombatOST, CurrentCombatOST:GetAttribute("DefaultVolume") or 0.8, CombatCrossfade, OSTTweens)
end

local function StopCombatMusic()
	if not CurrentCombatOST then
		if CurrentRegion then
			FadeAmbienceIn(CurrentRegion)
		end
		return
	end
	DebugPrint("[COMBAT] Combat ended, fading out:", CurrentCombatOST.Name)
	StopSound(CurrentCombatOST, CombatCrossfade)
	task.delay(CombatCrossfade, function()
		if not CombatActive and CurrentOST then
			DebugPrint("[COMBAT] Resuming previous OST:", CurrentOST.Name)
			ResumeSound(CurrentOST, CombatCrossfade)
		elseif not CombatActive and not CurrentOST and CurrentRegion and IsOSTEnabled() then
			DebugPrint("[COMBAT] No OST, resuming Region OST loop.")
			task.defer(RegionOSTLoop, CurrentRegion)
		else
			DebugPrint("[COMBAT] No OST to resume, restoring ambience.")
			FadeAmbienceIn(CurrentRegion)
		end
	end)
end

Player:GetAttributeChangedSignal("InCombat"):Connect(function()
	local inCombat = Player:GetAttribute("InCombat")

	if inCombat and not CombatActive then
		DebugPrint("[COMBAT] Player entered combat.")
		CombatActive = true
		FadeAmbienceOut()
		PlayCombatMusic(CurrentRegion or "Default")
	elseif not inCombat and CombatActive then
		DebugPrint("[COMBAT] Player left combat.")
		CombatActive = false
		StopCombatMusic()
	end
end)

for _, Ambience in Ambiences:GetChildren() do
	Ambience.Looped = true
	Ambience:Play()
	Ambience.TimePosition = math.random(0, Ambience.TimeLength / 2)
	if not Ambience:GetAttribute("DefaultVolume") then
		Ambience:SetAttribute("DefaultVolume", Ambience.Volume)
	end
	Ambience.Volume = 0
end

if SoundRegions then
	for _, Container in SoundRegions:GetChildren() do
		local Zone = ZoneLibrary.new(Container)
		Zone:relocate()
		local SoundLastExit = {}

		Zone.localPlayerEntered:Connect(function()
			DebugPrint("[ZONE] Entered sound region:", Container.Name)
			local Sound = Ambiences:FindFirstChild(Container.Name, true)
			table.insert(PlayingAmbiences, Sound)
			if not Sound then
				return
			end
			if Tweens[Sound] then
				Tweens[Sound]:Cancel()
				Tweens[Sound] = nil
			end
			local Tween = TweenService:Create(Sound, TweenInfo.new(1), { Volume = Sound:GetAttribute("DefaultVolume") })
			Tweens[Sound] = Tween
			Tween:Play()
		end)

		Zone.localPlayerExited:Connect(function()
			DebugPrint("[ZONE] Exited sound region:", Container.Name)
			local Sound = Ambiences:FindFirstChild(Container.Name, true)
			if not Sound then
				return
			end
			local now = os.clock()
			SoundLastExit[Sound] = now
			task.wait(1)
			if SoundLastExit[Sound] ~= now then
				return
			end
			local Tween = TweenService:Create(Sound, TweenInfo.new(1), { Volume = 0 })
			Tweens[Sound] = Tween
			Tween:Play()
		end)
	end
end

if LightingRegions then
	LightingRegions.Parent = workspace
	for _, Container in LightingRegions:GetChildren() do
		local Zone = ZoneLibrary.new(Container)
		Zone:relocate()
		Zone.localPlayerEntered:Connect(function()
			DebugPrint("[LIGHT] Entered lighting region:", Container.Name)
			Player:SetAttribute("LightingRegion", Container.Name)
		end)
		Zone.localPlayerExited:Connect(function()
			DebugPrint("[LIGHT] Exited lighting region:", Container.Name)
			Player:SetAttribute("LightingRegion", false)
		end)
	end
end

local function UpdateNamedRegions(name, left)
	if left then
		DebugPrint("[NAMED] Left region:", name)
		Player:SetAttribute("NamedRegion", false)
	else
		DebugPrint("[NAMED] Entered region:", name)
		Player:SetAttribute("NamedRegion", name)
	end
end

if NamedRegions then
	NamedRegions.Parent = workspace
	for _, Container in NamedRegions:GetChildren() do
		local Zone = ZoneLibrary.new(Container)
		Zone:relocate()
		Zone.localPlayerEntered:Connect(function()
			UpdateNamedRegions(Container.Name)
			table.insert(InNamedRegions, Container.Name)
		end)
		Zone.localPlayerExited:Connect(function()
			table.remove(InNamedRegions, table.find(InNamedRegions, Container.Name))
			UpdateNamedRegions(Container.Name, true)
		end)
	end
end

if OSTRegions then
	OSTRegions.Parent = workspace
	for _, Container in OSTRegions:GetChildren() do
		local Zone = ZoneLibrary.new(Container)
		Zone:relocate()

		Zone.localPlayerEntered:Connect(function()
			if CurrentRegion == Container.Name then
				return
			end
			DebugPrint("[OST] Entered OST region:", Container.Name)

			StopOST = true
			if CurrentOST then
				StopSound(CurrentOST, 1)
				CurrentOST = nil
			end
			if CurrentCombatOST then
				StopSound(CurrentCombatOST, 1)
				CurrentCombatOST = nil
			end
			FadeAmbienceOut()
			StopOST = false
			CurrentRegion = Container.Name
			if IsOSTEnabled() then
				task.defer(RegionOSTLoop, CurrentRegion)
			else
				FadeAmbienceIn(CurrentRegion)
			end
		end)

		Zone.localPlayerExited:Connect(function()
			if CurrentRegion ~= Container.Name then
				return
			end
			DebugPrint("[OST] Exited OST region:", Container.Name)
			StopOST = true
			if CurrentOST then
				StopSound(CurrentOST, 1)
				CurrentOST = nil
			end
			if CurrentCombatOST then
				StopSound(CurrentCombatOST, 1)
				CurrentCombatOST = nil
			end
			FadeAmbienceOut()
			CurrentRegion = nil
		end)
	end
end

local function UpdateAmbienceGroup()
	DebugPrint("[AMBIENCE] Group volume update:", Player:GetAttribute("Ambience"))
	Ambiences.Volume = if Player:GetAttribute("Ambience") then 1 else 0
end

Player:GetAttributeChangedSignal("Ambience"):Connect(UpdateAmbienceGroup)

local function UpdateOST()
	if IsOSTEnabled() then
		StopOST = false
		if CurrentRegion and not CombatActive and not CurrentOST then
			task.defer(RegionOSTLoop, CurrentRegion)
		elseif CurrentRegion and not CombatActive then
			FadeAmbienceIn(CurrentRegion)
		end
	else
		StopOST = true
		if CurrentOST then
			StopSound(CurrentOST, 1)
			CurrentOST = nil
		end
		if CurrentCombatOST then
			StopSound(CurrentCombatOST, 1)
			CurrentCombatOST = nil
		end
		MusicActive = false
		if CurrentRegion then
			FadeAmbienceIn(CurrentRegion)
		end
	end
end

Player:GetAttributeChangedSignal("OST"):Connect(UpdateOST)
UpdateOST()
