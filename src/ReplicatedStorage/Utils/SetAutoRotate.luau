return function(Character: Model, Value: boolean)
	local Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then
		return
	end
	if
		Value
		and not Character:GetAttribute("Ragdoll")
		and not Humanoid:GetAttribute("PostureBreak")
		and not Humanoid:GetAttribute("HeavyDeflect")
		and not Character:GetAttribute("Climbing")
	then
		Humanoid.AutoRotate = true
	else
		Humanoid.AutoRotate = false
	end
end
