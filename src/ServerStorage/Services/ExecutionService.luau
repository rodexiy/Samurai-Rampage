local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ExecutionService = Knit.CreateService({
	Name = "ExecutionService",
	Client = {},
})
local HitboxService
local RenderService
local QuestService
local SkillTreeService
local KillStreakService

function ExecutionService:ExecuteInRange(Attacker: Model)
	local Characters = HitboxService:GetCharactersInBoxArea(
		Attacker.HumanoidRootPart.CFrame * CFrame.new(0, 0, -2.5),
		Vector3.new(5, 7, 5)
	)

	for _, Character in Characters do
		if Attacker == Character then
			continue
		end
		if Attacker:GetAttribute("IsAI") and Character:GetAttribute("IsAI") then
			continue
		end
		if Character:GetAttribute("Died") or not Character:GetAttribute("Downed") then
			continue
		end

		RenderService:RenderForAllPlayers("Combat", "Blood", { Character = Character, Attacker = Attacker })
		Character:SetAttribute("Died", true)

		if SkillTreeService:IsSkillUnlocked(Character, "Health Recovery") then
			Attacker:SetAttribute(
				"Health",
				math.clamp(
					Attacker:GetAttribute("Health") + (Attacker:GetAttribute("MaxHealth") * 0.25),
					0,
					Attacker:GetAttribute("MaxHealth")
				)
			)
		elseif SkillTreeService:IsSkillUnlocked(Character, "Oni Health Recovery") then
			Attacker:SetAttribute(
				"Health",
				math.clamp(
					Attacker:GetAttribute("Health") + (Attacker:GetAttribute("MaxHealth") * 0.55),
					0,
					Attacker:GetAttribute("MaxHealth")
				)
			)
		end

		if not Character:GetAttribute("IsAI") then
			Attacker:SetAttribute("Stamina", Attacker:GetAttribute("MaxStamina"))
		end

		local Player = Players:GetPlayerFromCharacter(Attacker)
		if Player then
			if Character:GetAttribute("NoRewards") or Character:GetAttribute("WisdomWorldMob") then
				continue
			end

			KillStreakService:HandlePlayerKill(Attacker, Character)
			QuestService:CallQuestFunction(Player, "Kill", Character)
		end
	end
end

function ExecutionService.KnitInit()
	HitboxService = Knit.GetService("HitboxService")
	RenderService = Knit.GetService("RenderService")
	QuestService = Knit.GetService("QuestService")
	SkillTreeService = Knit.GetService("SkillTreeService")
	KillStreakService = Knit.GetService("KillStreakService")
end

function ExecutionService.KnitStart() end

return ExecutionService
