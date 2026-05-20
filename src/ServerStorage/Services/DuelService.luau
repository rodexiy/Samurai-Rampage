local RunService = game:GetService("RunService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DuelService = Knit.CreateService({
	Name = "DuelService",
	Client = {},
})

local MobService
local AlertService
local MissionBoardService
local AIService
local ArtifactService
local LevelService
local DataService

local MAX_DUEL_MODS = 20

local NameGenerator = require(game.ReplicatedStorage.Shared.Utils.NameGenerator)

local DojosFolder = Instance.new("Folder")
DojosFolder.Name = "Dojos"
DojosFolder.Parent = workspace

local DuelMobFolder = Instance.new("Folder")
DuelMobFolder.Name = "DuelMobs"
DuelMobFolder.Parent = workspace

local Dojos = {}

local TeleportCharacter = require(game.ReplicatedStorage.Shared.Utils.TeleportCharacter)
local Collector = require(game.ReplicatedStorage.Shared.Collector)

function DuelService:CreateConfig(Level: number)
	local Health = math.clamp(100 * math.max(1, (Level / 10) / 2), 100, 400)
	return {
		Lifes = {
			["1"] = {
				Health = Health,
				AttackDistance = 6,
				TargetOffset = 3,
				DetectionDistance = 120,
				MaintainDistance = 120,
				RunDistance = 10,

				MaxDistanceFromSpawn = 100,

				ActionDistance = 11,
				ActionChance = 55,
				DeflectChance = 70,
				RollChance = 30,

				RunSpeed = 15,

				Actions = {
					"Roll",
					"Run",
				},
			},
		},
	}
end

function DuelService:CreateDuelMob(): Model
	local MOB_LEVEL = math.random(1, 7) * 10

	local Mob = MobService:CreateMob("Bandit", "Bandit")
	Mob:SetAttribute("MobLevel", MOB_LEVEL)

	Mob.HumanoidRootPart.Anchored = true

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.ActionText = "Challenge"
	Prompt.HoldDuration = 0
	Prompt.ObjectText = "Bandit"
	Prompt.Style = Enum.ProximityPromptStyle.Custom
	Prompt.Parent = Mob
	Prompt:SetAttribute("callback", "Challenge")
	Prompt.Name = "ChallengePrompt"

	local Billboard = game.ReplicatedStorage.Assets.Billboards.DuelLevel:Clone()
	Billboard.Level.Text = tostring(MOB_LEVEL) .. "+"
	Billboard.Parent = Mob

	local SpawnCFrame = CFrame.new(MissionBoardService:GetRandomPointInDuelSpawn())
		* CFrame.new(0, 3, 0)
		* CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
	Mob:PivotTo(SpawnCFrame)
	Mob.Parent = DuelMobFolder

	return Mob
end

function DuelService:Challenge(Player: Player, Mob: Model)
	local Character = Player.Character
	if not Character then
		return
	end

	local PlayerData = DataService:GetData(Player)

	if PlayerData.Level < Mob:GetAttribute("MobLevel") then
		AlertService:AlertPlayer(
			Player,
			"You need to be level " .. Mob:GetAttribute("MobLevel") .. " or higher to challenge this enemy.",
			"Error"
		)
		return
	end

	local OriginalCFrame = Character:GetPivot()

	if Player:GetAttribute("InCombat") then
		AlertService:AlertPlayer(Player, "Cant challenge while in combat.", "Error")
		return
	end

	if Player:GetAttribute("InDojo") then
		AlertService:AlertPlayer(Player, "You are already in a dojo.", "Error")
		return
	end

	Mob:SetAttribute("DisplayName", NameGenerator:Male(true))

	Mob:AddTag("Boss")

	Player:SetAttribute("InDojo", true)

	local Dojo = game.ServerStorage.ServerAssets.Dojo:Clone()
	table.insert(Dojos, Dojo)
	local Offset = 256 * #Dojos
	Dojo:PivotTo(CFrame.new(5000 + Offset, 1000 + Offset, 1000 + Offset))

	local Connections = Collector.new()
	local Destroyed = false
	local function DestroyAll()
		if Destroyed then
			return
		end
		Destroyed = true
		Connections:Destroy()
		table.remove(Dojos, table.find(Dojos, Dojo))
		Dojo:Destroy()
		Mob:SetAttribute("Died", true)
		Mob:Destroy()
		DuelService:CreateDuelMob()
	end

	Connections:Add(Mob:GetAttributeChangedSignal("Died"):Connect(function()
		if Destroyed then
			return
		end

		Destroyed = true

		Connections:Destroy()
		AlertService:AlertPlayer(Player, "Teleporting back...")

		task.wait(3)

		Player:SetAttribute("InCombat", false)
		Mob:SetAttribute("InCombat", false)
		Player:SetAttribute("InDojo", false)
		LevelService:GiveExp(Player, Mob:GetAttribute("MobLevel") * 150)
		Player:RequestStreamAroundAsync(Dojo.Spawns.Player.Position, 5)

		Character.HumanoidRootPart.Anchored = true
		TeleportCharacter(Character, OriginalCFrame)
		task.delay(2 / 60, function()
			Character.HumanoidRootPart.Anchored = false
		end)

		table.remove(Dojos, table.find(Dojos, Dojo))
		Dojo:Destroy()
		DuelService:CreateDuelMob()
	end))

	Connections:Add(Character:GetAttributeChangedSignal("Died"):Connect(function()
		task.wait(15)
		DestroyAll()
	end))

	Connections:Add(Character:GetPropertyChangedSignal("Parent"):Connect(function()
		if not Character.Parent then
			DestroyAll()
		end
	end))
	Connections:Add(RunService.Heartbeat:Connect(function()
		local DistanceFromDojo = (Character.HumanoidRootPart.Position - Dojo.Spawns.Player.Position).Magnitude

		if DistanceFromDojo > 100 then
			Character:PivotTo(Dojo.Spawns.Player:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
		end
	end))

	Mob.ChallengePrompt:Destroy()
	Mob.DuelLevel:Destroy()
	Character.HumanoidRootPart.Anchored = true
	Mob:PivotTo(Dojo.Spawns.Mob:GetPivot() * CFrame.Angles(0, math.rad(-90), 0))
	task.delay(2 / 60, function()
		Character.HumanoidRootPart.Anchored = false
	end)

	AlertService:AlertPlayer(Player, "Teleporting to Duel.")
	Player:RequestStreamAroundAsync(Dojo.Spawns.Player.Position, 5)
	TeleportCharacter(Character, Dojo.Spawns.Player:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
	Mob.HumanoidRootPart.Anchored = false
	Mob.Parent = workspace.Entity

	AIService:AddAI(Mob, "Bandit", DuelService:CreateConfig(Mob:GetAttribute("MobLevel")))

	Dojo.Parent = DojosFolder
end

function DuelService.KnitInit()
	DataService = Knit.GetService("DataService")
	MobService = Knit.GetService("MobService")
	AlertService = Knit.GetService("AlertService")
	MissionBoardService = Knit.GetService("MissionBoardService")
	AIService = Knit.GetService("AIService")
	ArtifactService = Knit.GetService("ArtifactService")
	LevelService = Knit.GetService("LevelService")
end

function DuelService.KnitStart()
	local DuelSpawns = game.ServerStorage:FindFirstChild("DuelSpawns")
	if DuelSpawns then
		for i = 1, MAX_DUEL_MODS do
			DuelService:CreateDuelMob()
		end
	end

end

return DuelService
