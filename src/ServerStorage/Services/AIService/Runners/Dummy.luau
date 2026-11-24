local Dummy = {}

function Dummy.Start(_Config: { [string]: any })
	local Character = script.Parent :: Model
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if not Humanoid then
		return
	end

	Character:SetAttribute("IsDummy", true)
	Character:SetAttribute("NoRewards", true)
	Character:SetAttribute("Running", false)
	Character:SetAttribute("Blocking", false)
	Character:SetAttribute("DefaultWalkSpeed", 0)
	Character:SetAttribute("RunningWalkSpeed", 0)
	Character:SetAttribute("DefaultJumpPower", 0)
	Character:SetAttribute("SpawnCFrame", Character:GetPivot())
	Humanoid.WalkSpeed = 0
	Humanoid.JumpPower = 0
	Humanoid.AutoRotate = false
	Humanoid:Move(Vector3.zero)

	Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if not Character:GetAttribute("Ragdoll") then
			Humanoid.AutoRotate = false
			Humanoid:Move(Vector3.zero)
		end
	end)
end

return Dummy
