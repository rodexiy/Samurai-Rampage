local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BowConfig = require(ReplicatedStorage.Shared.BowConfig)
local CrouchConfig = require(ReplicatedStorage.Shared.CrouchConfig)

local Shared = {}

local NO_WEAPON_SPEED_MULTIPLIER = 1.2

local function HasInventoryWeaponEquipped(Character: Model): boolean
	return Character:GetAttribute("Weapon") ~= nil or Character:GetAttribute("LeftWeapon") ~= nil
end

local function ApplyNoWeaponSpeedBonus(Character: Model, walkspeed: number): number
	if not Players:GetPlayerFromCharacter(Character) then
		return walkspeed
	end

	if HasInventoryWeaponEquipped(Character) then
		return walkspeed
	end

	return walkspeed * NO_WEAPON_SPEED_MULTIPLIER
end

function Shared:ChangeWalkSpeed(Character: Model, amount: number?, overwrite: string?)
	local humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end
	local function SetWalkSpeed(Speed: number)
		if Character:GetAttribute("BowDrawing") then
			Speed = math.min(Speed, BowConfig.DrawWalkSpeed)
		end
		if Character:GetAttribute("Crouching") then
			Speed = math.min(Speed, CrouchConfig.WalkSpeed)
		end

		if Character:GetAttribute("IsAI") then
			humanoid.WalkSpeed = Speed
		else
			Character:SetAttribute("TargetWalkSpeed", Speed)
		end
	end

	local function change(toChange: string, walkspeed: number)
		SetWalkSpeed(if toChange == overwrite and amount then amount else walkspeed)
	end

	local Walkspeeds = {
		Meditating = function()
			change("Meditating", 0)
		end,

		HeavyDeflect = function()
			change("HeavyDeflect", 0)
		end,

		PostureBreak = function()
			change("PostureBreak", 0)
		end,

		SkillLockMovement = function()
			change("SkillLockMovement", 0)
		end,

		BeenHitted = function()
			change("BeenHitted", 4)
		end,

		Attack = function()
			change("Attack", 6)
		end,

		Attacking = function()
			change("Attacking", 6)
		end,

		Blocking = function()
			change("Blocking", 8)
		end,

		BeenDeflected = function()
			change("BeenDeflected", 8)
		end,

		Running = function()
			change(
				"Running",
				ApplyNoWeaponSpeedBonus(
					Character,
					(Character:GetAttribute("RunningWalkSpeed") or 24)
						* (Character:GetAttribute("RunSpeedMultiplier") or 1)
						+ (Character:GetAttribute("RunSpeedIncrease") or 0)
				)
			)
		end,

		Default = function()
			local target = amount or Character:GetAttribute("DefaultWalkSpeed") or humanoid.WalkSpeed
			target = ApplyNoWeaponSpeedBonus(Character, target)
			SetWalkSpeed(target)
		end,
	}

	local set = false
	for attributeName, func in pairs(Walkspeeds) do
		if not Character:GetAttribute(attributeName) == true then
			continue
		end
		set = true
		func()
		break
	end

	if not set then
		Walkspeeds.Default()
	end
end
function Shared:UpdateWalkspeed(Character: Model)
	Shared:ChangeWalkSpeed(Character)
end

function Shared:ChangeJumpPower(Character: Model, amount: number?, overwrite: string?)
	local humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end
	if Character:GetAttribute("BowDrawing") or Character:GetAttribute("Crouching") then
		humanoid.Jump = false
		humanoid.JumpPower = 0
		return
	end

	amount = amount or Character:GetAttribute("DefaultJumpPower")

	local function change(toChange, walkspeed)
		if toChange == overwrite then
			humanoid.JumpPower = amount
		else
			humanoid.JumpPower = walkspeed
		end
	end

	local JumpPowers = {
		PostureBreak = function()
			change("PostureBreak", 0)
		end,

		HeavyDeflect = function()
			change("HeavyDeflect", 0)
		end,

		SkillLockMovement = function()
			change("SkillLockMovement", 0)
		end,

		BeenHitted = function()
			change("BeenHitted", 0)
		end,

		Attack = function()
			change("Attack", 0)
		end,

		Attacking = function()
			change("Attacking", 0)
		end,

		Blocking = function()
			change("Blocking", 0)
		end,

		BeenDeflected = function()
			change("BeenDeflected", 0)
		end,

		JumpDebounce = function()
			change("JumpDebounce", 0)
		end,

		Default = function()
			humanoid.JumpPower = amount or Character:GetAttribute("DefaultJumpPower") or 30
		end,
	}

	local set = false
	for attributeName, func in pairs(JumpPowers) do
		if not Character:GetAttribute(attributeName) == true then
			continue
		end
		set = true
		func()
		break
	end

	if not set then
		JumpPowers.Default()
	end
end
function Shared:UpdateJumpPower(Character: Model)
	Shared:ChangeJumpPower(Character)
end

function Shared:UpdateBoth(Character: Model)
	task.spawn(function()
		Shared:UpdateJumpPower(Character)
		Shared:UpdateWalkspeed(Character)
	end)
end

return Shared
