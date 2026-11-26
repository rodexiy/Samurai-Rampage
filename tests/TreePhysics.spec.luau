return function(Service: any, Template: Model, Done: (boolean, string) -> ())
	local AssetService = game:GetService("AssetService")
	local PhysicsService = game:GetService("PhysicsService")
	local Folder = Instance.new("Folder")
	Folder.Name = "TreePhysicsTest"
	Folder.Parent = workspace
	local Floor = Instance.new("Part")
	Floor.Size = Vector3.new(80, 2, 80)
	Floor.CFrame = CFrame.new(0, 4999, 0)
	Floor.Anchored = true
	Floor.Parent = Folder
	local Entity = Instance.new("Model")
	local Blocker = Instance.new("Part")
	Blocker.Size = Vector3.new(80, 3, 80)
	Blocker.CFrame = CFrame.new(0, 5002, 0)
	Blocker.Anchored = true
	Blocker.Parent = Entity
	Instance.new("Humanoid").Parent = Entity
	Entity.Parent = Folder
	Service:TrackEntity(Entity)
	local Tree = Template:Clone()
	Tree:PivotTo(CFrame.new(0, 5000, 0) * Tree:GetPivot().Rotation)
	for _, Part in Tree:QueryDescendants("BasePart") :: { BasePart } do
		Part.Anchored = true
		Part.CanCollide = false
	end
	Tree.Parent = Folder
	local Point = Tree:GetPivot().Position + Vector3.new(0, 3, 0)
	local Root = Service:CreateBody(Tree, Point, 0.7)
	local Start = Root.CFrame
	local Collider = Root.Parent:FindFirstChild("TreeWorldCollider") :: MeshPart
	local Checks = 0

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		Check(Service:IsPrepared(Tree), "Prepare the collider before releasing the tree")
		Check(Collider.Anchored and Root.Anchored, "Prepared bodies stay anchored until the final hit")
		Check(Service:CreateBody(Tree, Point, 0.7) == Root, "Reuse the prepared collider instead of rebuilding it")
		local Respawn = Tree:Clone()
		Check(
			Respawn:FindFirstChild("TreePhysicsBody") == nil and Respawn:FindFirstChild("FallingBody") == nil,
			"Do not clone prepared physics into the respawn template"
		)
		Respawn:Destroy()
		Service:Release(Root, Vector3.xAxis)
		Check(not Root.Anchored and not Collider.Anchored, "Release the complete tree assembly")
		Check(Root:GetNetworkOwner() == nil, "Keep authoritative physics on the server")
		Check(Collider:CanCollideWith(Floor), "Collide with the world")
		Check(not Collider:CanCollideWith(Blocker), "Ignore an NPC even when its parts started in Default")
		for _, Group in { "Entity", "BigEntity", "ForceField", "Carried", "HorseMount", "WanderingNpc" } do
			if PhysicsService:IsCollisionGroupRegistered(Group) then
				Check(
					not PhysicsService:CollisionGroupsAreCollidable(Collider.CollisionGroup, Group),
					"Ignore " .. Group
				)
			end
		end
	end)
	if not Success then
		Folder:Destroy()
		Done(false, tostring(Error))
		return
	end

	task.delay(4, function()
		local Passed, Failure = pcall(function()
			Check((Root.Position - Start.Position).Magnitude > 1, "Move under real physics")
			Check(Root.CFrame.UpVector:Dot(Start.UpVector) < 0.9, "Tip toward the damaged side")
			local Mesh = AssetService:CreateEditableMeshAsync(Collider.MeshContent)
			assert(Mesh, "Could not inspect the physics collider")
			local MinY = math.huge
			local Scale = Collider.Size / Collider.MeshSize
			for _, Vertex in Mesh:GetVertices() do
				MinY = math.min(MinY, Collider.CFrame:PointToWorldSpace(Mesh:GetPosition(Vertex) * Scale).Y)
			end
			Mesh:Destroy()
			Check(MinY > 4999.7 and MinY < 5001, "Pass through the NPC blocker and rest on the world floor")
		end)
		Folder:Destroy()
		Done(Passed, if Passed then tostring(Checks) .. " tree physics checks passed" else tostring(Failure))
	end)
end
