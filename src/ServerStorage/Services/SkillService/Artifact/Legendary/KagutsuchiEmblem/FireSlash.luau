local FireSlash = {}

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

local Collector = require(game.ReplicatedStorage.Shared.Collector)

local Cooldown = 10
function FireSlash.Charge(Attacker: Model, Data: { any })
	DebounceService:AddDebounce(Attacker, "FireSlashDebounce", Cooldown, true)
	SkillService:SetSkillData(Attacker, "FireSlash", "Charge")
	AnimationService:PlayAnimation(Attacker, "FireSlashSlice")

	StaminaService:RemoveStamina(Attacker, 15)

	DebounceService:AddDebounce(Attacker, "Attack", 0.45)

	RenderService:RenderForAllPlayers("Combat", "Kanji", { Character = Attacker })

	task.wait(0.45)
	FireSlash.Release(Attacker, Data)
end
function FireSlash.Release(Attacker: Model, Data: { any })
	if SkillService:GetSkillState(Attacker, "FireSlash") ~= "Charge" then
		return
	end

	local RootCFrame = Data.RootCFrame or Attacker:GetPivot()
	RenderService:RenderForAllPlayers("FireSlash", "Release", { Character = Attacker, RootCFrame = RootCFrame })

	local Duration = 1.25
	local i = 0

	local Hitted = {}
	while i < Duration do
		local dt = task.wait()
		RootCFrame = RootCFrame * CFrame.new(0, 0, -40 * dt)

		HitboxService:CreatePartHitbox(Attacker, {
			Size = Vector3.new(4, 8, 8),
			Frames = 1,
			CFrame = RootCFrame,
			DontWeld = true,
			Hitted = Hitted,
		}, function(Enemy: Model)
			task.delay(LagCompensationService:GetCompensation(Enemy), function()
				task.defer(function()
					local Damage = DamageService:CalculateDamage(Attacker, Enemy, 15, { "Artifact" })
					local Context = HitService:NormalHit(Enemy, Attacker, Damage, { By = "Weapon", Ranged = true })

					if Context == "Hit" then
						BuffService:AddBuff(Enemy, "Burn", "Burn", 2, 3, "int")
					end
				end)
			end)
		end)
		i += dt
	end

	SkillService:SetSkillData(Attacker, "FireSlash", nil)
end

function FireSlash.Cancel(Attacker: Model)
	AnimationService:StopAnimationFind(Attacker, "FireSlashSlice")
end

function FireSlash.Caller(Attacker: Model, Data: { any })
	if
		Validate:CanUseSkill(Attacker, 5)
		and Attacker:GetAttribute("WeaponEquipped")
		and (Attacker.Name == "Yamarashi" or not DebounceService:HaveDebounce(Attacker, "FireSlashDebounce"))
	then
		FireSlash.Charge(Attacker, Data)
		return true
	end
end

function FireSlash.Start() end

return FireSlash
