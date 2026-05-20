local Knit = require(game.ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local CameraController = Knit.GetController("CameraController")
local DamageService = Knit.GetService("DamageService")
local SkillTreeController = Knit.GetController("SkillTreeController")

local Character = script.Parent.Parent.Parent
local Humanoid: Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local function landed()
	local Velocity = Humanoid.RootPart.Velocity.Y
	if Velocity > 0 then
		return
	end

	local Velocity = math.abs(Velocity)

	if Velocity > 130 then
		CameraController:ShakeOnce(Velocity / 170, 10, 0.1, 0.1)

		DamageService:FallDamage(Velocity)
	end
end

Humanoid.StateChanged:Connect(function(old, new)
	if new == Enum.HumanoidStateType.Landed then
		landed()
	end
end)
