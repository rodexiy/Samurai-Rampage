local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)
local Yamarashi = require(ServerStorage.Services.Services.AIService.Configs.Yamarashi)

local Config = DeepCopy(Yamarashi)

for _, Life in Config.Lifes do
	Life.SkillChance = 0
	Life.Skills = nil
end

-- The Yamarashi runner handles BladeIgnition independently of the attack skills.
return Config
