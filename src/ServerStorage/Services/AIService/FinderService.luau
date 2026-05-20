local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local FinderService = Knit.CreateService({
	Name = "FinderService",
	Client = {},
})

function FinderService:IsOnDot(from: Humanoid, humanoid: Humanoid, debug): boolean
	if not humanoid:IsDescendantOf(workspace) then
		return false
	end

	local npcToCharacter = (humanoid.RootPart.Position - from.RootPart.Position).Unit :: Vector3
	local npcLook = from.RootPart.CFrame.LookVector

	local dotProduct = npcToCharacter:Dot(npcLook)

	if debug then
		local hasDot = tostring(dotProduct):find(".")
		local isNegative = dotProduct < 0

		local sub = 1
		if isNegative then
			sub += 1
		end
		if hasDot then
			sub += 2
		end

		local dot = tostring(dotProduct)
		if hasDot then
			dot = dot:sub(1, dot:find(".") + sub)
		end
	end

	if dotProduct > 0.5 then
		return dotProduct
	else
		return false
	end
end

function FinderService:GetClosestTarget(
	Character: Model,
	MaxDistance: number?,
	OtherAIs: boolean?,
	DetectionCFrame: CFrame?
)
	local MaxDistance = MaxDistance or math.huge
	local DetectionCFrame = DetectionCFrame or Character:GetPivot()
	local Target
	local ClosestDistance

	local function CheckCandidate(Entity: Model)
		if not Entity then
			return
		end
		if Entity == Character then
			return
		end
		if Entity:GetAttribute("Died") then
			return
		end
		if Entity:GetAttribute("ForceField") then
			return
		end

		local Distance = (Entity:GetPivot().Position - DetectionCFrame.Position).Magnitude
		if Distance > MaxDistance then
			return
		end

		if ClosestDistance == nil or Distance < ClosestDistance then
			ClosestDistance = Distance
			Target = Entity
		end
	end

	for _, Player in Players:GetPlayers() do
		CheckCandidate(Player.Character)
	end

	if OtherAIs then
		for _, Entity in workspace.Entity:GetChildren() do
			if Entity:GetAttribute("IsAI") then
				CheckCandidate(Entity)
			end
		end
	end

	return Target, ClosestDistance
end

function FinderService.KnitInit() end

function FinderService.KnitStart() end

return FinderService
