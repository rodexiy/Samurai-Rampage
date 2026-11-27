local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local Player = Players.LocalPlayer
local Character = Player.Character

local StaminaService
local MovementService
local DeviceController
local SkillTreeController

local CharacterShared = require(ReplicatedStorage.Shared.CharacterShared)

local Validate = require(ReplicatedStorage.Shared.Validate)

local function StopRun()
	Character:SetAttribute("Running", false)
	CharacterShared:UpdateBoth(Character)
	MovementService:Run(false)
end

local Run = {
	callback = function(inputState: Enum.UserInputState, _InputObject: InputObject?)
		if inputState ~= Enum.UserInputState.Begin and inputState ~= Enum.UserInputState.End then
			return
		end
		local MobileToggle = DeviceController:IsMobile() and (not _InputObject or _InputObject.KeyCode ~= Enum.KeyCode.ButtonL3)

		if inputState == Enum.UserInputState.Begin then
			if Character:GetAttribute("Running") and MobileToggle then
				StopRun()
				return
			end

			if Validate:CanRun(Character) then
				if Character:GetAttribute("Blocking") then
					return
				end

				Character:SetAttribute("Running", true)
				task.spawn(function()
					MovementService:Run(true)
				end)

				CharacterShared:UpdateBoth(Character)

				task.spawn(function()
					while Character:GetAttribute("Running") do
						if not Validate:CanRun(Character) then
							Character:SetAttribute("Running", false)
							break
						end

						CharacterShared:UpdateBoth(Character)

						task.wait()
					end
					StopRun()
				end)

				local HasSkill = SkillTreeController:IsSkillUnlocked("No Run Stamina Drain")
				while Character:GetAttribute("Running") do
					local dt = task.wait(0.5)

					if not HasSkill or Character:GetAttribute("InCombat") then
						StaminaService:RemoveStamina(1.25 * dt * 2.25)
					end
				end
			else
				StopRun()
			end
		elseif Character:GetAttribute("Running") then
			if MobileToggle then
				return
			end
			StopRun()
		end
	end,

	keys = { Enum.KeyCode.LeftShift },
}

function Run.Start(_Services: any)
	StaminaService = Knit.GetService("StaminaService")
	MovementService = Knit.GetService("MovementService")
	DeviceController = Knit.GetController("DeviceController")
	SkillTreeController = Knit.GetController("SkillTreeController")

	local StopAttributes = {
		"EgoActive",
		"Attack",
		"UsingSkillCantAttack",
		"BeenHitted",
		"Meditating",
		"RealmEditing",
	}

	for _, att in StopAttributes do
		Character:GetAttributeChangedSignal(att):Connect(function()
			if Character:GetAttribute(att) then
				StopRun()
			end
		end)
	end

	DeviceController:BindAction("Run", Run.callback, "Run", UDim2.fromScale(0.775, 0.9))
end

return Run
