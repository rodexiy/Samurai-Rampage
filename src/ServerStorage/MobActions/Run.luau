local Knit = require(game.ReplicatedStorage.Packages.Knit)



local Character = script.Parent.Parent
local Humanoid = Character:WaitForChild("Humanoid")

local StaminaService = Knit.GetService("StaminaService")
local MovementService = Knit.GetService("MovementService")

local CharacterShared = require(game.ReplicatedStorage.Shared.CharacterShared)

local Validate = require(game.ReplicatedStorage.Shared.Validate)

local function StopRun()
	Character:SetAttribute("Running", false)
	CharacterShared:UpdateBoth(Character)
	MovementService:Run(Character, false)
end

local Run = {}
function Run:Run(state)
	if Character:GetAttribute("Running") then
		return
	end
	if Validate:CanRun(Character) then
		Character:SetAttribute("Running", true)
		MovementService:Run(Character, true)

		CharacterShared:UpdateBoth(Character)

		task.spawn(function()
			while Character:GetAttribute("Running") do
				if not Validate:CanRun(Character) then
					break
				end

				task.wait(0.5)
			end
			StopRun()
		end)
	else
		StopRun()
	end

end



return Run
