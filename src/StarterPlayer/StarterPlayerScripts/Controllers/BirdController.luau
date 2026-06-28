local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BirdController = Knit.CreateController({
	Name = "BirdController",
})

local LOCAL_PLAYER = Players.LocalPlayer
local RANDOM = Random.new()

local SIMULATION_STEP = 1 / 30
local MAX_BIRDS = if UserInputService.TouchEnabled then 4 else 6
local SPAWN_INTERVAL = 0.8
local SPAWN_DISTANCE_MIN = 70
local SPAWN_DISTANCE_MAX = 200
local DESPAWN_DISTANCE = 300
local SCARE_DISTANCE = 30
local BIRD_SPACING = 9
local GROUND_OFFSET = 0.65

local FLY_SPEED_MIN = 24
local FLY_SPEED_MAX = 34
local LAND_SPEED = 20
local FLIGHT_HEIGHT_MIN = 35
local FLIGHT_HEIGHT_MAX = 70
local NIGHT_START_TIME = 18
local NIGHT_END_TIME = 5.4
local WING_LOD_DISTANCE_SQUARED = 100 * 100
local WING_FLAP_SPEED = 28
local WING_FLAP_ANGLE = math.rad(38)

local clientBirdFolder
local idleTemplate
local flyingTemplate
local birds = {}
local simulationAccumulator = 0
local spawnAccumulator = SPAWN_INTERVAL
local scareAccumulator = 0

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = false
raycastParams.RespectCanCollide = true

local function horizontalUnit(vector, fallback)
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	if horizontal.Magnitude < 0.001 then
		return fallback or Vector3.zAxis
	end

	return horizontal.Unit
end

local function randomHorizontalDirection()
	local angle = RANDOM:NextNumber(0, math.pi * 2)
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local function randomPointAround(origin, minimumDistance, maximumDistance)
	local direction = randomHorizontalDirection()
	local distance = RANDOM:NextNumber(minimumDistance, maximumDistance)
	return origin + direction * distance
end

local function cubicHermite(startPosition, endPosition, startTangent, endTangent, alpha)
	local alphaSquared = alpha * alpha
	local alphaCubed = alphaSquared * alpha
	local startWeight = 2 * alphaCubed - 3 * alphaSquared + 1
	local startTangentWeight = alphaCubed - 2 * alphaSquared + alpha
	local endWeight = -2 * alphaCubed + 3 * alphaSquared
	local endTangentWeight = alphaCubed - alphaSquared

	return startPosition * startWeight
		+ startTangent * startTangentWeight
		+ endPosition * endWeight
		+ endTangent * endTangentWeight
end

local function refreshRaycastFilter()
	local filter = { clientBirdFolder }
	if LOCAL_PLAYER.Character then
		table.insert(filter, LOCAL_PLAYER.Character)
	end

	local characters = Workspace:FindFirstChild("Characters")
	if characters then
		table.insert(filter, characters)
	end

	local npcs = Workspace:FindFirstChild("NPCs")
	if npcs then
		table.insert(filter, npcs)
	end

	raycastParams.FilterDescendantsInstances = filter
end

local function findGround(position)
	refreshRaycastFilter()
	local origin = position + Vector3.new(0, 120, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -320, 0), raycastParams)
	if not result or result.Material == Enum.Material.Water or result.Normal.Y < 0.72 then
		return nil
	end

	if result.Instance:IsA("BasePart") and result.Instance.Transparency >= 0.98 then
		return nil
	end

	return result.Position + Vector3.new(0, GROUND_OFFSET, 0)
end

