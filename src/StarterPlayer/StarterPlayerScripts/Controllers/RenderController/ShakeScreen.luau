local Debris = game:GetService("Debris")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RenderController = Knit.GetController("RenderController")
local SoundEffectController = Knit.GetController("SoundEffectController")
local CameraController = Knit.GetController("CameraController")

local ShakeScreen = {}

local Player = game.Players.LocalPlayer
function easeOutQuint(t)
	return 1 - math.pow(1 - t, 5)
end

function easeOutExpo(x: number): number
	return x == 1 and 1 or 1 - math.pow(2, -10 * x)
end

function ShakeScreen.Explosion(RenderData)
	local position: CFrame = RenderData.Position
	local size: Vector3 = RenderData.Size or 0.1
	local MaxDistance = RenderData.MaxDistance or 80
	local Duration = RenderData.Duration or 0.1

	local function Shake()
		local Distance = (Player.Character:GetPivot().Position - position).Magnitude
		if Distance == 0 then
			Distance = 1
		end

		-- Normalize distance (0 when close, 1 when at max distance)
		local t = math.clamp(Distance / MaxDistance, 0, 1)
		local easedFactor = 1.05 - easeOutExpo(t) -- Invert so it decreases over distance

		local Magnitude = size * easedFactor * 2

		if Magnitude <= 0.1 then
			return
		end

		CameraController:ShakeOnce(Magnitude, 10, 0.1, 0.1)
	end
	if Duration then
		for i = 0, Duration, 0.1 do
			Shake()
			task.wait(0.1)
		end
	else
		Shake()
	end
end

return ShakeScreen
