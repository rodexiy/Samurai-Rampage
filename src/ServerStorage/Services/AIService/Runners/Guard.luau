local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Guard = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Character: Model
local Humanoid: Humanoid
local RootPart: BasePart
local Align: AlignOrientation
local Config = {}
local Actions = {}
local BountedPlayers = {}

local CurrentNode
local CombatAnimations
local Nodes
local FinderService
local WeaponService
local AIService
local PostureService
local AnimationService
local HitboxService
local RenderService
local SkillService

local Validate = require(game.ReplicatedStorage.Shared.Validate)
local CustomPathfinding = require(ServerStorage.Services.Services.AIService.CustomPathfinding)

local TimeOffset = math.random(1, 10000)

local JobConfig
local TickSinceLastWorking = tick()
local TickSinceStartingWorking
local WorkStation
local MovingToWork = false
local working = false

local Path = PathfindingService:CreatePath({
	AgentRadius = 3,
	AgentHeight = 5,
	AgentCanJump = false,
	WaypointSpacing = 10,
})

local Target: Model = nil
local BindedTarget: Model = nil
local TargetConnections = {}

local UpdateWait = 0.5

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

function Guard:UnbindTarget()
	if not BindedTarget then
		return
	end

	for _, Connection in TargetConnections do
		Connection:Disconnect()
		TargetConnections[_] = nil
	end

	UpdateWait = 0.5
	Character:MoveTo(RootPart.CFrame.Position)
	Align.Enabled = false
	BindedTarget = nil
end

function Guard:BindTarget()
	if Target and BindedTarget and Target == BindedTarget then
		return
	end
	self:UnbindTarget()

	BindedTarget = Target

	table.insert(
		TargetConnections,
		Target:GetAttributeChangedSignal("Attack"):Connect(function()
			if Target:GetAttribute("Attack") then
				task.delay(0.2, function()
					if
						Character:GetAttribute("PostureBreak")
						or Character:GetAttribute("Ragdoll")
						or Character:GetAttribute("UsingSkillCantAttack")
						or not Target
					then
						return
					end

					local Distance = (Character:GetPivot().Position - Target:GetPivot().Position).Magnitude

					if Target:GetAttribute("Attack") and Distance <= Config.ActionDistance then
						if math.random(0, 100) > Config.ActionChance then
							return
						end

						if Actions.Roll and math.random(0, 100) < Config.RollChance then
							local Direction = math.random(1, 2) == 1 and "Left" or "Right"
							Direction = math.random(1, 2) == 1 and Direction or "Backward"

							Actions.Roll:Roll(Direction)
						end
					end
				end)
			else
				AnimationService:StopAnimationFind(Character, "Block")
			end
		end)
	)

	table.insert(
		TargetConnections,
		Target:GetAttributeChangedSignal("Died"):Connect(function()
			Target = nil
			Guard:UnbindTarget()
		end)
	)

	Guard:LookAtTarget()

	Align.Enabled = true
	UpdateWait = 0
end

function Guard:Block()
	if Character:GetAttribute("UsingSkillCantAttack") then
		return
	end

	if Target then
		if Character:GetAttribute("Rolling") then
			return
		end

		if not AnimationService:GetAnimationFind(Character, "Block") then
			if math.random(0, 100) < Config.ActionChance and math.random(0, 100) < Config.DeflectChance then
				AnimationService:PlayAnimation(Character, CombatAnimations.Block)
			end
		end

		if not AnimationService:GetAnimationFind(Character, "Block") then
			return
		end

		PostureService:Block(Character, true)

		task.delay(0.2, function()
			PostureService:Block(Character, false)
		end)
	end
end

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

function Guard:MoveToRandomTarget()
	if Character:GetAttribute("Ragdoll") then
		return
	end

	if Character:GetAttribute("Downed") then
		return
	end
	if CustomPathfinding.Break then
		return
	end

	local NextNode = GetNextNode()

	if not NextNode or Path.Status ~= Enum.PathStatus.Success then
		return
	end

	local Waypoints = Path:GetWaypoints()

	for i, Waypoint in Waypoints do
		if typeof(Waypoint) == "PathWaypoint" then
			if CustomPathfinding.Break then
				break
			end
			Humanoid:MoveTo(Waypoint.Position)
			Humanoid.MoveToFinished:Wait()
			continue
		end
	end

	CurrentNode = NextNode
end

