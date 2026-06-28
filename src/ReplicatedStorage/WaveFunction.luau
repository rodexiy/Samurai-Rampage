local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveFunction = {}

local TAU = 2 * math.pi
local DEFAULT_GRAVITY_SCALE = 1

-- 0 = flat water, 1 = full wave height.
local WAVE_HEIGHT_SCALE = 0.65

local gravityScale = workspace:GetAttribute("Gravity") or DEFAULT_GRAVITY_SCALE

workspace:GetAttributeChangedSignal("Gravity"):Connect(function()
	gravityScale = workspace:GetAttribute("Gravity") or DEFAULT_GRAVITY_SCALE
end)

type Wave = {
	K: number,
	Speed: number,
	Amplitude: number,
	DirectionX: number,
	DirectionZ: number,
}

local function createWave(wavelength: number, steepness: number, wind: Vector2): Wave
	local k = TAU / wavelength
	local direction = wind.Unit

	return {
		K = k,
		Speed = math.sqrt(9.8 / k),
		Amplitude = steepness / k,
		DirectionX = direction.X,
		DirectionZ = direction.Y,
	}
end

-- These values are built once. The old implementation rebuilt this table and
-- normalized every direction for every bone on every frame.
local WAVES = table.freeze({
	createWave(200, 0.10, Vector2.new(1, 1)),
	createWave(200, 0.10, Vector2.new(-1, 1)),
	createWave(150, 0.08, Vector2.new(0.5, 1)),
	createWave(160, 0.10, Vector2.new(-0.5, -1)),
	createWave(120, 0.09, Vector2.new(1, 0)),
	createWave(170, 0.11, Vector2.new(0, -1)),
	createWave(170, 0.07, Vector2.new(1, -0.5)),
	createWave(140, 0.12, Vector2.new(-1, -0.5)),
})

local areas = {}
local activeWaveZones: Instance? = nil

local function bindWaveZones(waveZones: Instance)
	if waveZones == activeWaveZones then
		return
	end

	activeWaveZones = waveZones
	table.clear(areas)

	for _, child in waveZones:GetChildren() do
		table.insert(areas, child)
	end

	waveZones.ChildAdded:Connect(function(child)
		if waveZones ~= activeWaveZones then
			return
		end

		table.insert(areas, child)
	end)

	waveZones.ChildRemoved:Connect(function(child)
		if waveZones ~= activeWaveZones then
			return
		end

		local index = table.find(areas, child)
		if index then
			table.remove(areas, index)
		end
	end)
end

local function tryBindWaveZones(container: Instance)
	local waveZones = container:FindFirstChild("WaveZones")
	if waveZones then
		bindWaveZones(waveZones)
	end

	container.ChildAdded:Connect(function(child)
		if child.Name == "WaveZones" then
			bindWaveZones(child)
		end
	end)
end

-- Support both locations because OceanService currently refers to Workspace,
-- while older versions of this module looked in ReplicatedStorage.
tryBindWaveZones(ReplicatedStorage)
tryBindWaveZones(workspace)

local function getIntensity(position: Vector3): number
	for _, area in areas do
		if not area:IsA("BasePart") then
			continue
		end

		local radius = area:GetAttribute("Radius")
		local intensity = area:GetAttribute("Intensity")
		if typeof(radius) ~= "number" or radius <= 0 or typeof(intensity) ~= "number" then
			continue
		end

		local offset = position - area.Position
		local distanceSquared = offset:Dot(offset)
		if distanceSquared <= radius * radius then
			local alpha = 1 - math.sqrt(distanceSquared) / radius
			return 1 + (intensity - 1) * alpha
		end
	end

	return 1
end

function WaveFunction:GetDisplacement(position: Vector3, serverTime: number): Vector3
	local intensity = getIntensity(position)
	local x = 0
	local y = 0
	local z = 0

	for _, wave in WAVES do
		local phase = wave.K
			* (wave.DirectionX * position.X + wave.DirectionZ * position.Z - wave.Speed * serverTime * gravityScale)
		local horizontal = wave.Amplitude * intensity * math.cos(phase)

		x += wave.DirectionX * horizontal
		y += wave.Amplitude * intensity * math.sin(phase) * WAVE_HEIGHT_SCALE
		z += wave.DirectionZ * horizontal
	end

	return Vector3.new(x, y, z)
end

function WaveFunction:GetGerstner(position: Vector3, serverTime: number): CFrame
	return CFrame.new(self:GetDisplacement(position, serverTime))
end

-- Preserve the existing API for any callers outside this repository.
WaveFunction.getgerstner = WaveFunction.GetGerstner

return WaveFunction
