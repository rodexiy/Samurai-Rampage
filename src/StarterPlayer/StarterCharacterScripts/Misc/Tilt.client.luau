local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")
local RootJoint = RootPart:WaitForChild("RootJoint")
local RootC1 = RootJoint.C1

--[[
	Inclina o character em relação a direção que está andando
]]

local MaxTiltAngle = 5
local Tilt = CFrame.new()
local DefaultTilt = CFrame.new()

RunService.RenderStepped:Connect(function(Delta)
	if

		Character:GetAttribute("Ragdoll")
		or Humanoid:GetState() == Enum.HumanoidStateType.Seated
		or Character:GetAttribute("Died")
		or Character:GetAttribute("Downed")
		or Character:GetAttribute("PostureBreak")
		or Character:GetAttribute("Meditating")
	then
		Tilt = DefaultTilt
		RootJoint.C1 = RootC1 * Tilt
		return
	end

	if Character:GetAttribute("Climbing") then
		MaxTiltAngle = 15
	else
		MaxTiltAngle = 10
	end
	local MoveDirection = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
	Tilt = Tilt:Lerp(
		CFrame.Angles(math.rad(-MoveDirection.Z) * MaxTiltAngle, math.rad(-MoveDirection.X) * MaxTiltAngle, 0),
		0.4 ^ (1 / (Delta * 60))
	)
	RootJoint.C1 = RootC1 * (Tilt:Inverse())
end)