local function configureModel(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
end

local function setupFlyingWings(model)
	local leftWing = model:FindFirstChild("LeftWing", true)
	local rightWing = model:FindFirstChild("RightWing", true) or model:FindFirstChild("RightWind", true)

	if not (leftWing and leftWing:IsA("BasePart") and rightWing and rightWing:IsA("BasePart")) then
		local sourceWing = model:FindFirstChild("Part", true)
		if not sourceWing or not sourceWing:IsA("BasePart") then
			return nil
		end

		local fullSize = sourceWing.Size
		local baseCFrame = sourceWing.CFrame
		local quarterWidth = fullSize.X * 0.25

		leftWing = sourceWing
		leftWing.Name = "LeftWing"
		leftWing.Size = Vector3.new(fullSize.X * 0.5, fullSize.Y, fullSize.Z)
		leftWing.CFrame = baseCFrame * CFrame.new(-quarterWidth, 0, 0)
		leftWing.PivotOffset = CFrame.new(quarterWidth, 0, 0)

		rightWing = leftWing:Clone()
		rightWing.Name = "RightWing"
		rightWing.CFrame = baseCFrame * CFrame.new(quarterWidth, 0, 0)
		rightWing.PivotOffset = CFrame.new(-quarterWidth, 0, 0)
		rightWing.Parent = model
	end

	local modelPivot = model:GetPivot()

	return {
		left = leftWing,
		right = rightWing,
		leftBasePivot = modelPivot:ToObjectSpace(leftWing:GetPivot()),
		rightBasePivot = modelPivot:ToObjectSpace(rightWing:GetPivot()),
		animated = false,
	}
end

local function updateWingLOD(bird, birdCFrame, now)
	local wings = bird.wings
	if not wings then
		return
	end

	local camera = Workspace.CurrentCamera
	local isClose = camera
		and (bird.position - camera.CFrame.Position).Magnitude ^ 2 <= WING_LOD_DISTANCE_SQUARED

	if isClose then
		local flapAngle = math.sin(now * WING_FLAP_SPEED + bird.bobPhase) * WING_FLAP_ANGLE
		wings.left:PivotTo(birdCFrame * wings.leftBasePivot * CFrame.Angles(0, 0, flapAngle))
		wings.right:PivotTo(birdCFrame * wings.rightBasePivot * CFrame.Angles(0, 0, -flapAngle))
		wings.animated = true
	elseif wings.animated then
		wings.left:PivotTo(birdCFrame * wings.leftBasePivot)
		wings.right:PivotTo(birdCFrame * wings.rightBasePivot)
		wings.animated = false
	end
end

local function setVariant(bird, variant)
	if bird.variant == variant then
		return
	end

	if bird.model then
		bird.model.Parent = nil
	end

	local model = if variant == "Idle" then bird.idleModel else bird.flyingModel
	model:PivotTo(bird.cframe or CFrame.new(bird.position))
	model.Parent = clientBirdFolder
	bird.model = model
	bird.variant = variant
end

local function renderBird(bird, now)
	local direction = horizontalUnit(bird.velocity, bird.direction)
	bird.direction = direction

	local position = bird.position
	local bank = 0
	if bird.variant == "Flying" then
		position += Vector3.new(0, math.sin(now * 4 + bird.bobPhase) * 0.16, 0)
		bank = math.sin(now * 2.3 + bird.bobPhase) * 0.08
	end

	local cframe = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, 0, bank)
	bird.cframe = cframe
	bird.model:PivotTo(cframe)
	if bird.variant == "Flying" then
		updateWingLOD(bird, cframe, now)
	end
end

local function isFarEnoughFromBirds(position)
	for _, bird in birds do
		if (bird.position - position).Magnitude < BIRD_SPACING then
			return false
		end
	end

	return true
end

local function chooseFlightTarget(bird, playerPosition)
	local heading = horizontalUnit(bird.velocity, bird.direction)
	local turn = RANDOM:NextNumber(-0.65, 0.65)
	local travelDirection = CFrame.fromAxisAngle(Vector3.yAxis, turn):VectorToWorldSpace(heading)
	local travelDistance = RANDOM:NextNumber(90, 180)
	local targetXZ = bird.position + travelDirection * travelDistance

	-- Only steer back at the edge of the local simulation area. Normal flight
	-- continues from the bird's own heading instead of orbiting the player.
	if (targetXZ - playerPosition).Magnitude > DESPAWN_DISTANCE - 35 then
		local inward = horizontalUnit(playerPosition - bird.position, randomHorizontalDirection())
		travelDirection = horizontalUnit(travelDirection + inward * 0.8, inward)
		targetXZ = bird.position + travelDirection * travelDistance
	end

	local groundPosition = findGround(targetXZ)
	local baseY = if groundPosition
		then groundPosition.Y
		else bird.position.Y - (FLIGHT_HEIGHT_MIN + FLIGHT_HEIGHT_MAX) * 0.5

	bird.target = Vector3.new(
		targetXZ.X,
		baseY + RANDOM:NextNumber(FLIGHT_HEIGHT_MIN, FLIGHT_HEIGHT_MAX),
		targetXZ.Z
	)
	bird.targetExpiresAt = Workspace.DistributedGameTime + math.clamp(travelDistance / bird.speed * 1.5, 4, 9)
end

