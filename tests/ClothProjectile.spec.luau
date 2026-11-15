-- Run in a client playtest with two tagged fixtures and an untagged control.
return function(Controller: any, Fixture: Folder): string
	local AssetService = game:GetService("AssetService")
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Area(Editable: EditableMesh, Scale: Vector3): number
		local Total = 0
		for _, Face in Editable:GetFaces() do
			local Vertices = Editable:GetFaceVertices(Face)
			local A = Editable:GetPosition(Vertices[1]) * Scale
			local B = Editable:GetPosition(Vertices[2]) * Scale
			local C = Editable:GetPosition(Vertices[3]) * Scale
			Total += (B - A):Cross(C - A).Magnitude * 0.5
		end

		return Total
	end

	for Index, Name in { "ArrowCloth", "BulletCloth", "UntaggedCloth" } do
		local Mesh = Fixture:FindFirstChild(Name):FindFirstChildWhichIsA("MeshPart") :: MeshPart
		local Source = AssetService:CreateEditableMeshAsync(Mesh.MeshContent, { FixedSize = true })
		assert(Source, "The fixture mesh must be editable")
		local Scale = Mesh.Size / Mesh.MeshSize
		local BindPoses: { [string]: CFrame } = {}
		for _, Id in Source:GetBones() do
			local Bind = Source:GetBoneCFrame(Id)
			BindPoses[Source:GetBoneName(Id)] = CFrame.new(Bind.Position * Scale) * Bind.Rotation
		end
		for _, Bone in Mesh:QueryDescendants("Bone") :: { Bone } do
			local Bind = BindPoses[Bone.Name]
			if Bind then
				local Parent = Bone.Parent
				local ParentBind = if Parent:IsA("Bone") then BindPoses[Parent.Name] else CFrame.identity
				Bone.CFrame = ParentBind:ToObjectSpace(Bind)
				Bone.Transform = CFrame.identity
			end
		end
		task.wait()

		local Center = Vector3.zero
		local Normal = Vector3.zero
		local Nearest = math.huge
		for _, Face in Source:GetFaces() do
			local Vertices = Source:GetFaceVertices(Face)
			local A = Source:GetPosition(Vertices[1]) * Scale
			local B = Source:GetPosition(Vertices[2]) * Scale
			local C = Source:GetPosition(Vertices[3]) * Scale
			local Point = (A + B + C) / 3
			if Point.Magnitude < Nearest then
				Nearest = Point.Magnitude
				Center = Point
				Normal = (B - A):Cross(C - A).Unit
			end
		end

		local OriginalArea = Area(Source, Scale)
		local WorldCenter = Mesh.CFrame:PointToWorldSpace(Center)
		local WorldNormal = Mesh.CFrame:VectorToWorldSpace(Normal)
		local Origin, Displacement = WorldCenter - WorldNormal * 3, WorldNormal * 6
		local FirstBone = Mesh:FindFirstChildWhichIsA("Bone", true) :: Bone
		local BoneCount = #Mesh:QueryDescendants("Bone")
		local Texture = Mesh.TextureContent
		local Hits = {}
		Check(not Controller:HitByProjectile(Origin, Vector3.zero, Index == 2, {}), "Zero-length segments must be ignored")
		Check(not Controller:HitByProjectile(Origin, Displacement * 0.2, Index == 2, {}), "Clipped segments cannot hit cloth behind an obstacle")
		local Hit = Controller:HitByProjectile(Origin, Displacement, Index == 2, Hits)
		if Index == 3 then
			Check(not Hit and Mesh.MeshContent.Object == nil, "Untagged cloth must remain unchanged")
			Source:Destroy()
			continue
		end

		Check(Hit and Hits[Mesh] == true, "Both bows and firearms must punch tagged cloth")
		local Editable = Mesh.MeshContent.Object :: EditableMesh
		Check(Editable ~= nil, "A hole must use a client-side editable mesh")
		Check(#Mesh:QueryDescendants("Bone") == BoneCount and FirstBone:IsDescendantOf(Mesh), "Applying a hole must preserve the existing SmartBone skeleton")
		Check(Mesh.TextureContent == Texture, "Applying a hole must preserve the texture")
		local Radius = if Index == 2 then 0.3 else 0.18
		local ExpectedArea = 12 * Radius * Radius * math.sin(math.pi * 2 / 12) * 0.5
		local RemovedArea = OriginalArea - Area(Editable, Scale)
		Check(math.abs(RemovedArea - ExpectedArea) < 0.003, "Hole size must remain consistent on coarse skinned geometry")
		Check(not Controller:HitByProjectile(Origin, Displacement, Index == 2, {}), "Later projectiles must pass through an existing hole")
		Check(not Controller:HitByProjectile(Origin + Vector3.yAxis, Displacement, Index == 2, Hits), "One projectile must not cut the same cloth repeatedly")

		for _, Vertex in Editable:GetVertices() do
			local Weights = Editable:GetVertexBoneWeights(Vertex)
			local Total = 0
			for _, Weight in Weights do
				Total += Weight
			end
			Check(#Weights <= 4 and math.abs(Total - 1) < 4 / 255 + 1e-5,
				"New vertices must retain normalized bone weights within the engine's 8-bit quantization")
		end

		-- Moving a root bone without moving the MeshPart must move the hit surface too.
		FirstBone.CFrame += Vector3.yAxis * 20
		task.wait()
		Check(not Controller:HitByProjectile(Origin + Vector3.yAxis, Displacement, Index == 2, {}), "Shots at the old surface must miss after skeletal deformation")
		Check(Controller:HitByProjectile(Origin + Vector3.yAxis * 21, Displacement, Index == 2, {}), "Projectile hits must follow the deformed skeleton")
		Source:Destroy()
	end

	return string.format("Cloth projectiles: %d checks passed", Checks)
end
