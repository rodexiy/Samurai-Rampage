local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WaveFunction = {}

local Gravity = workspace:GetAttribute("Gravity") or 1

workspace:GetAttributeChangedSignal("Gravity"):Connect(function()
	Gravity = workspace:GetAttribute("Gravity")
end)

function WaveFunction:GerstnerWave(pos, delta, wavelength, steepness, globalWind)
	local k = 2 * math.pi / wavelength
	local c = math.sqrt(9.8 / k)
	local d = globalWind.Unit
	local f = k * (d:Dot(Vector2.new(pos.X, pos.Z)) - c * (delta * Gravity))
	local a = steepness / k

	return Vector3.new(d.X * (a * math.cos(f)), a * math.sin(f), d.Y * (a * math.cos(f)))
end

local WaveZones = ReplicatedStorage:FindFirstChild("WaveZones")

local Areas = {}
if WaveZones then
	local Areas = WaveZones:GetChildren()
	WaveZones.ChildAdded:Connect(function(child)
		table.insert(Areas, child)
	end)

	WaveZones.ChildRemoved:Connect(function(child)
		for k, area in Areas do
			if area == child then
				table.remove(Areas, k)
				break
			end
		end
	end)
end

local function getIntensity(pos)
	for _, area in Areas do
		local center = area.Position
		local radius = area:GetAttribute("Radius")

		local distance = (pos - center).Magnitude
		if distance <= radius then
			local intensity = area:GetAttribute("Intensity")
			local fadeIntensity = intensity * (distance / radius)
			return fadeIntensity
		end
	end
end

function WaveFunction:getgerstner(pos, delta)
	local totalWave = Vector3.new(0, 0, 0)

	local Intensity = 1
	local _intensity = getIntensity(pos)
	if _intensity then
		Intensity = _intensity
	end

	local waves = {
		{ Wavelength = 200, Steepness = 0.10 * Intensity, GlobalWind = Vector2.new(1, 1) },
		{ Wavelength = 200, Steepness = 0.10 * Intensity, GlobalWind = Vector2.new(-1, 1) },
		{ Wavelength = 150, Steepness = 0.08 * Intensity, GlobalWind = Vector2.new(0.5, 1) },
		{ Wavelength = 160, Steepness = 0.10 * Intensity, GlobalWind = Vector2.new(-0.5, -1) },
		{ Wavelength = 120, Steepness = 0.09 * Intensity, GlobalWind = Vector2.new(1, 0) },
		{ Wavelength = 170, Steepness = 0.11 * Intensity, GlobalWind = Vector2.new(0, -1) },
		{ Wavelength = 170, Steepness = 0.07 * Intensity, GlobalWind = Vector2.new(1, -0.5) },
		{ Wavelength = 140, Steepness = 0.12 * Intensity, GlobalWind = Vector2.new(-1, -0.5) },
	}

	for _, wave in waves do
		totalWave = totalWave + WaveFunction:GerstnerWave(pos, delta, wave.Wavelength, wave.Steepness, wave.GlobalWind)
	end

	return CFrame.new(totalWave)
end

return WaveFunction
