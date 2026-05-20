local Kurohitsugi = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DebounceService = Knit.GetService("DebounceService")
local StaminaService = Knit.GetService("StaminaService")
local SkillService = Knit.GetService("SkillService")
local AnimationService = Knit.GetService("AnimationService")
local RenderService = Knit.GetService("RenderService")
local HitboxService = Knit.GetService("HitboxService")
local HitService = Knit.GetService("HitService")
local LagCompensationService = Knit.GetService("LagCompensationService")

local Validate = require(game.ReplicatedStorage.Shared.Validate)
local SetAutoRotate = require(game.ReplicatedStorage.Shared.Utils.SetAutoRotate)

local Debounce = 200

local Assets = game.ReplicatedStorage.Assets.VFX.Skills.DevSpec.Kurohitsugi

function Kurohitsugi.Charge(Attacker: Model, Data: { any })
	Kurohitsugi.Release(Attacker, Data)
end

function Kurohitsugi.Release(Attacker: Model, Data: { any })
	local RootPart = Attacker:FindFirstChild("HumanoidRootPart")
	DebounceService:AddDebounce(Attacker, "Attack", 10)

	RenderService:RenderForAllPlayers("Kurohitsugi", "Release", { Character = Attacker })

	SetAutoRotate(Attacker, false)
	RootPart.Anchored = true

	task.wait(3.5)

	RenderService:RenderForAllPlayers("Kurohitsugi", "Hit", { Character = Attacker })

	HitboxService:CreatePartHitbox(Attacker, {
		Size = Vector3.new(308.608, 577.841, 319.292),
		Frames = 10,
		CFrame = RootPart:GetPivot() * CFrame.new(0, 250, 0),
		DontWeld = true,
	}, function(Enemy: Model)
		DebounceService:AddDebounce(Enemy, "SkillLockMovement", 6)
		SetAutoRotate(Enemy, false)

		RenderService:RenderForAllPlayers("Kurohitsugi", "Hit", { Character = Enemy })
	end)

	task.wait(4.5)

	HitboxService:CreatePartHitbox(Attacker, {
		Size = Vector3.new(308.608, 577.841, 319.292),
		Frames = 10,
		CFrame = RootPart:GetPivot() * CFrame.new(0, 250, 0),
		DontWeld = true,
	}, function(Enemy: Model)
		HitService:Hit(Enemy, Attacker, 10000, { By = "Skill" })
	end)

	task.wait(1.32)

	RootPart.Anchored = false
	SetAutoRotate(Attacker, true)
end

function Kurohitsugi.Cancel(Attacker: Model) end

function Kurohitsugi.Caller(Attacker: Model, Data: { any })
	if Validate:CanUseSkill(Attacker, 0) and not Attacker:GetAttribute("KurohitsugiDebounce") then
		DebounceService:AddDebounce(Attacker, "KurohitsugiDebounce", Debounce, true)

		task.spawn(function()
			Kurohitsugi.Charge(Attacker, Data)
		end)

		return true
	end
	return false
end

function Kurohitsugi.Start() end

return Kurohitsugi
