local Players = game:GetService("Players")
local Stances = require(game.ReplicatedStorage.Shared.Index.Stances)

local ZERO_VECTOR = Vector3.new(0, 0, 0)

local function ClearAssemblyVelocity(Character: Model)
	for _, Descendant in Character:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.AssemblyLinearVelocity = ZERO_VECTOR
			Descendant.AssemblyAngularVelocity = ZERO_VECTOR
		end
	end
end

local function ShouldSnapLeftArm(Character: Model, Torso: BasePart, LeftArm: BasePart)
	local StanceData = Stances[Character:GetAttribute("Stance")]
	if StanceData and StanceData.LeftArmRagdoll then
		return true
	end

	local LeftShoulder = Torso:FindFirstChild("Left Shoulder")
	if LeftShoulder and LeftShoulder:IsA("Motor6D") and not LeftShoulder.Enabled then
		return true
	end

	return LeftArm:FindFirstChild("ClientLeftArmRagdollAttachment") ~= nil
		or Torso:FindFirstChild("ClientLeftArmRagdollSocket") ~= nil
end

local function SnapLeftArmRagdoll(Character: Model)
	local Torso = Character:FindFirstChild("Torso")
	local LeftArm = Character:FindFirstChild("Left Arm")

	if not Torso or not Torso:IsA("BasePart") or not LeftArm or not LeftArm:IsA("BasePart") then
		return
	end

	if not ShouldSnapLeftArm(Character, Torso, LeftArm) then
		return
	end

	local LeftShoulder = Torso:FindFirstChild("Left Shoulder")
	if LeftShoulder and LeftShoulder:IsA("Motor6D") then
		LeftArm.CFrame = Torso.CFrame * LeftShoulder.C0 * LeftShoulder.C1:Inverse()
	else
		LeftArm.CFrame = Torso.CFrame * CFrame.new(-1.5, 0, 0)
	end

	LeftArm.AssemblyLinearVelocity = ZERO_VECTOR
	LeftArm.AssemblyAngularVelocity = ZERO_VECTOR
end

return function(Character, Pivot: CFrame)
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player then
		Player:RequestStreamAroundAsync(Pivot.Position, 5)
	end
	Character:PivotTo(Pivot)
	SnapLeftArmRagdoll(Character)
	local Head = Character:FindFirstChild("Head")
	local FaceHead = workspace.FaceHeadFolder:FindFirstChild(Character.Name .. "FaceHead")

	if FaceHead and Head then
		FaceHead:PivotTo(Head:GetPivot())
		local FaceHeadWeld = FaceHead:FindFirstChild("FaceHeadWeld")

		if FaceHeadWeld then
			FaceHeadWeld.Enabled = true
		end
	end

	ClearAssemblyVelocity(Character)
end
