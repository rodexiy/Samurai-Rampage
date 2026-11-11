local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RangedWeaponConfig = require(ReplicatedStorage.Shared.RangedWeaponConfig)

local RangedWeaponEffectsController = Knit.CreateController({ Name = "RangedWeaponEffectsController" })

local AimingCharacter: Model? = nil
local AimingConfig: any = nil

local function PlayCharacterSound(Character: Model, SoundId: string)
	local Root = Character.PrimaryPart
	if not Character.Parent or not Root then
		return
	end

	local Sound = Instance.new("Sound")
	Sound.Name = "TanegashimaHandling"
	Sound.SoundId = SoundId
	Sound.Volume = 0.7
	Sound.RollOffMinDistance = 5
	Sound.RollOffMaxDistance = 70
	Sound.Parent = Root
	Debris:AddItem(Sound, 15)
	Sound.Ended:Once(function()
		Sound:Destroy()
	end)
	Sound:Play()
end

function RangedWeaponEffectsController:SetAiming(Character: Model, Aiming: boolean)
	if Aiming then
		local Config = RangedWeaponConfig.GetForCharacter(Character)
		if not Config.IsFirearm or AimingCharacter == Character then
			return
		end

		AimingCharacter = Character
		AimingConfig = Config
		PlayCharacterSound(Character, Config.AimSound)
	elseif AimingCharacter == Character then
		local Config = AimingConfig
		AimingCharacter = nil
		AimingConfig = nil
		PlayCharacterSound(Character, Config.StopAimSound)
	end
end

function RangedWeaponEffectsController:PlayReadySound(Character: Model, ItemName: string?)
	local Config = if ItemName then RangedWeaponConfig.Get(ItemName) else RangedWeaponConfig.GetForCharacter(Character)
	if Config.IsFirearm then
		PlayCharacterSound(Character, Config.ReadySound)
	end
end

local function PlayShot(Shooter: Player, Origin: Vector3, Config: any)
	local Emitter = Instance.new("Attachment")
	Emitter.Name = "TanegashimaAudioEmitter"
	Emitter.Parent = workspace.Terrain
	Emitter.WorldPosition = Origin
	Debris:AddItem(Emitter, 15)

	local Sound = Instance.new("Sound")
	Sound.SoundId = Config.ShotSound
	Sound.Volume = 1
	Sound.RollOffMinDistance = 15
	Sound.RollOffMaxDistance = 600
	Sound.Parent = Emitter
	Sound.Ended:Once(function()
		Emitter:Destroy()
	end)
	Sound:Play()

	local Character = Shooter.Character
	local Model = Character and Character:FindFirstChild("BowModel")
	if not Model or Character:GetAttribute("Bow") ~= Config.WeaponName then
		return
	end

	for _, Particle: ParticleEmitter in Model:QueryDescendants("ParticleEmitter") do
		local Count = Particle:GetAttribute("EmitCount")
		Particle:Emit(if typeof(Count) == "number" then Count else Config.DefaultEmitCount)
	end
	for _, Light: PointLight in Model:QueryDescendants("PointLight") do
		Light.Enabled = true
		task.delay(Config.MuzzleLightDuration, function()
			if Light.Parent then
				Light.Enabled = false
			end
		end)
	end
end

function RangedWeaponEffectsController.KnitStart()
	Knit.GetService("BowService").Projectile:Connect(function(Action: string, _Id: number, ...: any)
		if Action ~= "Launch" then
			return
		end

		local Shooter, Origin, _Velocity, _Acceleration, _ServerTime, ItemName = ...
		local Config = RangedWeaponConfig.Get(ItemName)
		if Config.IsFirearm then
			PlayShot(Shooter, Origin, Config)
		end
	end)
end

return RangedWeaponEffectsController
