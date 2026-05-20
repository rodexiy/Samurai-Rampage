local PathfindingService = game:GetService("PathfindingService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local TextChatService = game:GetService("TextChatService")
local Villager = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local CustomPathfinding = require(ServerStorage.Services.Services.AIService.CustomPathfinding)

local Character: Model
local Humanoid: Humanoid
local RootPart: BasePart
local Align: AlignOrientation
local Config = {}
local Actions = {}
local JobConfig
local WorkStation
local BeingAttacked

local WeaponService

local Nodes
local CurrentNode

local TickSinceLastWorking = tick()
local TickSinceStartingWorking
local MovingToWork = false
local UpdateWait = 0.5
local working = false

local function GetClosestNode(_Nodes)
	local ClosestNode
	local Distance = math.huge
	for _, Node in _Nodes or Nodes do
		if CurrentNode == Node then
			continue
		end
		local NodeDistance = (Node.Position - Character:GetPivot().Position).Magnitude
		if NodeDistance < Distance then
			Distance = NodeDistance
			ClosestNode = Node
		end
	end

	return ClosestNode, Distance
end

local function GetClosestJobNode(_Nodes, Job)
	local ClosestNode
	local Distance = math.huge

	if not ServerStorage.WalkingNodes[Character:GetAttribute("NodeLocation")]:FindFirstChild(Job) then
		warn("No job nodes found for job: " .. Job)
		return
	end
	for _, Node in _Nodes or Nodes do
		if CurrentNode == Node then
			continue
		end
		local NodeDistance = (Node.Position - Character:GetPivot().Position).Magnitude
		if NodeDistance < Distance and not Node:GetAttribute("Unavailable") then
			Distance = NodeDistance
			ClosestNode = Node
		end
	end
	--print("Closest job node found: " .. ClosestNode.Name)
	return ClosestNode, Distance
end

local function GetNodesInDistance(_Nodes, MaxDistance)
	local InDistance = {}
	for _, Node in _Nodes or Nodes do
		if CurrentNode == Node then
			continue
		end
		local NodeDistance = (Node.Position - Character:GetPivot().Position).Magnitude
		if NodeDistance <= MaxDistance then
			table.insert(InDistance, Node)
		end
	end

	return InDistance
end

local Path = PathfindingService:CreatePath({
	AgentRadius = 3,
	AgentHeight = 5,
	AgentCanJump = false,
	WaypointSpacing = 10,
})

local function GetNextNode()
	local NextNode

	local NodesInFront = {}

	local CharacterLookVector = Character:GetPivot().LookVector

	for _, Node in Nodes do
		local DirectionToNode = (Node.Position - Character:GetPivot().Position).Unit
		local DotProduct = DirectionToNode:Dot(CharacterLookVector)

		if DotProduct > 0 then
			table.insert(NodesInFront, Node)
		end
	end

	if #NodesInFront == 0 then
		for _, Node in Nodes do
			local DirectionToNode = (Node.Position - Character:GetPivot().Position).Unit
			local DotProduct = DirectionToNode:Dot(CharacterLookVector)

			if DotProduct < 0 then
				table.insert(NodesInFront, Node)
			end
		end
	end

	local NodesInDistance = GetNodesInDistance(NodesInFront, 100)
	if #NodesInDistance == 0 then
		NextNode = GetClosestNode(NodesInFront) :: BasePart
	else
		local FilteredNodes = {}
		for _, Node in NodesInDistance do
			Path:ComputeAsync(Character:GetPivot().Position - Vector3.new(0, 4 / 0.75, 0), Node.Position)
			if Path.Status ~= Enum.PathStatus.Success then
				continue
			end

			table.insert(FilteredNodes, Node)
		end
		if #FilteredNodes == 0 then
			NextNode = GetClosestNode(NodesInFront)
		else
			NextNode = FilteredNodes[math.random(1, #FilteredNodes)]
		end
	end

	if not NextNode then
		local NodesRandom = GetNodesInDistance(Nodes, 125)
		NextNode = NodesRandom[math.random(1, #NodesRandom)]
	end

	Path:ComputeAsync(Character:GetPivot().Position - Vector3.new(0, 4 / 0.75, 0), NextNode.Position)

	return NextNode
end

function Villager:MoveToTarget()
	if Character:GetAttribute("Ragdoll") then
		return
	end

	if Character:GetAttribute("Downed") then
		return
	end

	local NextNode = GetNextNode()

	if not NextNode or Path.Status ~= Enum.PathStatus.Success then
		return
	end

	local Waypoints = Path:GetWaypoints()

	for i, Waypoint in Waypoints do
		if typeof(Waypoint) == "PathWaypoint" then
			Humanoid:MoveTo(Waypoint.Position)
			Humanoid.MoveToFinished:Wait()
			continue
		end
	end

	CurrentNode = NextNode
end

function Villager:RunState()
	if not Actions.Run then
		return
	end
	Actions.Run:Run()
end

function Villager:MoveToClosestGuard()
	if not BeingAttacked then
		return
	end

	local guard = CustomPathfinding:FindClosestGuardInTheVillage(Character) :: Model
	local PathNodes = CustomPathfinding:FindPath(Character.PrimaryPart.Position, guard.PrimaryPart.Position)
	CustomPathfinding:MoveTo(Character.Humanoid, PathNodes)
end

function Villager:Rest()
	if working and not MovingToWork then
		if TickSinceStartingWorking and tick() - TickSinceStartingWorking > JobConfig.WorkDuration then
			-- CustomPathfinding:FindPlayersInRadius(Character, function(Player)
			-- 	ReplicatedStorage.Assets.Public.BubbleEvent:FireClient(Player, "Cansei, vo baianar", Character.PrimaryPart.Position)
			-- end)
			working = false
			MovingToWork = false
			TickSinceStartingWorking = nil
			TickSinceLastWorking = tick()
			if WorkStation then
				--WorkStation:SetAttribute("Unavailable", nil)
				WorkStation = nil
			end
		end
	end

	if MovingToWork or working then
		return
	end

	local Job = Character:GetAttribute("Job")
	if Job and tick() - TickSinceLastWorking > JobConfig.RestDuration then
		local JobNode = ServerStorage.WalkingNodes[Character:GetAttribute("NodeLocation")]:FindFirstChild(Job)
		if JobNode then
			local Nodes = JobNode:GetChildren()
			JobNode = GetClosestJobNode(Nodes, Job)
			if JobNode then
				local temp =
					table.clone(ServerStorage.WalkingNodes[Character:GetAttribute("NodeLocation")].Nodes:GetChildren())
				table.insert(temp, JobNode)
				local PathNodes = CustomPathfinding:FindPath(Character:GetPivot().Position, JobNode.Position, temp)
				if PathNodes then
					--JobNode:SetAttribute("Unavailable", true)
					-- CustomPathfinding:FindPlayersInRadius(Character, function(Player)
					-- 	ReplicatedStorage.Assets.Public.BubbleEvent:FireClient(Player, "Ta na hora de trabaiar", Character.PrimaryPart.Position)
					-- end)
					MovingToWork = true
					CustomPathfinding:MoveTo(Character.Humanoid, PathNodes, function()
						Character:PivotTo(JobNode.CFrame)
						WorkStation = JobNode
					end)
					MovingToWork = false
					working = true
					TickSinceStartingWorking = tick()
				else
					Villager:MoveToTarget()
				end
			else
				Villager:MoveToTarget()
			end
		end
	else
		Villager:MoveToTarget()
	end
end

function Villager:Run()
	if Character:GetAttribute("Ragdoll") then
		return
	end

	if Character:GetAttribute("Downed") then
		return
	end

	if not BeingAttacked then
		Villager:Rest()
	else
	end
end

function Villager.Start(_Config)
	WeaponService = Knit.GetService("WeaponService")

	Character = script.Parent :: Model

	if Character:GetAttribute("Job") then
		TickSinceLastWorking = tick()
		JobConfig = require(ServerStorage.Services.Services.AIService.JobConfigs[Character:GetAttribute("Job")])
	end

	local function Configure()
		local ActionsFolder = game.ServerStorage.ServerAssets.MobActions

		local ActionsList = Config.Actions or {}
		for actionName, instance in Actions do
			if not table.find(ActionsList, actionName) then
				Actions[actionName] = nil
				instance:Destroy()
			end
		end

		for _, action in ActionsList do
			if ActionsFolder:FindFirstChild(action) then
				if script:FindFirstChild(action) then
					continue
				end

				local Clone = ActionsFolder[action]:Clone()
				Clone.Parent = script
				Actions[action] = require(Clone)
			end
		end

		Character:SetAttribute("RunningWalkSpeed", Config.RunSpeed or 20)
	end

	Config = _Config.Lifes[tostring(Character:GetAttribute("Lifes"))]
	Character:GetAttributeChangedSignal("Lifes"):Connect(function()
		Config = _Config.Lifes[tostring(Character:GetAttribute("Lifes"))]
		Configure()
	end)

	Nodes = ServerStorage.WalkingNodes[Character:GetAttribute("NodeLocation")].Nodes:GetChildren()
	CurrentNode = GetClosestNode()

	Configure()

	Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	RootPart = Character.PrimaryPart

	Align = RootPart:FindFirstChildWhichIsA("AlignOrientation", true)

	Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		--Align.Enabled = not Character:GetAttribute("Ragdoll")
	end)

	local HitboxDetected: BindableEvent = Character:FindFirstChild("HitboxDetected")

	if HitboxDetected then
		HitboxDetected.Event:Connect(function(Attacker: Model)
			Attacker:SetAttribute("Bounted", true)
			BeingAttacked = true
			task.delay(30, function()
				Attacker:SetAttribute("Bounted", nil)
				BeingAttacked = nil
			end)
		end)
	end

	Character:SetAttribute("SpawnCFrame", Character:GetPivot())

	script:GetAttributeChangedSignal("Enabled"):Connect(function()
		if not script:GetAttribute("Enabled") then
			Villager:Run()
			return
		end

		while script:GetAttribute("Enabled") do
			Villager:Run()
			task.wait(UpdateWait)
		end
	end)

	script:SetAttribute("Enabled", true)
end

return Villager
