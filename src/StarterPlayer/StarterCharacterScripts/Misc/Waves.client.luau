local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GRID_SIZE = 512
local RECENTER_INTERVAL = 0.25
local VISIBILITY_CHECK_INTERVAL = 0.1

local player = Players.LocalPlayer
local character = script.Parent.Parent.Parent
local rootPart = character:WaitForChild("HumanoidRootPart")
local WaveFunction = require(ReplicatedStorage.Shared.WaveFunction)

local ocean = ReplicatedFirst:WaitForChild("Ocean"):Clone()
local highQuality = ocean:WaitForChild("HighQuality")
assert(highQuality:IsA("BasePart"), "Ocean.HighQuality must be a BasePart")

local function getGridCenter(): Vector3
	local position = rootPart.Position
	return Vector3.new(math.round(position.X / GRID_SIZE) * GRID_SIZE, 0, math.round(position.Z / GRID_SIZE) * GRID_SIZE)
end

local currentGridCenter = getGridCenter()
ocean:PivotTo(CFrame.new(currentGridCenter))
ocean.Parent = Workspace

type BoneData = {
	Bone: Bone,
	RestPosition: Vector3,
}

local bones: { BoneData } = {}
for _, descendant in highQuality:GetDescendants() do
	if descendant:IsA("Bone") then
		table.insert(bones, {
			Bone = descendant,
			RestPosition = highQuality.CFrame:PointToObjectSpace(descendant.WorldPosition),
		})
	end
end

if #bones == 0 then
	warn("Ocean.HighQuality has no Bones; use a skinned MeshPart with Bone descendants for Gerstner deformation")
end

local function pointIsOnScreen(camera: Camera, point: Vector3): boolean
	local viewportPoint, inFront = camera:WorldToViewportPoint(point)
	local viewportSize = camera.ViewportSize

	return inFront
		and viewportPoint.X >= 0
		and viewportPoint.X <= viewportSize.X
		and viewportPoint.Y >= 0
		and viewportPoint.Y <= viewportSize.Y
end

local function rayHitsSurface(camera: Camera, screenX: number, screenY: number): boolean
	local ray = camera:ViewportPointToRay(screenX, screenY)
	local normal = highQuality.CFrame.UpVector
	local denominator = ray.Direction:Dot(normal)

	if math.abs(denominator) < 1e-4 then
		return false
	end

	local distance = (highQuality.Position - ray.Origin):Dot(normal) / denominator
	if distance < 0 then
		return false
	end

	local localHit = highQuality.CFrame:PointToObjectSpace(ray.Origin + ray.Direction * distance)
	local halfSize = highQuality.Size * 0.5
	return math.abs(localHit.X) <= halfSize.X and math.abs(localHit.Z) <= halfSize.Z
end

local function isHighQualityVisible(): boolean
	local camera = Workspace.CurrentCamera
	if not camera or highQuality.Transparency >= 1 or not highQuality:IsDescendantOf(Workspace) then
		return false
	end

	local halfSize = highQuality.Size * 0.5
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local corner = highQuality.CFrame:PointToWorldSpace(Vector3.new(halfSize.X * x, 0, halfSize.Z * z))
			if pointIsOnScreen(camera, corner) then
				return true
			end
		end
	end

	local viewportSize = camera.ViewportSize
	return rayHitsSurface(camera, 0, 0)
		or rayHitsSurface(camera, viewportSize.X, 0)
		or rayHitsSurface(camera, 0, viewportSize.Y)
		or rayHitsSurface(camera, viewportSize.X, viewportSize.Y)
		or rayHitsSurface(camera, viewportSize.X * 0.5, viewportSize.Y * 0.5)
end

local visible = false
local wavesEnabled = player:GetAttribute("Waves") ~= false
local recenterElapsed = RECENTER_INTERVAL
local visibilityElapsed = VISIBILITY_CHECK_INTERVAL
local renderConnection: RBXScriptConnection? = nil
local removingConnection: RBXScriptConnection? = nil
local wavesChangedConnection: RBXScriptConnection? = nil
local cleanedUp = false

local function resetWaves()
	for _, boneData in bones do
		boneData.Bone.Transform = CFrame.identity
	end
end

local function updateWavesSetting()
	wavesEnabled = player:GetAttribute("Waves") ~= false
	if wavesEnabled then
		visibilityElapsed = VISIBILITY_CHECK_INTERVAL
	else
		visible = false
		resetWaves()
	end
end

local function cleanup()
	if cleanedUp then
		return
	end

	cleanedUp = true
	if renderConnection then
		renderConnection:Disconnect()
	end
	if removingConnection then
		removingConnection:Disconnect()
	end
	if wavesChangedConnection then
		wavesChangedConnection:Disconnect()
	end
	ocean:Destroy()
end

renderConnection = RunService.RenderStepped:Connect(function(deltaTime)
	recenterElapsed += deltaTime
	if recenterElapsed >= RECENTER_INTERVAL then
		recenterElapsed = 0
		local nextGridCenter = getGridCenter()
		if nextGridCenter ~= currentGridCenter then
			currentGridCenter = nextGridCenter
			ocean:PivotTo(CFrame.new(currentGridCenter))
		end
	end

	if not wavesEnabled or #bones == 0 then
		return
	end

	visibilityElapsed += deltaTime
	if visibilityElapsed >= VISIBILITY_CHECK_INTERVAL then
		visibilityElapsed = 0
		visible = isHighQualityVisible()
	end

	if not visible then
		return
	end

	local serverTime = Workspace:GetServerTimeNow()
	for _, boneData in bones do
		local samplePosition = highQuality.CFrame:PointToWorldSpace(boneData.RestPosition)
		local worldDisplacement = WaveFunction:GetDisplacement(samplePosition, serverTime)
		boneData.Bone.Transform = CFrame.new(highQuality.CFrame:VectorToObjectSpace(worldDisplacement))
	end
end)

wavesChangedConnection = player:GetAttributeChangedSignal("Waves"):Connect(updateWavesSetting)
updateWavesSetting()

removingConnection = player.CharacterRemoving:Connect(function(removingCharacter)
	if removingCharacter == character then
		cleanup()
	end
end)

script.Destroying:Connect(cleanup)
