local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BowConfig = require(ReplicatedStorage.Shared.BowConfig)
local TanegashimaConfig = require(ReplicatedStorage.Shared.TanegashimaConfig)

local RangedWeaponConfig = {}

function RangedWeaponConfig.Get(ItemName: string?): any
	return if ItemName == "Tanegashima" then TanegashimaConfig else BowConfig
end

function RangedWeaponConfig.GetForCharacter(Character: Model?): any
	return RangedWeaponConfig.Get(if Character then Character:GetAttribute("Bow") else nil)
end

function RangedWeaponConfig.CanFocus(Character: Model, Active: boolean?): boolean
	local Config = RangedWeaponConfig.GetForCharacter(Character)
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	local Root = Character.PrimaryPart
	local MaxSpeed = if Active then Config.FocusExitMoveSpeed else Config.FocusMaxMoveSpeed

	return Humanoid ~= nil and Root ~= nil and not Humanoid.Sit
		and Humanoid.FloorMaterial ~= Enum.Material.Air
		and Humanoid.MoveDirection.Magnitude < Config.FocusMoveInputDeadzone
		and Root:GetVelocityAtPosition(Root.Position).Magnitude <= MaxSpeed
		and not Character:GetAttribute("Running") and Config.CanUse(Character)
end

function RangedWeaponConfig.GetModel(ItemName: string): Model?
	if ItemName == "Tanegashima" then
		return ReplicatedStorage.Assets.Models:FindFirstChild("Tanegashima") :: Model?
	end

	return ReplicatedStorage.Assets.Models.Bow.Bow
end

function RangedWeaponConfig.GetAmmoCount(Config: any, Counts: { [string]: number }): number
	local Count = math.huge
	for ItemName, Amount in Config.Ammunition do
		Count = math.min(Count, math.floor((Counts[ItemName] or 0) / Amount))
	end

	return if Count == math.huge then 0 else Count
end

return RangedWeaponConfig
