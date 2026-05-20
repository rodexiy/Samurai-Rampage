local Knit = require(game.ReplicatedStorage.Packages.Knit)

local BossSpawnService = Knit.CreateService({
	Name = "BossSpawnService",
	Client = {},
})

local MobService
local AIService

local IsDev = game.GameId == 9047199245

local Bosses = {
	{
		Name = "Hanzo",
		Runner = "Bandit",
		Config = "Hanzo",

		SpawnTime = { 0 },
		SpawnLocation = CFrame.new(-125.963, 90.951, 196.373) * CFrame.Angles(0, math.rad(90), 0),
	},

	{
		Name = "Yamarashi",
		Runner = "Yamarashi",
		Config = "Yamarashi",

		SpawnTime = { 10 },
		SpawnLocation = CFrame.new(-2004.175, 30.801, -926.825) * CFrame.Angles(0, math.rad(180), 0),
	},
}

function BossSpawnService:SpawnBoss(Data: { any })
	if IsDev then
		Data.SpawnLocation = Data.SpawnLocation * CFrame.new(0, -Data.SpawnLocation.Y + 10, 0)
	end
	local Boss = MobService:SpawnMob(Data.Name, Data.SpawnLocation, Data.Name)
	AIService:AddAI(Boss, Data.Runner, Data.Config)

	if not Boss then
		return
	end

	Boss:GetAttributeChangedSignal("Died"):Connect(function()
		task.wait(math.random(Data.SpawnTime[1], Data.SpawnTime[2] or Data.SpawnTime[1]))
		BossSpawnService:SpawnBoss(Data)
	end)
end

function BossSpawnService:BindBossSpawn()
	for _, Boss in Bosses do
		task.spawn(function()
			local SpawnTime = math.random(Boss.SpawnTime[1], Boss.SpawnTime[2] or Boss.SpawnTime[1])
			task.wait(SpawnTime)
			BossSpawnService:SpawnBoss(Boss)
		end)
	end
end

function BossSpawnService.KnitInit()
	MobService = Knit.GetService("MobService")
	AIService = Knit.GetService("AIService")
end

function BossSpawnService.KnitStart()
	BossSpawnService:BindBossSpawn()
end

return BossSpawnService
