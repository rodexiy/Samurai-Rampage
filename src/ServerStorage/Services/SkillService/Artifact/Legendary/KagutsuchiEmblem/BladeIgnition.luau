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

function BladeIgnition.Ignite(Attacker: Model, Data: { any })
	local Blades = BloodService:GetBlades(Attacker)
	if not Blades or not Attacker:GetAttribute("WeaponEquipped") then
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

	local Blade = Blades[1]

	if not Blade then
		return
	end

	local FireVFX: MeshPart = game.ReplicatedStorage.Assets.VFX.Buff.SwordFire:Clone()
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = Blade
	Weld.Part1 = FireVFX
	Weld.Parent = FireVFX

	local SwordTrail = Attacker.Assets:FindFirstChild("SwordTrail", true)
	local FireTrail = FireVFX:FindFirstChild("FireTrail", true)
	if FireTrail then
		if not SwordTrail then
			FireTrail.Enabled = false
		end

		FireTrail.Attachment0 = SwordTrail.Attachment0
		FireTrail.Attachment1 = SwordTrail.Attachment1
	end

	FireVFX.Name = "FireVFX"
	FireVFX.Size = Blade.Size
	FireVFX:PivotTo(Blade:GetPivot())
	FireVFX.Parent = Blade

	local Connections = Collector.new()
	Connections:Add(Attacker:GetAttributeChangedSignal("SwordOnFire"):Connect(function()
		if not Attacker:GetAttribute("SwordOnFire") then
			local Trail = FireVFX:FindFirstChildWhichIsA("Trail", true)
			if Trail then
				Trail.Enabled = false
			end

			for _, VFX in FireVFX:GetChildren() do
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

			task.wait(1)
			FireVFX:Destroy()
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
