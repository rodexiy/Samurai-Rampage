return function(Building: any): string
	local Checks = 0
	local Origin = Vector3.new(28000, 500, 28000)
	local Realm = Instance.new("Model")
	Realm.Name = "RealmBuildingGeometryTest"
	Realm:SetAttribute("TerrainCenter", Origin)
	Realm:SetAttribute("TerrainSize", Vector3.one * 64)
	Realm.Parent = workspace
	local Asset = Instance.new("Model")
	local TreeAsset = Instance.new("Model")
	local SmallAsset = Instance.new("Part")
	SmallAsset.Size = Vector3.one * 0.5
	local GridEnabled = Building.GridEnabled

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Part(Name: string, Size: Vector3, Position: Vector3, Parent: Instance): Part
		local Result = Instance.new("Part")
		Result.Name, Result.Size, Result.Position = Name, Size, Position
		Result.Anchored = true
		Result.Parent = Parent

		return Result
	end

	local Success, Error = pcall(function()
		Part("Floor", Vector3.new(60, 2, 60), Origin, Realm)
		Part("Wall", Vector3.new(1, 20, 30), Origin + Vector3.new(20, 10, 0), Realm)
		Part("Body", Vector3.new(4, 4, 4), Vector3.zero, Asset)
		Asset.WorldPivot = CFrame.new(3, -1, 2)
		local Bounds = Building.GetBounds(Asset)
		local Helper = Part("EffectCarrier", Vector3.one * 20, Vector3.new(0, -8, 0), Asset)
		Helper.Transparency = 1
		Helper.CanCollide = false
		local VisibleBounds = Building.GetBounds(Asset)
		Check((VisibleBounds.Size - Bounds.Size).Magnitude < 0.001
			and (VisibleBounds.Offset.Position - Bounds.Offset.Position).Magnitude < 0.001,
			"Invisible noncollidable effect carriers do not enlarge or offset placement bounds")
		Helper.CanCollide = true
		Check(Building.GetBounds(Asset).Size.Y > Bounds.Size.Y, "Invisible collision surfaces remain part of placement bounds")
		Helper:Destroy()
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Include
		Params.FilterDescendantsInstances = { Realm }
		local Hit = workspace:Raycast(Origin + Vector3.new(0.37, 20, 0.42), -Vector3.yAxis * 40, Params)
		assert(Hit, "Test ray must hit floor")

		Check(Building.CanUseSurface(Realm, Hit, Asset), "Accept a realm floor")
		Building.GridEnabled = false
		local Frame = Building.GetPlacement(Asset, Bounds, Hit, 15, Origin)
		local Box = Frame * Bounds.Offset
		Check(math.abs(Box.Position.Y - Bounds.Size.Y / 2 - Hit.Position.Y - 0.025) < 0.002,
			"Seat the bounding box correctly with an offset pivot")
		Check(math.abs(Box.Position.X - Hit.Position.X) < 0.002, "Disabled grid preserves arbitrary coordinates")
		Check(math.abs(Frame.RightVector.Z - math.sin(math.rad(15))) < 0.001, "R rotates clockwise by 15 degrees")
		Check(Building.IsClear(Realm, Bounds, Frame, {}), "Contact with the floor does not count as overlap")
		Check(not Building.IsInside(Realm, CFrame.new(Origin + Vector3.xAxis * 32), Bounds.Size), "Check the entire object at realm edges")

		local Obstacle = Part("Obstacle", Vector3.one * 2, Box.Position, Realm)
		Check(not Building.IsClear(Realm, Bounds, Frame, {}), "Block intersection with collidable parts")
		Obstacle.CanCollide = false
		Check(Building.IsClear(Realm, Bounds, Frame, {}), "Ignore noncollidable visual geometry")
		Obstacle:Destroy()

		Building.GridEnabled = true
		local Snapped = Building.GetPlacement(Asset, Bounds, Hit, 0, Origin) * Bounds.Offset
		Check(math.abs(Snapped.Position.X - Origin.X) < 0.002, "Floor grid snaps relative to realm origin")
		Building.GridEnabled = false

		local WallHit = workspace:Raycast(Origin + Vector3.new(0, 10.37, 0.42), Vector3.xAxis * 30, Params)
		assert(WallHit, "Test ray must hit wall")
		Check(not Building.CanUseSurface(Realm, WallHit, Asset), "Floor assets reject walls")
		Asset:SetAttribute("PlacementType", "Wall")
		Check(not Building.CanUseSurface(Realm, Hit, Asset), "Wall assets reject floors")
		Check(Building.CanUseSurface(Realm, WallHit, Asset), "Wall assets accept vertical realm surfaces")
		local WallFrame = Building.GetPlacement(Asset, Bounds, WallHit, 0, Origin)
		Check(WallFrame.LookVector:Dot(WallHit.Normal) > 0.999, "Wall asset front faces away from the wall")
		Check(Building.IsClear(Realm, Bounds, WallFrame, {}), "A flush wall placement is clear")
		Building.GridEnabled = true
		local WallBox = Building.GetPlacement(Asset, Bounds, WallHit, 0, Origin) * Bounds.Offset
		Check(math.abs(WallBox.Position.Y - (Origin.Y + 10)) < 0.002, "Wall grid snaps within the wall plane")
		Building.GridEnabled = false
		Asset:SetAttribute("PlacementType", "Floor")

		local Objects = Instance.new("Folder")
		Objects.Name = "PlacedObjects"
		Objects.Parent = Realm
		local Table = Instance.new("Model")
		Table.Parent = Objects
		local Top = Part("Top", Vector3.new(8, 1, 8), Origin + Vector3.new(-12, 5, 0), Table)
		local TableHit = workspace:Raycast(Top.Position + Vector3.yAxis * 10, -Vector3.yAxis * 20, Params)
		assert(TableHit, "Test ray must hit table")
		Check(not Building.CanUseSurface(Realm, TableHit, Asset), "Placed objects do not support stacking by default")
		Table:SetAttribute("SupportsPlacement", true)
		Check(Building.CanUseSurface(Realm, TableHit, Asset), "Tables opt in to supporting objects")
		local TableFrame = Building.GetPlacement(Asset, Bounds, TableHit, 0, Origin)
		Check(Building.IsClear(Realm, Bounds, TableFrame, {}), "Placing on top of a table does not overlap it")
		Table:SetAttribute("SupportsPlacement", false)
		Top:SetAttribute("PlacementSurface", "Floor")
		Check(Building.CanUseSurface(Realm, TableHit, Asset), "Explicit support surfaces opt in independently")
		Top.CanCollide = false
		Check(not Building.IsClear(Realm, Bounds, CFrame.new(Top.Position) * Bounds.Offset:Inverse(), {}),
			"Noncollidable placed decorations still block overlap")
		Top.Transparency = 1
		Check(Building.IsClear(Realm, Bounds, CFrame.new(Top.Position) * Bounds.Offset:Inverse(), {}),
			"Invisible noncollidable placed effect carriers do not block other objects")
		Top.CanCollide = true
		Check(not Building.IsClear(Realm, Bounds, CFrame.new(Top.Position) * Bounds.Offset:Inverse(), {}),
			"Invisible collidable support geometry still blocks overlap")

		Part("Trunk", Vector3.new(2, 16, 2), Vector3.new(0, 8, 0), TreeAsset)
		Part("Roots", Vector3.new(4, 2, 4), Vector3.new(0, 1, 0), TreeAsset)
		local Canopy = Part("Canopy", Vector3.new(18, 4, 18), Vector3.new(0, 18, 0), TreeAsset)
		Canopy.CanCollide = false
		TreeAsset.WorldPivot = CFrame.identity
		local TreeBounds = Building.GetBounds(TreeAsset)
		local TreeFrame = CFrame.new(Origin + Vector3.new(8, 1.025, 8))
		local Nearby = Part("NearbyProp", Vector3.one * 2, TreeFrame.Position + Vector3.new(6, 2, 0), Realm)
		Check(Building.IsClear(Realm, TreeBounds, TreeFrame, {}), "A nearby prop can occupy empty space inside a large model's bounds")
		Nearby.Position = TreeFrame.Position + Vector3.new(0, 4, 0)
		Check(not Building.IsClear(Realm, TreeBounds, TreeFrame, {}), "The same prop cannot intersect the trunk")
		Nearby.Position = TreeFrame.Position + Vector3.new(6, 18, 0)
		Check(Building.IsClear(Realm, TreeBounds, TreeFrame, {}), "Noncollidable foliage does not reserve a large placement volume")
		Nearby:Destroy()

		local PlacedTree = TreeAsset:Clone()
		PlacedTree:PivotTo(TreeFrame)
		PlacedTree.Parent = Objects
		local SmallBounds = Building.GetBounds(SmallAsset)
		Check(Building.IsClear(Realm, SmallBounds, TreeFrame * CFrame.new(6, 18, 0), {}),
			"Placing a prop through decorative foliage follows the same rule in reverse")
		Check(not Building.IsClear(Realm, SmallBounds, TreeFrame * CFrame.new(0, 4, 0), {}),
			"A prop still cannot intersect an existing trunk")
		PlacedTree:Destroy()

		local Sphere = Part("CurvedObstacle", Vector3.one * 6, Origin + Vector3.new(0, 10, 20), Objects)
		Sphere.Shape = Enum.PartType.Ball
		Check(Building.IsClear(Realm, SmallBounds, CFrame.new(Sphere.Position + Vector3.new(2.5, 2.5, 0)), {}),
			"Mesh and curved obstacle bounds do not count as solid geometry")
		Check(not Building.IsClear(Realm, SmallBounds, CFrame.new(Sphere.Position + Vector3.new(1, 1, 0)), {}),
			"Actual curved geometry still blocks overlap")
		Sphere:Destroy()

		Check(not Building.IsVector(Vector3.new(0 / 0, 0, 0)), "Reject NaN coordinates")
		Check(not Building.IsVector(Vector3.new(math.huge, 0, 0)), "Reject infinite coordinates")
		Check(Building.Resolve({ Tab = "Invalid", Category = "Chair", Name = "Fake" }) == nil, "Reject unknown catalog tabs")
	end)

	Building.GridEnabled = GridEnabled
	Realm:Destroy()
	Asset:Destroy()
	TreeAsset:Destroy()
	SmallAsset:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " realm building checks passed"
end
