local WindVault = {}

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
local TweenService = game:GetService("TweenService")
local BuffService = Knit.GetService("BuffService")
local DamageService = Knit.GetService("DamageService")

local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)
local Collector = require(game.ReplicatedStorage.Shared.Collector)

local BaseDamage = 10

local Cooldown = 6
function WindVault:Charge(Attacker: Model, Data: { any })
	DebounceService:AddDebounce(Attacker, "WindVaultDebounce", Cooldown, true)
	SkillService:SetSkillData(Attacker, "WindVault", "Charge")

	StaminaService:RemoveStamina(Attacker, 15)
	task.wait(0.45)
	self:Release(Attacker, Data)
end
function WindVault:Release(Attacker: Model, Data: { any })
	if SkillService:GetSkillState(Attacker, "WindVault") ~= "Charge" then
		return
	end

	local RootCFrame = Data.RootCFrame or Attacker:GetPivot()
	RenderService:RenderForAllPlayers("WindVault", "Release", { Character = Attacker, RootCFrame = RootCFrame })
	local HITBOX_SIZE = Vector3.new(4, 4, 4)
	local RootPart = Attacker.HumanoidRootPart

	local Mass = GetModelMass(Attacker)
	local BodyVelocity = Instance.new("BodyVelocity")
	BodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 5000 * Mass
	BodyVelocity.Velocity = Attacker:GetPivot().LookVector * 50

	BodyVelocity.Parent = RootPart

	local Hitted = {}

	for i = 1, 10 do
		BodyVelocity.Velocity = Attacker:GetPivot().LookVector * 50

		HitboxService:CreatePartHitbox(Attacker, {
			DontWeld = true,
			CFrame = Attacker:GetPivot() * CFrame.new(0, 0, -(HITBOX_SIZE / 2)),
		}, function(Enemy: Model)
			if table.find(Hitted, Enemy) then
				return
			end

			table.insert(Hitted, Enemy)
			local Damage = DamageService:CalculateDamage(Attacker, Enemy, BaseDamage, { "Artifact" })
			HitService:Hit(Enemy, Attacker, Damage, { By = "Skill" })
		end)
		task.wait(0.025)
	end
	BodyVelocity:Destroy()

	SkillService:SetSkillData(Attacker, "WindVault", nil)
end

function WindVault.Caller(Attacker: Model, Data: { any })
	if
		Validate:CanUseSkill(Attacker, 15)
		and Attacker:GetAttribute("WeaponEquipped")
		and not DebounceService:HaveDebounce(Attacker, "WindVaultDebounce")
	then
		WindVault:Charge(Attacker, Data)
		return true
	end
end

function WindVault.Start() end

return WindVault