local function beginFlight(bird, frightened, playerPosition)
	setVariant(bird, "Flying")
	bird.state = "Flying"
	bird.canLandAt = Workspace.DistributedGameTime + RANDOM:NextNumber(10, 24)

	if frightened then
		local away = horizontalUnit(bird.position - playerPosition, randomHorizontalDirection())
		bird.velocity = away * bird.speed + Vector3.new(0, 9, 0)
		bird.target = bird.position + away * RANDOM:NextNumber(80, 120) + Vector3.new(0, RANDOM:NextNumber(24, 40), 0)
		bird.targetExpiresAt = Workspace.DistributedGameTime + 7
		bird.fleeUntil = Workspace.DistributedGameTime + 5
	else
		bird.velocity = bird.direction * bird.speed + Vector3.new(0, 7, 0)
		bird.fleeUntil = 0
		chooseFlightTarget(bird, playerPosition)
	end
end

local function beginLanding(bird)
	local heading = horizontalUnit(bird.velocity, bird.direction)
	local turn = RANDOM:NextNumber(-0.3, 0.3)
	local landingDirection = CFrame.fromAxisAngle(Vector3.yAxis, turn):VectorToWorldSpace(heading)
	local targetXZ = bird.position + landingDirection * RANDOM:NextNumber(50, 85)
	local groundPosition = findGround(targetXZ)
	if not groundPosition then
		return false
	end

	local now = Workspace.DistributedGameTime
	local horizontalDistance = (Vector3.new(groundPosition.X, 0, groundPosition.Z) - Vector3.new(bird.position.X, 0, bird.position.Z)).Magnitude
	local duration = math.clamp(horizontalDistance / LAND_SPEED, 2.25, 4)

	bird.state = "Landing"
	bird.target = groundPosition
	bird.landingStart = bird.position
	bird.landingStartTangent = bird.velocity * duration
	bird.landingStartedAt = now
	bird.landingDuration = duration
	bird.targetExpiresAt = now + duration + 1
	return true
end

local function finishLanding(bird)
	bird.position = bird.target
	bird.velocity = Vector3.zero
	bird.state = "Perched"
	bird.stateEndsAt = Workspace.DistributedGameTime + RANDOM:NextNumber(7, 22)
	setVariant(bird, "Idle")
end

local function destroyBird(index)
	local bird = birds[index]
	if not bird then
		return
	end

	bird.idleModel:Destroy()
	bird.flyingModel:Destroy()
	table.remove(birds, index)
end

local function destroyAllBirds()
	for index = #birds, 1, -1 do
		destroyBird(index)
	end
end

local function birdsCanSpawn()
	local clockTime = Lighting.ClockTime
	local isNight = clockTime >= NIGHT_START_TIME or clockTime < NIGHT_END_TIME
	return LOCAL_PLAYER:GetAttribute("Birds") ~= false
		and not isNight
		and Workspace:GetAttribute("Season") ~= "Winter"
end

