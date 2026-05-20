local Knit = require(game.ReplicatedStorage.Packages.Knit)
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local DungeonService = Knit.CreateService({
	Name = "DungeonService",
})

local Terrain: Terrain = workspace:WaitForChild("Terrain")

local DungeonFolder = Instance.new("Folder")
DungeonFolder.Name = "Dungeon"
DungeonFolder.Parent = Workspace

local RewardService
local MobService
local AIService

local DungeonAssets = ServerStorage.ServerAssets.Dungeons

type DungeonConfig = {
	Name: string,
	Type: "Linear" | "Random",
	MaxSafeRooms: number,
	SafeRooms: number,
	RoomAmount: number,
	Rooms: { any },
	Enemies: { any },
}

function DungeonService:GetRoom(DungeonConfig: DungeonConfig, Name: string)
	local AllRooms = DungeonAssets[DungeonConfig.Name]
	return AllRooms:FindFirstChild(Name) or AllRooms.Rooms:FindFirstChild(Name)
end

function DungeonService:GetRandomRoom(DungeonConfig: DungeonConfig)
	local AllRooms = DungeonAssets[DungeonConfig.Name].Rooms:GetChildren()
	local Room = AllRooms[math.random(1, #AllRooms)]

	if Room:GetAttribute("SafeRoom") and DungeonConfig.SafeRooms >= DungeonConfig.MaxSafeRooms then
		return self:GetRandomRoom(DungeonConfig)
	end

	return Room:Clone()
end

function DungeonService:GetRandomDoor(Room: Model)
	local Doors = Room.Doors:GetChildren()

	local Filtered = {}
	for _, Door in Doors do
		if Door.Name:find("ShouldDestroy") then
			continue
		end

		table.insert(Filtered, Door)
	end
	table.clear(Doors)
	if #Filtered > 0 then
		return Filtered[math.random(1, #Filtered)]
	end

	return false
end

function DungeonService:CanPlace(AnchorDoor: BasePart, Room: Model)
	local LimitsFolder = Room:FindFirstChild("Limits")
	if not LimitsFolder then
		return DungeonService:CanPlaceBoundingBox(AnchorDoor, Room)
	end

	local Params = OverlapParams.new()
	Params.FilterDescendantsInstances = { AnchorDoor.Parent, Room }
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.CollisionGroup = "LIMITS"

	for i, v: BasePart in LimitsFolder:GetChildren() do
		local c, s = v.CFrame, v.Size
		local Parts = workspace:GetPartBoundsInBox(c, s, Params)

		if #Parts > 1 then
			for _, k in Parts do
				if k.Parent.Name == "Limits" or k.Name == "LIMIT" then
					return false
				end
			end
		end
	end

	return true
end

function DungeonService:CanPlaceBoundingBox(AnchorDoor, Room)
	local Params = OverlapParams.new()
	Params.FilterDescendantsInstances = { AnchorDoor.Parent, Room }
	Params.FilterType = Enum.RaycastFilterType.Exclude

	local _cframe, _size = Room:GetBoundingBox()
	local size = _size - Vector3.new(2, 2, 2)
	local size = Vector3.new(math.round(size.X), math.round(size.Y), math.round(size.Z))
	local Hitbox = game.Workspace:GetPartBoundsInBox(_cframe, size, Params)

	return #Hitbox == 0
end

function DungeonService:PlaceStartRoom(DungeonConfig: DungeonConfig)
	local StartRoom = DungeonAssets[DungeonConfig.Name].Start:Clone()

	DungeonConfig.Start = StartRoom
	StartRoom:PivotTo(DungeonConfig.CFrame)
	StartRoom.Parent = DungeonFolder
	DungeonService:CheckForWater(StartRoom)
end

function DungeonService:CheckForWater(Room: Model)
	for _, Water in Room:GetChildren() do
		if Water.Name == "WATER" then
			Terrain:FillBlock(
				Water.CFrame * CFrame.new(0, 0.5, 0),
				Water.Size + Vector3.new(8, 0, 8),
				Enum.Material.Water
			)
		end
	end
end

local function PlaceRoom(DungeonConfig, _LastRoom, Room)
	LastRoom = _LastRoom or LastRoom
	local Tries = #Room.Doors:GetChildren()

	if DungeonConfig.AmountOfRooms >= DungeonConfig.RoomAmount then
		return false
	end

	local Placed = false

	for i = 1, Tries do
		if Placed then
			break
		end

		for _, AnchorDoor in LastRoom.Doors:GetChildren() do
			local RoomDoor = DungeonService:GetRandomDoor(Room)

			local RoomIndex

			if DungeonConfig.Type == "Linear" then
				RoomIndex = if LastRoom.Name == "Start" then 1 else tonumber(LastRoom.Name) + 1
			else
				RoomIndex = #DungeonConfig.Rooms + 1
			end

			Room.Name = RoomIndex
			Room.PrimaryPart = RoomDoor
			Room:PivotTo(AnchorDoor:GetPivot() * CFrame.Angles(0, math.rad(180), 0))

			if DungeonService:CanPlace(AnchorDoor, Room) then
				Placed = true
				Room.Parent = DungeonFolder

				if Room:GetAttribute("SafeRoom") then
					DungeonConfig.SafeRooms += 1
				end

				table.insert(DungeonConfig.Rooms, Room)
				DungeonService:CheckForWater(Room)
				LastRoom = Room

				if DungeonConfig.Progress == "Complete" or RoomIndex == 1 then
					RoomDoor.Parent.Parent.DoorPlates:FindFirstChild(tostring(RoomDoor.Name)):Destroy()
					pcall(function()
						AnchorDoor.Parent.Parent.DoorPlates:FindFirstChild(tostring(AnchorDoor.Name)):Destroy()
						AnchorDoor:Destroy()
					end)
					RoomDoor:Destroy()
				else
					RoomDoor.Parent.Parent.DoorPlates:WaitForChild(tostring(RoomDoor.Name)).Name = "ShouldDestroy"
						.. Room.Name
					AnchorDoor.Parent.Parent.DoorPlates:WaitForChild(tostring(AnchorDoor.Name)).Name = "ShouldDestroy"
						.. Room.Name
					RoomDoor.Name = "ShouldDestroy" .. Room.Name
					AnchorDoor.Name = "ShouldDestroy" .. Room.Name
				end

				break
			end
		end
	end

	if not Placed and DungeonConfig.Backtrack then
		if LastRoom.Name == "Start" or tonumber(LastRoom.Name) == 1 then
			Room:Destroy()
			return false
		end

		task.wait()
		DungeonConfig.AmountOfRooms += 1
		return PlaceRoom(DungeonConfig, DungeonFolder:FindFirstChild(tonumber(LastRoom.Name) - 1), Room)
	elseif not Placed then
		Room:Destroy()
		return false
	end

	return true, Room
end

function DungeonService:GenerateRandomDungeon(DungeonConfig: DungeonConfig, LastRoom: Model)
	local LastRoom = LastRoom or DungeonConfig.Start

	for _, Door in LastRoom.Doors:GetChildren() do
		local Room = self:GetRandomRoom(DungeonConfig)
		local Placed = PlaceRoom(DungeonConfig, LastRoom, Room)

		if Placed then
			task.spawn(function()
				DungeonService:GenerateRandomDungeon(DungeonConfig, Room)
			end)
		end
	end
end

function DungeonService:GenerateLinearDungeon(DungeonConfig: DungeonConfig)
	local LastRoom = DungeonConfig.Start
	for RoomIndex = 1, DungeonConfig.RoomAmount do
		local Room = self:GetRandomRoom(DungeonConfig)

		local Placed = PlaceRoom(DungeonConfig, LastRoom, Room)
		if Placed then
			LastRoom = Room
		end
	end
end

function DungeonService:BossRoom(DungeonConfig: DungeonConfig)
	local LastRoom = DungeonConfig.Rooms[#DungeonConfig.Rooms]

	local BossRoom = self:GetRoom(DungeonConfig, "Boss")
	local Placed, Room = PlaceRoom(DungeonConfig, LastRoom, BossRoom)
	DungeonConfig.BossRoom = Room

	DungeonService:SpawnBoss(DungeonConfig)
end

function DungeonService:SpawnBoss(DungeonConfig)
	local Model = DungeonConfig.Boss.Model
	local Runner = DungeonConfig.Boss.Runner
	local Config = DungeonConfig.Boss.Config

	local BossCFrame = DungeonConfig.BossRoom.EnemySpawn:GetChildren()[1].CFrame
	local Mob = MobService:SpawnMob(Model, BossCFrame, Model)
	AIService:AddAI(Mob, Runner, Config)
end

function DungeonService:EnemyConfig(DungeonConfig: DungeonConfig)
	local AllRooms = DungeonConfig.Rooms

	for _, Room in AllRooms do
		local RoomEnemies = Room:FindFirstChild("EnemySpawn")

		for _, Door in Room.Doors:GetChildren() do
			if Door.Name == "ShouldDestroy" .. Room.Name then
				Door:Destroy()
			end
		end

		for _, Door in Room.DoorPlates:GetChildren() do
			if Door.Name == "ShouldDestroy" .. Room.Name then
				Door:Destroy()
			end
		end

		if RoomEnemies then
			local Enemies = {}

			local DeadWieldEvent = Instance.new("BindableEvent")
			DeadWieldEvent.Name = "DeadWieldEvent"
			local PossibleEnemies = require(RoomEnemies.ModuleScript)

			for _, EnemyPoint in RoomEnemies:GetChildren() do
				if EnemyPoint:IsA("ModuleScript") then
					continue
				end
				local Enemy = RewardService:GetRandomRewardFromWeight(PossibleEnemies)
				if Enemy == "None" then
					continue
				end

				local Mob = MobService:SpawnMob(
					Enemy,
					EnemyPoint:GetPivot() * CFrame.Angles(0, math.rad(math.random(0, 360)), 0),
					Enemy
				)
				AIService:AddAI(Mob, Enemy, Enemy)

				table.insert(Enemies, Mob)

				Mob:GetPropertyChangedSignal("Parent"):Connect(function()
					if Mob.Parent == nil then
						table.remove(Enemies, table.find(Enemies, Mob))

						if #Enemies == 0 then
							DeadWieldEvent:Fire()
						end
					end
				end)
			end

			if DungeonConfig.Progress == "Enemy" then
				DeadWieldEvent.Event:Wait()
			end

			DeadWieldEvent:Destroy()
		end

		for _, Door in Room.Doors:GetChildren() do
			if Door.Name == "ShouldDestroy" .. (tostring(tonumber(Room.Name) + 1)) then
				Door:Destroy()
			end
		end

		for _, Door in Room.DoorPlates:GetChildren() do
			if Door.Name == "ShouldDestroy" .. (tostring(tonumber(Room.Name) + 1)) then
				Door:Destroy()
			end
		end
	end
end

function DungeonService:GenerateDungeon(DungeonConfig: DungeonConfig)
	DungeonConfig.Rooms = {}
	DungeonConfig.AmountOfRooms = 0
	DungeonConfig.SafeRooms = 0

	self:PlaceStartRoom(DungeonConfig)

	if DungeonConfig.Type == "Linear" then
		self:GenerateLinearDungeon(DungeonConfig)
	elseif DungeonConfig.Type == "Random" then
		self:GenerateRandomDungeon(DungeonConfig)
	end

	if DungeonConfig.Boss then
		self:BossRoom(DungeonConfig)
	end

	if DungeonConfig.Progress == "Enemy" then
		self:EnemyConfig(DungeonConfig)
	elseif DungeonConfig.Progress == "Complete" then
		self:EnemyConfig(DungeonConfig)
	end
end

function DungeonService:KnitInit()
	RewardService = Knit.GetService("RewardService")
	MobService = Knit.GetService("MobService")
	AIService = Knit.GetService("AIService")

	PhysicsService:RegisterCollisionGroup("LIMITS")
	PhysicsService:CollisionGroupSetCollidable("LIMITS", "LIMITS", true)
	PhysicsService:CollisionGroupSetCollidable("LIMITS", "Default", false)
end

function DungeonService:KnitStart()
	DungeonService:GenerateDungeon({
		Name = "Test",
		Type = "Linear",
		Progress = "Enemy",
		Backtrack = true,
		RoomAmount = 10,
		MaxSafeRooms = 1,
		Boss = {
			Model = "Yamarashi",
			Runner = "Yamarashi",
			Config = "Yamarashi",
		},
		CFrame = CFrame.new(-8000, 221.901, 430.346) * CFrame.Angles(0, math.rad(90), 0),
	})
end

return DungeonService