function Guard:MoveToTarget()
	local Noise = math.noise(os.clock() + TimeOffset)

	local CharactersIn = HitboxService:GetCharactersInCircleArea(Character:GetPivot().Position, 10)

	local AllyOffset = Vector3.zero

	local Closest = nil
	local ClosestDistance = math.huge
	for _, CharacterIn in CharactersIn do
		if CharacterIn == Target or CharacterIn == Character then
			continue
		end

		if CharacterIn:GetAttribute("IsAI") and not CharacterIn:GetAttribute("Downed") then
			local Distance = (CharacterIn:GetPivot().Position - Target:GetPivot().Position).Magnitude
			if Distance < ClosestDistance then
				Closest = CharacterIn
				ClosestDistance = Distance
			end
		end
	end

	if Closest then
		AllyOffset = -(CFrame.new(Character:GetPivot().Position, Closest:GetPivot().Position).LookVector * 10)
	end

	local PositionToMove = (CFrame.new(Target:GetPivot().Position, RootPart.CFrame.Position) * CFrame.new(
		Noise * 30,
		0,
		-(Config.TargetOffset * (math.abs(Noise) * 7.5))
	)).Position + AllyOffset

	Humanoid:MoveTo(PositionToMove)
end

function Guard:LookAtTarget()
	if Character:GetAttribute("Ragdoll") then
		return
	end

	if Character:GetAttribute("Downed") then
		return
	end

	Character:SetAttribute("MousePosition", Target:GetPivot().Position)
	local Pivot = Target:GetPivot()
	local PositionToLook = Vector3.new(Pivot.Position.X, RootPart.CFrame.Position.Y, Pivot.Position.Z)
	Align.LookAtPosition = PositionToLook
end

function Guard:RunToTarget()
	if not Actions.Run then
		return
	end

	local Distance = (Target:GetPivot().Position - RootPart:GetPivot().Position).Magnitude
	if Distance >= Config.RunDistance then
		Actions.Run:Run()
	end
end

function Guard:CheckDistance()
	local Distance = (Target:GetPivot().Position - RootPart:GetPivot().Position).Magnitude

	if Distance > Config.MaintainDistance then
		self:UnbindTarget()
		Target = nil
		return true
	end
end

