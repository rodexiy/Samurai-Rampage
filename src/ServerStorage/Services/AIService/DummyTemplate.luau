local DummyTemplate = {}

local BodyParts = {
	HumanoidRootPart = true,
	Head = true,
	Torso = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

function DummyTemplate.Ensure(Mobs: Folder): Model?
	local Existing = Mobs:FindFirstChild("Dummy")
	if Existing and Existing:IsA("Model") then
		return Existing
	end

	local Source = Mobs:FindFirstChild("Bandit")
	if not Source or not Source:IsA("Model") then
		return nil
	end

	local Dummy = Source:Clone()
	Dummy.Name = "Dummy"
	for Attribute in Dummy:GetAttributes() do
		Dummy:SetAttribute(Attribute, nil)
	end
	for _, Tag in Dummy:GetTags() do
		Dummy:RemoveTag(Tag)
	end

	for _, Child in Dummy:GetChildren() do
		if Child:IsA("BasePart") then
			if not BodyParts[Child.Name] then
				Child:Destroy()
			else
				Child.Anchored = false
				Child.Color = Color3.fromRGB(163, 162, 165)
				for _, Tag in Child:GetTags() do
					Child:RemoveTag(Tag)
				end
			end
		elseif not Child:IsA("Humanoid") and not Child:IsA("BodyColors") then
			Child:Destroy()
		end
	end

	for _, Script in Dummy:QueryDescendants("LuaSourceContainer") do
		Script:Destroy()
	end
	for _, Joint: Motor6D in Dummy:QueryDescendants("Motor6D") do
		if not Joint.Part0 or not Joint.Part1 then
			Joint:Destroy()
		end
	end

	local Humanoid = Dummy:FindFirstChildWhichIsA("Humanoid")
	if not Humanoid or not Dummy.PrimaryPart then
		Dummy:Destroy()
		return nil
	end

	Humanoid.DisplayName = "Dummy"
	Humanoid.WalkSpeed = 0
	Humanoid.JumpPower = 0
	Humanoid.AutoRotate = false
	Dummy:SetAttribute("HitboxType", "R6")
	Dummy:SetAttribute("IsDummy", true)
	Dummy:SetAttribute("NoRewards", true)
	Dummy:AddTag("Entity")
	Dummy:PivotTo(CFrame.new())
	Dummy.Parent = Mobs
	return Dummy
end

return DummyTemplate
