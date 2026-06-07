local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Player = game.Players.LocalPlayer
local Character = Player.Character

local WeaponService
local Validate = require(game.ReplicatedStorage.Shared.Validate)

local Camera = workspace.CurrentCamera
local CharacterShared = require(game.ReplicatedStorage.Shared.CharacterShared)

local AnimationController
local RenderController
local SoundEffectController
local DeviceController

local EquipWeapon = {
	callback = function(inputState)
		local CombatAnimations = AnimationController:GetCombatAnimationFolder(Character)
		if Character:GetAttribute("Meditating") then
			return
		end

		if inputState == Enum.UserInputState.Begin then
			if not Character:GetAttribute("WeaponEquipped") then
				if not Validate:CanEquipWeapon(Character) then
					return
				end

				Character:SetAttribute("Equipping", true)
				AnimationController:PlayAnimation(Character, CombatAnimations.EquipHold)
				SoundEffectController:PlaySoundEffect("EquipHold", true, Character.PrimaryPart)
			end
		end

		if inputState == Enum.UserInputState.End then
			if not Character:GetAttribute("WeaponEquipped") then
				if
					not AnimationController:GetAnimationFind(Character, "EquipHold")
					or Character:GetAttribute("Unequipping")
				then
					Character:SetAttribute("Equipping", false)
					return
				end
				AnimationController:StopAnimationFind(Character, "EquipHold")
				AnimationController:PlayAnimation(Character, CombatAnimations.EquipDraw)

				WeaponService:Equip(true)
				Character:SetAttribute("Equipping", false)
			else
				if
					Character:GetAttribute("Unequipping")
					or Character:GetAttribute("Equipping")
					or Character:GetAttribute("ClientAttacking")
					or Character:GetAttribute("ClientStrongAttack")
					or Character:GetAttribute("EquipDebounce")
					or Character:GetAttribute("Attacking")
				then
					return
				end

				--Character:SetAttribute("Running", false)
				Character:SetAttribute("Unequipping", true)

				CharacterShared:UpdateBoth(Character)
				Character:SetAttribute("AnimationPreset", "Default")

				local DelayDuration = 1.4
				
				if Character:GetAttribute("InCombat") then
					DelayDuration = 1
				end
				task.delay(DelayDuration, function()
					CharacterShared:UpdateBoth(Character)
				end)

				task.delay(DelayDuration + 0.2, function()
					Character:SetAttribute("Unequipping", false)
				end)

				WeaponService:Equip(false)
			end
			return
		end
	end,

	keys = { Enum.KeyCode.E },
}

function EquipWeapon.Start()
	WeaponService = Knit.GetService("WeaponService")
	AnimationController = Knit.GetController("AnimationController")
	RenderController = Knit.GetController("RenderController")
	SoundEffectController = Knit.GetController("SoundEffectController")
	DeviceController = Knit.GetController("DeviceController")

	DeviceController:BindAction("EquipWeapon", EquipWeapon.callback, "Equip", UDim2.fromScale(0.8, 0.2))

	Character:GetAttributeChangedSignal("CallUnequipWeaponClient"):Connect(function()
		if
			(Character:GetAttribute("WeaponEquipped") or Character:GetAttribute("Equipping"))
			and Character:GetAttribute("CallUnequipWeaponClient")
		then
			Character:SetAttribute("Equipping", false)
			Character:SetAttribute("EquipDebounce", false)

			EquipWeapon.callback(Enum.UserInputState.End)
		end
	end)
end

return EquipWeapon
