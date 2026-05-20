local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RandomMobEventService = Knit.CreateService({
	Name = "RandomMobEventService",
	Client = {},
})

local MobService
local AIService

local MaxEvents = 6

local Events = {}

local BanditSpawns = workspace:FindFirstChild("BanditSpawns")
function RandomMobEventService:GetRandomPointToSpawn()
	local Point = BanditSpawns:GetChildren()[math.random(1, #BanditSpawns:GetChildren())]
	local Size = Point.Size
	local Offset = Vector3.new(math.random(-Size.X / 2, Size.X / 2), 0, math.random(-Size.Z / 2, Size.Z / 2))
	return Point.Position + Offset
end

function RandomMobEventService:Spawn()
	if #Events >= MaxEvents then
		return
	end

	local Event = {
		Mobs = {},
	}

	local Point = RandomMobEventService:GetRandomPointToSpawn()
	for _ = 1, math.random(1, 3) do
		local BanditOffset = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
		local Bandit: Model = MobService:SpawnMob(
			"Bandit",
			CFrame.new(Point + BanditOffset) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0),
			"Bandit"
		)

		AIService:AddAI(Bandit, "Bandit", "Bandit")

		Bandit:GetPropertyChangedSignal("Parent"):Connect(function()
			if Bandit.Parent == nil then
				table.remove(Event.Mobs, _)
			end
		end)

		Bandit:GetAttributeChangedSignal("Attack"):Connect(function()
			Event.LastActive = tick()
		end)
		table.insert(Event.Mobs, Bandit)
	end

	Event.LastActive = tick()
	table.insert(Events, Event)
end

function RandomMobEventService.KnitInit()
	AIService = Knit.GetService("AIService")
	MobService = Knit.GetService("MobService")
end

function RandomMobEventService.KnitStart()
	-- if not BanditSpawns then
	-- 	return
	-- end

	-- for _ = 1, MaxEvents do
	-- 	RandomMobEventService:Spawn()
	-- end

	-- while true do
	-- 	for _, Event in Events do
	-- 		if tick() - Event.LastActive > 300 then
	-- 			for _, Mob in Event.Mobs do
	-- 				Mob:Destroy()
	-- 				table.remove(Event.Mobs, _)
	-- 			end
	-- 			table.remove(Events, _)
	-- 		end

	-- 		if #Event.Mobs == 0 then
	-- 			table.remove(Events, _)

	-- 			task.delay(math.random(10, 20), function()
	-- 				RandomMobEventService:Spawn()
	-- 			end)
	-- 		end
	-- 	end

	-- 	task.wait(1)
	-- end
end

return RandomMobEventService
