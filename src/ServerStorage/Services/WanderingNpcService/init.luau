local PhysicsService = game:GetService("PhysicsService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local WanderingNpcService = Knit.CreateService({
	Name = "WanderingNpcService",
	Client = {},
})

local AIService
local HitboxService

local MobService

local WalkingNodes = game.ServerStorage:FindFirstChild("WalkingNodes")

local SkinColors = {
	Color3.fromRGB(255, 212, 151),
	Color3.fromRGB(255, 194, 124),
	Color3.fromRGB(255, 210, 171),
	Color3.fromRGB(154, 126, 103),
	Color3.fromRGB(217, 203, 122),
}

function WanderingNpcService:CreateNpc(MobName: string, Equipment: string?)
	local Mob = MobService:CreateMob(MobName, Equipment or MobName)

	local BodyColors = Mob:FindFirstChild("BodyColors") or Instance.new("BodyColors")
	local RandomColor = SkinColors[math.random(1, #SkinColors)]
	BodyColors.HeadColor3 = RandomColor
	BodyColors.LeftArmColor3 = RandomColor
	BodyColors.RightArmColor3 = RandomColor
	BodyColors.LeftLegColor3 = RandomColor
	BodyColors.RightLegColor3 = RandomColor
	BodyColors.TorsoColor3 = RandomColor
	BodyColors.Parent = Mob

	Mob.PrimaryPart.TopStatusDisplay.EntityName.Visible = false

	local EyesFace: Decal = Mob:FindFirstChild("EyesFace", true)
	if EyesFace then
		EyesFace.Color3 = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
	end

	HitboxService:LoadR6Hitbox(Mob)

	for _, Part: BasePart in Mob:GetDescendants() do
		if Part:IsA("BasePart") and (Part.CollisionGroup == "Default" or Part.CollisionGroup == "Entity") then
			Part.CollisionGroup = "WanderingNpc"
		end
	end

	return Mob
end

function WanderingNpcService.KnitInit()
	MobService = Knit.GetService("MobService")
	AIService = Knit.GetService("AIService")
	HitboxService = Knit.GetService("HitboxService")
end

function WanderingNpcService.KnitStart()
	if not WalkingNodes then
		return
	end

	PhysicsService:RegisterCollisionGroup("WanderingNpc")
	PhysicsService:CollisionGroupSetCollidable("WanderingNpc", "WanderingNpc", false)
	PhysicsService:CollisionGroupSetCollidable("Entity", "WanderingNpc", false)

	for _, NodesLocation in WalkingNodes:GetChildren() do
		local MaxNpcs = NodesLocation:GetAttribute("MaxNpcs")

		if not MaxNpcs or not NodesLocation:FindFirstChild("Presets") then
			continue
		end

		local Nodes = NodesLocation.Nodes:GetChildren()

		local Presets = require(NodesLocation.Presets)

		local function Spawn()
			local MobName = Presets[math.random(1, #Presets)]

			local willSpawnFarmer = math.random(0, 100)
			local willSpawnGuard = math.random(0, 100)
			local Npc

			if willSpawnGuard <= 10 then
				Npc = WanderingNpcService:CreateNpc(MobName, "Guard")
			elseif willSpawnFarmer <= 30 then
				Npc = WanderingNpcService:CreateNpc(MobName, "KaisoraVillager")
			else
				Npc = WanderingNpcService:CreateNpc(MobName, MobName)
			end

			if not Npc then
				return
			end

			local RandomNode = Nodes[math.random(1, #Nodes)]

			Npc:SetAttribute("NodeLocation", NodesLocation.Name)
			Npc:SetAttribute("WanderingNpc", true)
			Npc:AddTag("Entity")

			Npc.HumanoidRootPart.CFrame = CFrame.new(RandomNode.Position + Vector3.new(0, 2.5, 0))
				* CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
			Npc.Parent = workspace.Entity

			Npc:GetAttributeChangedSignal("Died"):Connect(function()
				task.wait(math.random(60, 120))
				Spawn()
			end)

			if willSpawnGuard <= 10 then
				AIService:AddAI(Npc, "Guard", "Guard", "Guard")
				return
			end

			if willSpawnFarmer <= 30 then
				AIService:AddAI(Npc, "Villager", "KaisoraVillager", "Farmer")
				return
			end

			AIService:AddAI(Npc, "Villager", "KaisoraVillager")
		end

		for i = 1, MaxNpcs do
			Spawn()
		end
	end
end

return WanderingNpcService
