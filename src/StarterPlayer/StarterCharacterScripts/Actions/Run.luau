local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Player = game.Players.LocalPlayer
local Character = Player.Character
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local StaminaService
local MovementService
local DeviceController
local SkillTreeController

local CharacterShared = require(game.ReplicatedStorage.Shared.CharacterShared)

local Validate = require(game.ReplicatedStorage.Shared.Validate)

local function StopRun()
	Character:SetAttribute("Running", false)
	CharacterShared:UpdateBoth(Character)
	MovementService:Run(false)
end

local Run = {
	callback = function(inputState, inputObject)
		if inputState ~= Enum.UserInputState.Begin and inputState ~= Enum.UserInputState.End then
			return
		end

		if inputState == Enum.UserInputState.Begin then
			if Character:GetAttribute("Running") and DeviceController:IsMobile() then
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
			if DeviceController:IsMobile() then
				return
			end
			StopRun()
		end
	end,

	keys = { Enum.KeyCode.LeftShift },
}

function Run.Start(srvs)
	StaminaService = Knit.GetService("StaminaService")
	MovementService = Knit.GetService("MovementService")
	DeviceController = Knit.GetController("DeviceController")
	SkillTreeController = Knit.GetController("SkillTreeController")

	local StopAttributes = {
		"Attack",
		"UsingSkillCantAttack",
		"BeenHitted",
		"Meditating",
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
