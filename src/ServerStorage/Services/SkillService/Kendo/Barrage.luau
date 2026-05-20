local Barrage = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DebounceService = Knit.GetService("DebounceService")
local Players = game:GetService("Players")
local StaminaService = Knit.GetService("StaminaService")
local SkillService = Knit.GetService("SkillService")
local AnimationService = Knit.GetService("AnimationService")
local RenderService = Knit.GetService("RenderService")
local HitboxService = Knit.GetService("HitboxService")
local HitService = Knit.GetService("HitService")
local LagCompensationService = Knit.GetService("LagCompensationService")
local DamageService = Knit.GetService("DamageService")

local Validate = require(game.ReplicatedStorage.Shared.Validate)

local Debounce = 20
local Multiplier = 2

function Barrage.Charge(Attacker: Model, Data: { any })
	SkillService:SetSkillData(Attacker, "Barrage", "Charge")

	RenderService:RenderForAllPlayers("Combat", "Kanji", { Character = Attacker })
	DebounceService:AddDebounce(Attacker, "UsingSkillCantAttack", 0.5)
	task.wait(0.25)

	if SkillService:GetSkillState(Attacker, "Barrage") ~= "Charge" then
		return
	end

	Barrage.Release(Attacker, Data)
end

function Barrage.Release(Attacker: Model, Data: { any })
	SkillService:SetSkillData(Attacker, "Barrage", "Release")

	local Animations = game.ReplicatedStorage.Assets.Animations.Stances.Advanced.M1:GetChildren()

	DebounceService:AddDebounce(Attacker, "Attack", 0.1)

	local AttacksAmount = #Animations * 2

	local BarrageDuration = 2

	for _ = 1, BarrageDuration do
		for _, Animation in Animations do
			AnimationService:StopAnimationFind(Attacker, "Deflected")
			AnimationService:StopAnimationFind(Attacker, "Barrage_Attack")

			if Attacker:GetAttribute("PostureBreak") or Attacker:GetAttribute("Ragdoll") then
				break
			end

			DebounceService:AddDebounce(Attacker, "UsingSkillCantAttack", 0.15)

			DebounceService:AddDebounce(Attacker, "Attack", 0.1)

			local AttackAnimation: AnimationTrack = AnimationService:PlayAnimation(Attacker, Animation)
			AttackAnimation.Name = "Barrage_Attack"

			local StaminaCost = Attacker:GetAttribute("SwordStaminaCost") * 4
			StaminaService:RemoveStamina(Attacker, StaminaCost / AttacksAmount)
			AttackAnimation:AdjustSpeed(1.85)

			RenderService:RenderForAllPlayers(
				"Combat",
				"AttackSlash",
				{ Character = Attacker, SlashInstance = Animation:FindFirstChild("Slash") }
			)

			HitboxService:CreatePartHitbox(Attacker, {
				Size = Vector3.new(6, 6, 6),
				Frames = 1,
				IgnoreCheck = true,
			}, function(Character: Model)
				task.delay(LagCompensationService:GetCompensation(Character), function()
					local Damage = DamageService:CalculateDamage(Attacker, Character, 35, { "Weapon" }) / AttacksAmount
					HitService:NormalHit(
						Character,
						Attacker,
						Damage,
						{ By = "Weapon", ExtendDeflectTime = true, ExtendDuration = 0.25, DontApplyForce = true }
					)
				end)
			end)

			task.wait(0.1)
		end
	end

	SkillService:SetSkillData(Attacker, "Barrage", nil)
end

function Barrage.Cancel(Attacker: Model) end

function Barrage.Caller(Attacker: Model, Data: { any })
	local StaminaCost = Attacker:GetAttribute("SwordStaminaCost") * 4

	if
		Validate:CanUseSkill(Attacker, StaminaCost)
		and Attacker:GetAttribute("WeaponEquipped")
		and not Attacker:GetAttribute("BarrageDebounce")
	then
		DebounceService:AddDebounce(Attacker, "BarrageDebounce", Debounce, true)

		task.spawn(function()
			Barrage.Charge(Attacker, Data)
		end)

		return true
	end
	return false
end

function Barrage.Start() end

return Barrage