function Guard:TryAttack()
	local Distance = (Target:GetPivot().Position - RootPart:GetPivot().Position).Magnitude

	if Distance <= Config.AttackDistance then
		if not Target:GetAttribute("Downed") then
			if math.random(1, 5) > 1 then
				if Target:GetAttribute("PostureBreak") then
					WeaponService:WeaponInput(Character, "Attack", { RootCFrame = Character:GetPivot() })
					return
				end
				task.wait(math.random(10, 40) / 100)
				WeaponService:WeaponInput(Character, "Attack", { RootCFrame = Character:GetPivot() })
			else
				if Config.Skills and math.random(0, 100) <= Config.SkillChance then
					local SkillToUse = Config.Skills[math.random(1, #Config.Skills)]

					if not SkillService:UseSkill(Character, SkillToUse) then
						return
					end
				end

				WeaponService:WeaponInput(Character, "StrongAttack", { RootCFrame = Character:GetPivot() })
			end
		else
			WeaponService:WeaponInput(Character, "StrongAttack", { RootCFrame = Character:GetPivot() })
		end
	end
end

function Guard:Rest()
	if CustomPathfinding.Break then
		return
	end
	if working and not MovingToWork then
		if TickSinceStartingWorking and tick() - TickSinceStartingWorking > JobConfig.WorkDuration then
			CustomPathfinding:FindPlayersInRadius(Character, function(Player)
				ReplicatedStorage.Assets.Public.BubbleEvent:FireClient(
					Player,
					"Cansei, vo baianar",
					Character.PrimaryPart.Position
				)
			end)
			working = false
			MovingToWork = false
			TickSinceStartingWorking = nil
			TickSinceLastWorking = tick()
			if WorkStation then
				WorkStation:SetAttribute("Unavailable", nil)
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
					JobNode:SetAttribute("Unavailable", true)
					CustomPathfinding:FindPlayersInRadius(Character, function(Player)
						ReplicatedStorage.Assets.Public.BubbleEvent:FireClient(
							Player,
							"Ta na hora de trabaiar",
							Character.PrimaryPart.Position
						)
					end)
					MovingToWork = true
					CustomPathfinding:MoveTo(Character.Humanoid, PathNodes, function()
						Character:PivotTo(JobNode.CFrame)
						WorkStation = JobNode
					end)
					MovingToWork = false
					working = true
					TickSinceStartingWorking = tick()
				else
					Guard:MoveToRandomTarget()
				end
			else
				Guard:MoveToRandomTarget()
			end
		end
	else
		Guard:MoveToRandomTarget()
	end
end

function Guard:Run()
	if Character:GetPivot().Y < 0 then
		Character:PivotTo(Character:GetAttribute("SpawnCFrame"))
		return
	end
	if Character:GetAttribute("Ragdoll") then
		return
	end

	if Character:GetAttribute("Downed") then
		return
	end

	local _Target = FinderService:GetClosestTarget(Character, Config.DetectionDistance)

	if _Target and _Target:GetAttribute("Bounted") then
		if not Target and _Target then
			local TargetPlayer = game.Players:GetPlayerFromCharacter(_Target)
			if TargetPlayer then
				RenderService:RenderForPlayer(TargetPlayer, "Enemy", "Detect", { Character = Character })
			end
		end
		Target = _Target
	end

	if not Target or Character:GetAttribute("Ragdoll") then
		self:UnbindTarget()

		if Character:GetAttribute("WeaponEquipped") then
			Character:SetAttribute("Running", false)
			Character:SetAttribute("WeaponEquipped", false)
			task.delay(math.random(100, 500) / 100, function()
				if Target then
					return
				end
				Character:SetAttribute("InCombat", false)
				WeaponService:Equip(Character, false, 1.5)
				Guard:Rest()
				CustomPathfinding.Break = false
			end)
		else
			Guard:Rest()
		end
		return
	end

	self:BindTarget()

	if not Character:GetAttribute("WeaponEquipped") then
		WeaponService:Equip(Character, true)
	end

	if self:CheckDistance() then
		return
	end

	self:LookAtTarget()
	self:MoveToTarget()
	self:RunToTarget()
	self:TryAttack()
end

function Guard.Start(_Config)
	FinderService = Knit.GetService("FinderService")
	WeaponService = Knit.GetService("WeaponService")
	PostureService = Knit.GetService("PostureService")
	AnimationService = Knit.GetService("AnimationService")
	HitboxService = Knit.GetService("HitboxService")
	RenderService = Knit.GetService("RenderService")
	SkillService = Knit.GetService("SkillService")

	Character = script.Parent

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

	Nodes = ServerStorage.WalkingNodes[Character:GetAttribute("NodeLocation")].Nodes:GetChildren()
	CurrentNode = GetClosestNode()
	Config = _Config.Lifes[tostring(Character:GetAttribute("Lifes"))]
	Character:GetAttributeChangedSignal("Lifes"):Connect(function()
		Config = _Config.Lifes[tostring(Character:GetAttribute("Lifes"))]
		Configure()
	end)

	Configure()

	Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	RootPart = Character.PrimaryPart

	Align = RootPart:FindFirstChildWhichIsA("AlignOrientation", true)

	CombatAnimations = WeaponService:GetCombatAnimationFolder(Character)

	Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		Align.Enabled = not Character:GetAttribute("Ragdoll")
	end)

	local HitboxDetected: BindableEvent = Character:FindFirstChild("HitboxDetected")

	if HitboxDetected then
		HitboxDetected.Event:Connect(function(Attacker: Model, Data: {})
			if not Target then
				CustomPathfinding.Break = true
				local TargetPlayer = game.Players:GetPlayerFromCharacter(Attacker)
				if TargetPlayer then
					RenderService:RenderForPlayer(TargetPlayer, "Enemy", "Detect", { Character = Character })
				end
				Target = Attacker
				Target:SetAttribute("Bounted", true)
				task.delay(30, function()
					local _Target = FinderService:GetClosestTarget(Character, Config.DetectionDistance)

					if _Target and not _Target:GetAttribute("Bounted") then
						Attacker:SetAttribute("Bounted", nil)
					elseif not _Target then
						Attacker:SetAttribute("Bounted", nil)
					elseif _Target and _Target:GetAttribute("Bounted") then
						_Target:SetAttribute("Bounted", true)
					end
				end)
			end

			if Data.DodgeOnly then
				local RollRNG = math.random(0, 100)
				if Actions.Roll and RollRNG < Config.RollChance then
					local Direction = math.random(1, 2) == 1 and "Left" or "Right"
					Direction = math.random(1, 2) == 1 and Direction or "Backward"

					Actions.Roll:Roll(Direction)
				end
			else
				Guard:Block()
			end
		end)
	end

	Character:SetAttribute("SpawnCFrame", Character:GetPivot())

	script:GetAttributeChangedSignal("Enabled"):Connect(function()
		if not script:GetAttribute("Enabled") then
			Guard:Run()
			return
		end

		while script:GetAttribute("Enabled") do
			Guard:Run()
			task.wait(UpdateWait)
		end
	end)
end

return Guard
