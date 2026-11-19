return function(Controller: any, Wind: any): string
	local Checks = 0
	local Origin = Vector3.new(24000, 500, 24000)
	local Root = Instance.new("Model")
	Root.Name = "RealmWindValidation"
	Root.Parent = workspace
	local Leaf = Instance.new("Part")
	Leaf.Anchored = true
	Leaf.CFrame = CFrame.new(Origin)
	Leaf:AddTag("WindShake")
	Leaf:SetAttribute("WindPower", 0.05)
	Leaf:SetAttribute("WindSpeed", 5)
	Leaf:SetAttribute("WindDirection", Vector3.xAxis)
	Leaf.Parent = Root
	local Bone = Instance.new("Bone")
	Bone.CFrame = CFrame.new(0, 1, 0)
	Bone.Transform = CFrame.Angles(0, 0, 0.1)
	Bone:AddTag("WindShake")
	Bone:SetAttribute("WindPower", 0.05)
	Bone:SetAttribute("WindSpeed", 5)
	Bone:SetAttribute("WindDirection", Vector3.xAxis)
	Bone.Parent = Leaf
	local Fresh = Instance.new("Part")
	Fresh.Anchored = true
	Fresh.CFrame = CFrame.new(Origin)
	Fresh:AddTag("WindShake")
	Fresh.Parent = Root
	local Iterate = Wind.VectorMap.ForEachObjectInView
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Matches(First: CFrame, Second: CFrame): boolean
		return (First.Position - Second.Position).Magnitude < 0.005
			and First.UpVector:Dot(Second.UpVector) > 0.999999 and First.LookVector:Dot(Second.LookVector) > 0.999999
	end

	local Success, Error = pcall(function()
		Wind:AddObjectShake(Leaf)
		Wind:AddObjectShake(Bone)
		local Metadata = Wind.ObjectMetadata[Leaf]
		local Settings, Seed, OldChunk = Metadata.Settings, Metadata.Seed, Metadata.ChunkKey
		local BoneLocal = Bone.CFrame
		local Frame = CFrame.new(Origin + Vector3.new(180, 20, -60)) * CFrame.Angles(math.rad(15), math.rad(30), math.rad(45))
		local BoneFrame = Frame * BoneLocal
		Controller.Rebase(Wind, Bone, BoneFrame)
		Check(Bone.CFrame == BoneLocal, "Rebasing a bone before its parent replicates preserves its authored local frame")
		Check(Bone.Transform == CFrame.identity, "Reset only the bone's local wind animation")
		Controller.Rebase(Wind, Leaf, Frame)
		Check(Matches(Leaf.CFrame, Frame), "Apply the authoritative part frame instead of returning to the old wind origin")
		Check(Matches(Metadata.Origin, Frame) and Matches(Wind.ObjectMetadata[Bone].Origin, BoneFrame),
			"Update part and bone animation origins")
		Check(Metadata.Settings == Settings and Metadata.Seed == Seed, "Keep wind settings and animation seeds")
		Check(Wind.VectorMap:GetVoxel(OldChunk) == nil, "Remove the moved objects from their old spatial region")
		local Voxel = Wind.VectorMap:GetVoxel(Metadata.ChunkKey)
		Check(Voxel ~= nil and table.find(Voxel[Leaf.ClassName], Leaf) ~= nil, "Index the part in its new spatial region")
		Check(Leaf:HasTag("WindShake") and Bone:HasTag("WindShake"), "Keep simulation tags while moving")

		local FreshFrame = CFrame.new(Origin + Vector3.new(-100, 5, 0))
		Controller.Rebase(Wind, Fresh, FreshFrame)
		Check(Wind.ObjectMetadata[Fresh] ~= nil and Matches(Wind.ObjectMetadata[Fresh].Origin, FreshFrame),
			"Handle a move arriving before wind registration")
		Wind.VectorMap.ForEachObjectInView = function(_Map: any, _Camera: Camera, _Distance: number,
			Callback: (string, BasePart | Bone) -> ())
			Callback(Leaf.ClassName, Leaf)
			Callback("Bone", Bone)
		end
		Metadata.LastUpdate = -math.huge
		Wind.ObjectMetadata[Bone].LastUpdate = -math.huge
		Wind:Update(1 / 30)
		Check(Wind.Active == 2, "Exercise the actual WindShake update after rebasing")
		Check((Leaf.Position - Frame.Position).Magnitude < 1 and (Leaf.Position - Origin).Magnitude > 100,
			"The next wind update animates at the new location")
		Check(Bone.CFrame == BoneLocal, "Wind animation keeps the bone's authored attachment frame")
	end)

	Wind.VectorMap.ForEachObjectInView = Iterate
	Wind:RemoveObjectShake(Bone)
	Wind:RemoveObjectShake(Leaf)
	Wind:RemoveObjectShake(Fresh)
	Root:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " realm wind checks passed"
end
