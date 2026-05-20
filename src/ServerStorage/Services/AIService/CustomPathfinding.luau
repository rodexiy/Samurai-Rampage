local Path = {}
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local ServerStorage = game:GetService("ServerStorage")
local EntityFolder = workspace:FindFirstChild("Entity")

type Callback = (item: any) -> nil
type Character = Model
Path.Break = false

local function getClosestNode(position, nodes)
	local closestNode = nil
	local minDist = math.huge
	for _, node in pairs(nodes) do
		local dist = (node.Position - position).Magnitude
		if dist < minDist then
			closestNode = node
			minDist = dist
		end
	end
	return closestNode
end

local function getNeighbors(currentNode, nodes)
	local neighbors = {}

	for _, node in pairs(nodes) do
		if node ~= currentNode then
			local dist = (node.Position - currentNode.Position).Magnitude
			if dist < 100 then -- Ajuste esse valor para definir conexão entre nós
				table.insert(neighbors, node)
			end
		end
	end
	return neighbors
end

local function heuristic(nodeA, nodeB)
	return (nodeA.Position - nodeB.Position).Magnitude
end

local function reconstructPath(cameFrom, current, debugMode)
	local totalPath = { current.Position }
	while cameFrom[current] do
		current = cameFrom[current]
		table.insert(totalPath, 1, current.Position)
	end

	if debugMode then
		print("✅ Caminho reconstruído! Tamanho:", #totalPath)
	end

	-- Se o modo debug estiver ativado, cria partes neon amarelas no caminho
	if debugMode then
		for _, pos in pairs(totalPath) do
			local part = Instance.new("Part")
			part.Size = Vector3.new(1, 1, 1)
			part.Position = pos
			part.Color = Color3.fromRGB(255, 255, 0) -- Amarelo
			part.Material = Enum.Material.Neon
			part.Anchored = true
			part.CanCollide = false
			part.Parent = workspace

			-- Faz a parte desaparecer depois de 5 segundos
			Debris:AddItem(part, 30)
		end
	end

	return totalPath
end

-- Cria um caminho seguro entre dois pontos usando PathfindingService
local function createSafePath(startPos, endPos, debug)
	if not endPos then
		return
	end
	local path = PathfindingService:CreatePath({
		AgentRadius = 2, -- Ajuste conforme o tamanho do NPC
		AgentHeight = 5,
		AgentCanJump = true,
	})
	path:ComputeAsync(startPos, endPos)

	if path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	else
		return nil
	end
end

function Path:FindClosestGuardInTheVillage(Character: Model)
	if not Character:GetAttribute("NodeLocation") then
		return
	end
	local final_char
	local min_dist = math.huge

	for _, char: Model in pairs(EntityFolder:GetChildren()) do
		if
			char:GetAttribute("Job") == "Guard"
			and char:GetAttribute("NodeLocation") == Character:GetAttribute("NodeLocation")
		then
			if (char.PrimaryPart.Position - Character.PrimaryPart.Position).Magnitude < min_dist then
				min_dist = char.PrimaryPart.Position
				final_char = char
			end
		end
	end

	return final_char
end

function Path:FindPlayersInRadius(Character, callback: (Character) -> nil)
	local PlayerT = {}
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Character }

	local partsInRadius = workspace:GetPartBoundsInRadius(Character.PrimaryPart.Position, 30, params)

	for _, part in pairs(partsInRadius) do
		local character = part.Parent
		if character and character:FindFirstChild("Humanoid") then
			local player = game.Players:GetPlayerFromCharacter(character)

			if player then
				table.insert(PlayerT, player)
			end
		end
	end

	if callback then
		for i, v in pairs(PlayerT) do
			callback(v)
		end
	end
end

function Path:MoveTo(npc, pathPoints, callback: Callback): nil
	if npc:GetAttribute("Ragdoll") then
		return
	end

	if npc:GetAttribute("Downed") then
		return
	end

	for i = 1, #pathPoints - 1 do
		local safePath = createSafePath(pathPoints[i], pathPoints[i + 1])
		if safePath then
			for _, waypoint in ipairs(safePath) do
				if self.Break then
					return
				end
				if waypoint.Action == Enum.PathWaypointAction.Jump then
					npc.Jump = true
				end
				npc:MoveTo(waypoint.Position)
				npc.MoveToFinished:Wait()
			end
		else
			warn("Erro ao criar caminho seguro entre pontos")
			break
		end
	end

	if callback then
		callback()
	end
end

function Path:FindPath(startPos, endPos, nodes, debugMode: boolean?)
	local startNode = getClosestNode(startPos, nodes)
	local endNode = getClosestNode(endPos, nodes)

	if not startNode or not endNode then
		print("❌ ERRO: Nós inicial ou final não encontrados!")
		return {}
	end

	if debugMode then
		print("🚀 Buscando caminho de", startNode.Name, "até", endNode.Name)
	end

	local openSet = { [startNode] = true }
	local cameFrom = {}

	local gScore = { [startNode] = 0 }
	local fScore = { [startNode] = heuristic(startNode, endNode) }

	local openSetList = { startNode } -- Para garantir que o algoritmo não pare antes da hora

	while #openSetList > 0 do
		-- Escolhe o nó com o menor fScore
		local currentIndex = 1
		local current = openSetList[currentIndex]

		for i, node in ipairs(openSetList) do
			if fScore[node] < fScore[current] then
				currentIndex = i
				current = node
			end
		end

		table.remove(openSetList, currentIndex) -- Remove o nó explorado

		if current == endNode then
			return reconstructPath(cameFrom, current, debugMode)
		end

		openSet[current] = nil -- Remove da lista de nós a explorar

		for _, neighbor in pairs(getNeighbors(current, nodes)) do
			local tentativeGScore = gScore[current] + heuristic(current, neighbor)

			if not gScore[neighbor] or tentativeGScore < gScore[neighbor] then
				cameFrom[neighbor] = current
				gScore[neighbor] = tentativeGScore
				fScore[neighbor] = tentativeGScore + heuristic(neighbor, endNode)

				if not openSet[neighbor] then
					openSet[neighbor] = true
					table.insert(openSetList, neighbor)
				end
			end
		end
	end

	return {} -- Se não encontrou um caminho, retorna um caminho vazio
end

return Path
