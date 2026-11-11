local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BowConfig = require(ReplicatedStorage.Shared.BowConfig)
local BowSoundController = Knit.CreateController({ Name = "BowSoundController" })

local SoundEffectController
local ChargingTemplate: Sound
local EquipTemplate: Sound
local ShootFolder: Folder
local ImpactSounds: { [string]: Folder | Sound } = {}
local ChargingSounds: { [Model]: Sound } = {}

function BowSoundController:StopCharging(Character: Model)
	local Sound = ChargingSounds[Character]
	ChargingSounds[Character] = nil
	if Sound then
		Sound:Stop()
		Sound:Destroy()
	end
end

local function UpdateCharging(Character: Model)
	BowSoundController:StopCharging(Character)
	if not Character.Parent or not Character:GetAttribute("BowDrawing") or not Character:GetAttribute("BowEquipped") then
		return
	end

	local Started = Character:GetAttribute("BowDrawStarted")
	local Remaining = BowConfig.FullChargeTime - (if typeof(Started) == "number" then workspace:GetServerTimeNow() - Started else 0)
	local Root = Character.PrimaryPart
	if Remaining <= 0 or not Root then
		return
	end

	local Sound = SoundEffectController:PlaySoundEffect(ChargingTemplate, true, Root)
	if not Sound then
		return
	end
	ChargingSounds[Character] = Sound
	task.delay(Remaining, function()
		if ChargingSounds[Character] == Sound then
			BowSoundController:StopCharging(Character)
		end
	end)
end

local function BindCharacter(Character: Model)
	Character:GetAttributeChangedSignal("BowDrawing"):Connect(function()
		UpdateCharging(Character)
	end)
	Character:GetAttributeChangedSignal("BowEquipped"):Connect(function()
		if Character:GetAttribute("BowEquipped") then
			local Root = Character.PrimaryPart
			if Root then
				SoundEffectController:PlaySoundEffect(EquipTemplate, true, Root)
			end
		else
			BowSoundController:StopCharging(Character)
		end
	end)
	Character.Destroying:Once(function()
		BowSoundController:StopCharging(Character)
	end)
	UpdateCharging(Character)
end

local function PlayAtPosition(Source: Folder | Sound, Position: Vector3)
	local Emitter = Instance.new("Attachment")
	Emitter.Name = "BowAudioEmitter"
	Emitter.Parent = workspace.Terrain
	Emitter.WorldPosition = Position
	Debris:AddItem(Emitter, 15)

	local Sound = if Source:IsA("Sound") then SoundEffectController:PlaySoundEffect(Source, true, Emitter)
		else SoundEffectController:PlayRandomFromFolder(Source, true, Emitter)
	if Sound then
		Sound.Ended:Once(function()
			Emitter:Destroy()
		end)
	else
		Emitter:Destroy()
	end
end

function BowSoundController.KnitStart()
	SoundEffectController = Knit.GetController("SoundEffectController")
	local Package = SoundService:WaitForChild("SoundServicePackage")
	local Combat = Package:WaitForChild("Combat")
	local Sounds = Combat:WaitForChild("Bow")
	ChargingTemplate = Sounds:WaitForChild("Bow Charging") :: Sound
	EquipTemplate = Sounds:WaitForChild("Bow Equip") :: Sound
	ShootFolder = Sounds:WaitForChild("Bow Shoot") :: Folder
	local Materials = Sounds:WaitForChild("Bow Impacts")
	ImpactSounds = {
		Player = Sounds:WaitForChild("Bow Hit") :: Folder,
		Metal = Materials:WaitForChild("Metal") :: Sound,
		Wood = Materials:WaitForChild("Wood") :: Sound,
		Default = Materials:WaitForChild("Default") :: Sound,
	}

	local function BindPlayer(Player: Player)
		Player.CharacterAdded:Connect(BindCharacter)
		Player.CharacterRemoving:Connect(function(Character: Model)
			BowSoundController:StopCharging(Character)
		end)
		if Player.Character then
			BindCharacter(Player.Character)
		end
	end
	Players.PlayerAdded:Connect(BindPlayer)
	for _, Player in Players:GetPlayers() do
		BindPlayer(Player)
	end

	Knit.GetService("BowService").Projectile:Connect(function(Action: string, _Id: number, ...: any)
		if Action == "Launch" then
			local _Shooter, Origin = ...
			PlayAtPosition(ShootFolder, Origin)
		elseif Action == "Hit" then
			local Position, _Velocity, HitPart, ImpactType = ...
			local Kind = ImpactType or BowConfig.GetImpactSoundType(HitPart)
			PlayAtPosition(ImpactSounds[Kind] or ImpactSounds.Default, Position)
		end
	end)
end

return BowSoundController
