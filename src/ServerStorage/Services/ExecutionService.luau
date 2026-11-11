local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ExecutionService = Knit.CreateService({
	Name = "ExecutionService",
	Client = {},
})

ExecutionService.Executed = Instance.new("BindableEvent")

local HitboxService
local RenderService
local QuestService
local SkillTreeService
local KillStreakService

function ExecutionService:Execute(Attacker: Model, Character: Model, Ranged: boolean?): boolean
	if Attacker == Character or not Attacker.Parent or not Character.Parent
		or (Attacker:GetAttribute("IsAI") and Character:GetAttribute("IsAI"))
		or Character:GetAttribute("Died") or not Character:GetAttribute("Downed") then
		return false
	end

	-- Ranged hits have already rendered blood through HitService.
	if not Ranged then
		RenderService:RenderForAllPlayers("Combat", "Blood", { Character = Character, Attacker = Attacker })
	end
	Character:SetAttribute("Died", true)
	self.Executed:Fire(Attacker, Character)

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
	if Player and not Character:GetAttribute("NoRewards") and not Character:GetAttribute("WisdomWorldMob") then
		KillStreakService:HandlePlayerKill(Attacker, Character)
		QuestService:CallQuestFunction(Player, "Kill", Character)
	end

	return true
end

function ExecutionService:ExecuteInRange(Attacker: Model)
	local Root = Attacker.PrimaryPart
	if not Root then
		return
	end

	local Characters = HitboxService:GetCharactersInBoxArea(
		Root.CFrame * CFrame.new(0, 0, -2.5),
		Vector3.new(5, 7, 5)
	)
	for _, Character in Characters do
		self:Execute(Attacker, Character)
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