local function createBird(playerPosition)
	local groundPosition
	for _ = 1, 8 do
		local candidate = randomPointAround(playerPosition, SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
		groundPosition = findGround(candidate)
		if groundPosition and isFarEnoughFromBirds(groundPosition) then
			break
		end
		groundPosition = nil
	end

	if not groundPosition then
		return
	end

	local idleModel = idleTemplate:Clone()
	local flyingModel = flyingTemplate:Clone()
	configureModel(idleModel)
	configureModel(flyingModel)
	local wings = setupFlyingWings(flyingModel)

	local direction = randomHorizontalDirection()
	local startsPerched = RANDOM:NextNumber() < 0.35
	local bird = {
		idleModel = idleModel,
		flyingModel = flyingModel,
		wings = wings,
		model = nil,
		variant = nil,
		position = groundPosition,
		velocity = direction * RANDOM:NextNumber(FLY_SPEED_MIN, FLY_SPEED_MAX),
		direction = direction,
		speed = RANDOM:NextNumber(FLY_SPEED_MIN, FLY_SPEED_MAX),
		target = groundPosition,
		targetExpiresAt = 0,
		stateEndsAt = 0,
		canLandAt = 0,
		fleeUntil = 0,
		landingStart = groundPosition,
		landingStartTangent = Vector3.zero,
		landingStartedAt = 0,
		landingDuration = 0,
		bobPhase = RANDOM:NextNumber(0, math.pi * 2),
		cframe = CFrame.new(groundPosition),
	}
	table.insert(birds, bird)

	if startsPerched then
		bird.state = "Perched"
		bird.stateEndsAt = Workspace.DistributedGameTime + RANDOM:NextNumber(5, 18)
		setVariant(bird, "Idle")
	else
		bird.position += Vector3.new(0, RANDOM:NextNumber(FLIGHT_HEIGHT_MIN, FLIGHT_HEIGHT_MAX), 0)
		setVariant(bird, "Flying")
		bird.state = "Flying"
		bird.canLandAt = Workspace.DistributedGameTime + RANDOM:NextNumber(10, 25)
		chooseFlightTarget(bird, playerPosition)
	end

	renderBird(bird, Workspace.DistributedGameTime)
end

local function updateFlyingBird(bird, playerPosition, now, deltaTime)
	if now >= bird.targetExpiresAt or (bird.target - bird.position).Magnitude < 7 then
		if now >= bird.fleeUntil and now >= bird.canLandAt and RANDOM:NextNumber() < 0.35 then
			if beginLanding(bird) then
				return
			end
		end

		chooseFlightTarget(bird, playerPosition)
	end

	local toTarget = bird.target - bird.position
	if toTarget.Magnitude > 0.01 then
		local desiredVelocity = toTarget.Unit * bird.speed
		bird.velocity = bird.velocity:Lerp(desiredVelocity, math.clamp(deltaTime * 1.4, 0, 1))
	end

	bird.position += bird.velocity * deltaTime
end

local function updateLandingBird(bird, playerPosition, now, deltaTime)
	if now >= bird.targetExpiresAt then
		beginFlight(bird, false, playerPosition)
		return
	end

	local alpha = math.clamp((now - bird.landingStartedAt) / bird.landingDuration, 0, 1)
	if alpha >= 1 then
		finishLanding(bird)
		return
	end

	local nextPosition = cubicHermite(
		bird.landingStart,
		bird.target,
		bird.landingStartTangent,
		Vector3.zero,
		alpha
	)
	if deltaTime > 0 then
		bird.velocity = (nextPosition - bird.position) / deltaTime
	end
	bird.position = nextPosition
end

local function simulate(playerPosition, now, deltaTime)
	for index = #birds, 1, -1 do
		local bird = birds[index]
		local distanceFromPlayer = (bird.position - playerPosition).Magnitude

		if distanceFromPlayer > DESPAWN_DISTANCE then
			destroyBird(index)
			continue
		end

		if bird.state == "Flying" then
			updateFlyingBird(bird, playerPosition, now, deltaTime)
		elseif bird.state == "Landing" then
			updateLandingBird(bird, playerPosition, now, deltaTime)
		elseif bird.state == "Perched" and now >= bird.stateEndsAt then
			beginFlight(bird, false, playerPosition)
		end

		renderBird(bird, now)
	end
end

local function scareNearbyBirds(playerPosition, now)
	for _, bird in birds do
		if bird.state ~= "Flying" and (bird.position - playerPosition).Magnitude <= SCARE_DISTANCE then
			beginFlight(bird, true, playerPosition)
		elseif bird.state == "Flying" and now >= bird.fleeUntil and (bird.position - playerPosition).Magnitude <= SCARE_DISTANCE * 0.65 then
			beginFlight(bird, true, playerPosition)
		end
	end
end

function BirdController.KnitStart()
	local birdAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Models"):WaitForChild("Birds")
	idleTemplate = birdAssets:WaitForChild("IdleBird")
	flyingTemplate = birdAssets:WaitForChild("FlyingBird")

	local existingFolder = Workspace:FindFirstChild("ClientBirds")
	if existingFolder then
		existingFolder:Destroy()
	end

	clientBirdFolder = Instance.new("Folder")
	clientBirdFolder.Name = "ClientBirds"
	clientBirdFolder.Parent = Workspace

	RunService.Heartbeat:Connect(function(deltaTime)
		if Workspace:GetAttribute("InMainMenu") or not birdsCanSpawn() then
			if #birds > 0 then
				destroyAllBirds()
			end
			spawnAccumulator = 0
			return
		end

		local character = LOCAL_PLAYER.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end

		local now = Workspace.DistributedGameTime
		local playerPosition = rootPart.Position

		simulationAccumulator += math.min(deltaTime, 0.1)
		if simulationAccumulator >= SIMULATION_STEP then
			local simulationDelta = simulationAccumulator
			simulationAccumulator = 0
			simulate(playerPosition, now, simulationDelta)
		end

		scareAccumulator += deltaTime
		if scareAccumulator >= 0.12 then
			scareAccumulator = 0
			scareNearbyBirds(playerPosition, now)
		end

		spawnAccumulator += deltaTime
		if #birds < MAX_BIRDS and spawnAccumulator >= SPAWN_INTERVAL then
			spawnAccumulator = 0
			createBird(playerPosition)
		end
	end)
end

return BirdController
