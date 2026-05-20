local RunService = game:GetService("RunService")

local Player = game.Players.LocalPlayer

local Camera = workspace.CurrentCamera

local Character = Player.Character or Player.CharacterAdded:Wait()

local Head = Character:WaitForChild("Head")

local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local Torso = Character:WaitForChild("Torso")
local Neck = Torso:WaitForChild("Neck")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local Waist = HumanoidRootPart:WaitForChild("RootJoint")

local RHip = Torso:WaitForChild("Right Hip")
local LHip = Torso:WaitForChild("Left Hip")

local LHipOriginC0 = LHip.C0
local RHipOriginC0 = RHip.C0

local NeckOriginC0 = Neck.C0
local WaistOriginC0 = Waist.C0

Neck.MaxVelocity = 1 / 3

RunService.RenderStepped:Connect(function(Delta)
	local LerpSpeed = 0.4 ^ (1 / (Delta * 60))

	if Character:FindFirstChild("Torso") and Character:FindFirstChild("Head") then
		local TorsoLookVector = Torso.CFrame.lookVector
		local HeadPosition = Head.CFrame.p

		if
			not Player:GetAttribute("FollowCamera")
			or Character:GetAttribute("Climbing")
			or Character:GetAttribute("Meditating")
		then
			Neck.C0 = Neck.C0:lerp(NeckOriginC0, LerpSpeed)
			Waist.C0 = Waist.C0:lerp(WaistOriginC0, LerpSpeed)
			LHip.C0 = LHip.C0:lerp(LHipOriginC0, LerpSpeed)
			RHip.C0 = RHip.C0:lerp(RHipOriginC0, LerpSpeed)
			return
		end

		if Neck and Waist then
			if Camera.CameraSubject:IsDescendantOf(Character) or Camera.CameraSubject:IsDescendantOf(Player) then
				local Point = (Camera.CFrame * CFrame.new(0, 0, -1000)).Position

				local Distance = (Head.CFrame.p - Point).magnitude
				local Difference = Head.CFrame.Y - Point.Y

				local goalNeckCFrame = CFrame.Angles(
					-(math.atan(Difference / Distance) * 0.5),
					(((HeadPosition - Point).Unit):Cross(RootPart.CFrame.LookVector)).Y * 1,
					0
				)

				local xAxisWaistRotation = -(math.atan(Difference / Distance) * 0.5)
				local yAxisWaistRotation = (((HeadPosition - Point).Unit):Cross(Torso.CFrame.LookVector)).Y * 0.5
				local rotationWaistCFrame = CFrame.Angles(xAxisWaistRotation, yAxisWaistRotation, 0)
				local goalWaistCFrame = rotationWaistCFrame * WaistOriginC0
				Waist.C0 = Waist.C0:lerp(goalWaistCFrame, LerpSpeed).Rotation + WaistOriginC0.Position

				Neck.C0 = Neck.C0:lerp(goalNeckCFrame * NeckOriginC0, LerpSpeed).Rotation + NeckOriginC0.Position

				local currentLegCounterCFrame = Waist.C0 * WaistOriginC0:Inverse()
				local legsCounterCFrame = currentLegCounterCFrame:Inverse()
				RHip.C0 = legsCounterCFrame * RHipOriginC0
				LHip.C0 = legsCounterCFrame * LHipOriginC0
			end
		end
	end
end)
