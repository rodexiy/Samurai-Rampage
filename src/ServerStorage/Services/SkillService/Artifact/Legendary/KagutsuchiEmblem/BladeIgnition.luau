local BladeIgnition = {}

local Validate = require(game.ReplicatedStorage.Shared.Validate)

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local DebounceService = Knit.GetService("DebounceService")
local StaminaService = Knit.GetService("StaminaService")
local SkillService = Knit.GetService("SkillService")
local AnimationService = Knit.GetService("AnimationService")
local RenderService = Knit.GetService("RenderService")
local HitboxService = Knit.GetService("HitboxService")
local HitService = Knit.GetService("HitService")
local LagCompensationService = Knit.GetService("LagCompensationService")
local BloodService = Knit.GetService("BloodService")
local SkillTreeService = Knit.GetService("SkillTreeService")

local TweenService = game:GetService("TweenService")

local Collector = require(game.ReplicatedStorage.Shared.Collector)

local function GetBladeSwordTrail(Blade: BasePart): Trail?
	local DirectTrail = Blade:FindFirstChild("SwordTrail")
	if DirectTrail and DirectTrail:IsA("Trail") then
		return DirectTrail
	end

	local Weapon = Blade:FindFirstAncestorWhichIsA("Model")
	if not Weapon then
		return nil
	end

	local SwordTrail = Weapon:FindFirstChild("SwordTrail", true)
	if SwordTrail and SwordTrail:IsA("Trail") then
		return SwordTrail
	end

	return nil
end

local function AttachEffectTrailToBlade(EffectVFX: Instance, Blade: BasePart, TrailName: string)
	local EffectTrail = EffectVFX:FindFirstChild(TrailName, true)
	if not EffectTrail or not EffectTrail:IsA("Trail") then
		return
	end

	local SwordTrail = GetBladeSwordTrail(Blade)
	if not SwordTrail then
		EffectTrail.Enabled = false
		return
	end

	EffectTrail.Attachment0 = SwordTrail.Attachment0
	EffectTrail.Attachment1 = SwordTrail.Attachment1
end

local function DisableFireVFX(FireVFX: Instance)
	local Trail = FireVFX:FindFirstChildWhichIsA("Trail", true)
	if Trail then
		Trail.Enabled = false
	end

	for _, VFX in FireVFX:GetDescendants() do
		if VFX:IsA("ParticleEmitter") then
			VFX.Enabled = false
		end
	end

	local Sound = FireVFX:FindFirstChildWhichIsA("Sound", true)
	if Sound then
		TweenService:Create(Sound, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { Volume = 0 }):Play()
	end

	local PointLight = FireVFX:FindFirstChildWhichIsA("PointLight", true)
	if PointLight then
		TweenService:Create(PointLight, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { Brightness = 0 }):Play()
	end
end

function BladeIgnition.Ignite(Attacker: Model, Data: { any })
	local Blades = BloodService:GetBlades(Attacker)
	if #Blades == 0 or not Attacker:GetAttribute("WeaponEquipped") then
		return
	end

	DebounceService:AddDebounce(Attacker, "BladeIgnitionDebounce", 120, true)

	local WasOnFire = Attacker:GetAttribute("SwordOnFire")

	local FireDuration = 25
	if SkillTreeService:IsSkillUnlocked(Attacker, "Blade Ignition II") then
		FireDuration = 45
	end

	DebounceService:AddDebounce(Attacker, "SwordOnFire", FireDuration)

	Attacker:SetAttribute("ConfettiOnSword", false)

	if WasOnFire then
		return
	end

	local FireVFXs = {}
	for _, Blade in Blades do
		local FireVFX: MeshPart = game.ReplicatedStorage.Assets.VFX.Buff.SwordFire:Clone()
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = Blade
		Weld.Part1 = FireVFX
		Weld.Parent = FireVFX

		AttachEffectTrailToBlade(FireVFX, Blade, "FireTrail")

		FireVFX.Name = "FireVFX"
		FireVFX.Size = Blade.Size
		FireVFX:PivotTo(Blade:GetPivot())
		FireVFX.Parent = Blade
		table.insert(FireVFXs, FireVFX)
	end

	local Connections = Collector.new()
	Connections:Add(Attacker:GetAttributeChangedSignal("SwordOnFire"):Connect(function()
		if not Attacker:GetAttribute("SwordOnFire") then
			for _, FireVFX in FireVFXs do
				DisableFireVFX(FireVFX)
			end

			task.wait(1)
			for _, FireVFX in FireVFXs do
				FireVFX:Destroy()
			end
			Connections:Destroy()
		end
	end))
end

function BladeIgnition.Caller(Attacker: Model, Data: { any })
	if
		Validate:CanUseSkill(Attacker, 5)
		and (Attacker.Name == "Yamarashi" or not DebounceService:HaveDebounce(Attacker, "BladeIgnitionDebounce"))
	then
		BladeIgnition.Ignite(Attacker, Data)
		return true
	end
end

function BladeIgnition.Start() end

return BladeIgnition
