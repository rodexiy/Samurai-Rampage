local UpSlash = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DebounceService = Knit.GetService("DebounceService")
local Players = game:GetService("Players")
local StaminaService = Knit.GetService("StaminaService")
local SkillService = Knit.GetService("SkillService")
local AnimationService = Knit.GetService("AnimationService")
local RenderService = Knit.GetService("RenderService")
local HitboxService = Knit.GetService("HitboxService")
local HitService = Knit.GetService("HitService")
local SkillTreeService = Knit.GetService("SkillTreeService")
local DamageService = Knit.GetService("DamageService")

local Validate = require(game.ReplicatedStorage.Shared.Validate)
local Debounce = 15

function UpSlash.Charge(Attacker: Model, Data: { any })
	SkillService:SetSkillData(Attacker, "UpSlash", "Charge")
	local QuickDraw: AnimationTrack = AnimationService:PlayAnimation(Attacker, "QuickdrawCharge")
	QuickDraw.Priority = Enum.AnimationPriority.Action2

	Attacker:SetAttribute("SkillLockMovement", true)
	DebounceService:AddDebounce(Attacker, "UsingSkillCantAttack", 1)
	task.wait(0.25)
	if SkillService:GetSkillState(Attacker, "UpSlash") ~= "Charge" then
		QuickDraw:Stop()
		return
	end

	DebounceService:AddDebounce(Attacker, "Attack", 0.7)
	task.wait(0.2)
	QuickDraw:AdjustSpeed(0)
	if SkillService:GetSkillState(Attacker, "UpSlash") ~= "Charge" then
		QuickDraw:Stop()
		return
	end

	RenderService:RenderForAllPlayers("Combat", "SheathStar", { Character = Attacker })

	task.wait(0.15)

	if SkillService:GetSkillState(Attacker, "UpSlash") ~= "Charge" then
		QuickDraw:Stop()
		return
	end

	local UpSlashRelease: AnimationTrack = AnimationService:PlayAnimation(Attacker, "UpSlashRelease")
	UpSlashRelease.Priority = Enum.AnimationPriority.Action2

	task.wait(0.15)

	if SkillService:GetSkillState(Attacker, "UpSlash") ~= "Charge" then
		QuickDraw:Stop()
		return
	end

	Data.QuickDraw = QuickDraw
	UpSlash.Release(Attacker, Data)
end

function UpSlash.Release(Attacker: Model, Data: { any })
	SkillService:SetSkillData(Attacker, "UpSlash", "Release")

	AnimationService:StopAnimationFind(Attacker, "QuickdrawCharge")

	RenderService:RenderForAllPlayers("UpSlash", "Release", { Character = Attacker })

	DebounceService:AddDebounce(Attacker, "HitboxStart", 0.05)

	local DoesBlockBreak = SkillTreeService:IsSkillUnlocked(Attacker, "Up Slash Block Break")

	task.delay(0.15, function()
		HitboxService:CreatePartHitbox(Attacker, {
			Size = Vector3.new(1.5, 8.5, 8.5),
			CFrame = Attacker:GetPivot() * CFrame.new(0, 0, -4) * CFrame.Angles(0, 0, math.rad(-45)),
		}, function(Character: Model)
			local Damage = DamageService:CalculateDamage(Attacker, Character, 10, { "Weapon" })
			task.delay((Character:GetAttribute("Ping") or 0), function()
				local Context =
					HitService:NormalHit(Character, Attacker, Damage, { By = "Weapon", BlockBreak = DoesBlockBreak })

				if Context == "Hit" then
					RenderService:RenderForAllPlayers("UpSlash", "Hit", { Character = Character, Attacker = Attacker })
				end
			end)
		end)
	end)

	task.delay(0.25, function()
		Attacker:SetAttribute("SkillLockMovement", false)
		SkillService:SetSkillData(Attacker, "UpSlash", nil)
	end)
end

function UpSlash.Cancel(Attacker: Model)
	AnimationService:StopAnimationFind(Attacker, "QuickdrawCharge")
	DebounceService:RemoveDebounce(Attacker, "UsingSkillCantAttack")
	Attacker:SetAttribute("SkillLockMovement", false)
end

function UpSlash.Caller(Attacker: Model, Data: { any })
	local StaminaCost = Attacker:GetAttribute("SwordStaminaCost") * 2
	if
		Validate:CanUseSkill(Attacker, StaminaCost)
		and Attacker:GetAttribute("WeaponEquipped")
		and not Attacker:GetAttribute("UpSlashDebounce")
	then
		DebounceService:AddDebounce(Attacker, "UpSlashDebounce", Debounce, true)
		StaminaService:RemoveStamina(Attacker, StaminaCost)

		task.spawn(function()
			UpSlash.Charge(Attacker, Data)
		end)

		return true
	end
	return false
end

function UpSlash.Start() end

return UpSlash
