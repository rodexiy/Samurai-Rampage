local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CharacterShared = require(ReplicatedStorage.Shared.CharacterShared)

local Character = script.Parent.Parent :: Model
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
CharacterShared:ChangeWalkSpeed(Character)

local TargetWalkSpeed = Character:GetAttribute("TargetWalkSpeed") :: number
local SpeedIncreaseRate = 1.65
local SpeedDecreaseRate = 5

Character:GetAttributeChangedSignal("TargetWalkSpeed"):Connect(function()
	TargetWalkSpeed = Character:GetAttribute("TargetWalkSpeed") :: number
end)

RunService.RenderStepped:Connect(function(DeltaTime: number)
	local WalkSpeed = Humanoid.WalkSpeed
	if Humanoid.MoveDirection.Magnitude == 0 then
		Humanoid.WalkSpeed = math.clamp(WalkSpeed - TargetWalkSpeed * SpeedDecreaseRate * DeltaTime, 0, TargetWalkSpeed)
		return
	end

	if WalkSpeed > TargetWalkSpeed and TargetWalkSpeed == CharacterShared:GetM1WalkSpeed(Character) then
		local DefaultWalkSpeed = Character:GetAttribute("DefaultWalkSpeed") or 12
		Humanoid.WalkSpeed = math.max(TargetWalkSpeed, WalkSpeed - DefaultWalkSpeed * SpeedDecreaseRate * DeltaTime)
		return
	end

	Humanoid.WalkSpeed = math.min(WalkSpeed + TargetWalkSpeed * SpeedIncreaseRate * DeltaTime, TargetWalkSpeed)
end)
