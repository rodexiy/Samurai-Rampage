local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

Players.CharacterAutoLoads = false

workspace:SetAttribute("ServerStartTime", game.Workspace:GetServerTimeNow())

PhysicsService:RegisterCollisionGroup("Debris")
PhysicsService:CollisionGroupSetCollidable("Debris", "Debris", false)

local MobsFolder = game.ServerStorage.ServerAssets:FindFirstChild("Mobs")

if MobsFolder then
	for _, Entity in MobsFolder:GetChildren() do
		local Humanoid: Humanoid = Entity.Humanoid
		if Humanoid then
			print(Entity)
			Humanoid.NameOcclusion = Enum.NameOcclusion.OccludeAll
			Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			Humanoid.HealthDisplayDistance = 0
			Humanoid.NameDisplayDistance = 0
		end
	end
end

local FaceHeadFolder = workspace:FindFirstChild("FaceHeadFolder")
if not FaceHeadFolder then
	FaceHeadFolder = Instance.new("Model")
	FaceHeadFolder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	FaceHeadFolder.Name = "FaceHeadFolder"
	FaceHeadFolder.Parent = workspace
end

for _, Tool in game.ReplicatedStorage.Assets.Weapons:GetDescendants() do
	if Tool:IsA("BasePart") then
		Tool.Anchored = false
		Tool.CanCollide = false
		Tool.Massless = true
	end
end

local total = 0
for _, Part in game.ReplicatedStorage.Assets.Equipables:GetDescendants() do
	if Part:IsA("BasePart") then
		Part.Anchored = false
		Part.CanCollide = false
		Part.Massless = true
		if Part.CastShadow then
			Part.CastShadow = false
			total += 1
		end
	end
end

for _, Tool in game.ReplicatedStorage.Assets.Tools:GetDescendants() do
	if Tool:IsA("BasePart") then
		Tool.Anchored = false
		Tool.CanCollide = false
		Tool.CanQuery = false
		Tool.CanTouch = false
		Tool.Massless = true
	end
end

for _, service in game:GetService("ServerStorage"):GetDescendants() do
	if not service:IsA("ModuleScript") then
		continue
	end
	if not service.Name:match("Service$") then
		continue
	end

	require(service)
end

Knit.Start():andThen(function()
	print("[KNIT]: Started!")
end)

local PathCmdr = ReplicatedStorage.Assets.Libraries.Cmdr
local Cmdr = require(ReplicatedStorage.Assets.Libraries.Cmdr)

Cmdr:RegisterDefaultCommands()
Cmdr:RegisterCommandsIn(PathCmdr.Commands)
Cmdr:RegisterHooksIn(PathCmdr.Hooks)
Cmdr:RegisterTypesIn(PathCmdr.Types)

local SharedCmdr = ReplicatedStorage.Shared:FindFirstChild("Cmdr")
if SharedCmdr and SharedCmdr:FindFirstChild("Commands") then
	Cmdr:RegisterCommandsIn(SharedCmdr.Commands)
end

local ServerCmdr = game.ServerStorage.Services:FindFirstChild("Cmdr")
if ServerCmdr then
	local Types = ServerCmdr:FindFirstChild("Types")
	if Types then
		local StoryMissionType = Types:FindFirstChild("StoryMission")
		if StoryMissionType then
			local MissionNames = {}
			for _, Mission in require(game.ServerStorage.Services.Index.StoryMissions) do
				table.insert(MissionNames, Mission.Name)
			end
			StoryMissionType:SetAttribute("MissionNames", table.concat(MissionNames, ","))
		end
		Cmdr:RegisterTypesIn(Types)
	end

	local Commands = ServerCmdr:FindFirstChild("Commands")
	if Commands then
		Cmdr:RegisterCommandsIn(Commands)
	end
end

local MobService = Knit.GetService("MobService")
local AIService = Knit.GetService("AIService")
