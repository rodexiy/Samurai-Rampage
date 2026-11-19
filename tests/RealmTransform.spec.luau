return function(Building: any, Service: any, History: any, Context: any): string
	local Checks = 0
	local Center = Vector3.new(26000, 500, 26000)
	local Realm = Instance.new("Model")
	Realm.WorldPivot = CFrame.new(Center)
	Realm:SetAttribute("OwnerId", 90003)
	Realm:SetAttribute("Loaded", true)
	Realm:SetAttribute("TerrainCenter", Center)
	Realm:SetAttribute("TerrainSize", Vector3.one * 64)
	local Objects = Instance.new("Folder")
	Objects.Name = "PlacedObjects"
	Objects.Parent = Realm
	local Character = Instance.new("Model")
	Character:SetAttribute("InRealm", true)
	Character.Parent = Realm
	local Root = Instance.new("Part")
	Root.Anchored = true
	Root.Position = Center + Vector3.yAxis * 20
	Root.Parent = Character
	Character.PrimaryPart = Root
	Instance.new("Humanoid").Parent = Character
	local Object = Instance.new("Part")
	Object.Anchored = true
	Object.Size = Vector3.new(2, 3, 4)
	Object.CFrame = CFrame.new(Center + Vector3.yAxis * 6) * CFrame.Angles(math.rad(13), math.rad(22), math.rad(-7))
	Object:SetAttribute("PlacementId", "transform-test")
	Object:SetAttribute("RealmId", 90003)
	Object:SetAttribute("PlacementAngle", 15)
	Object:AddTag("WindShake")
	local WindBone = Instance.new("Bone")
	WindBone.CFrame = CFrame.new(0, 1, 0)
	WindBone:AddTag("WindShake")
	WindBone.Parent = Object
	Object.Parent = Objects
	Realm.Parent = workspace
	local Player = { UserId = 90003, Character = Character }
	function Player:GetAttribute(_Name: string): any
		return nil
	end
	local Origin = Object:GetPivot()
	local Record = { Id = "transform-test", Transform = { Realm:GetPivot():ToObjectSpace(Origin):GetComponents() }, Angle = 15 }
	Context.Realm = Realm
	Context.Data = { Realm = { PlacedObjects = { Record } } }
	local Request = {
		PlacementId = Record.Id, Origin = Origin, Position = Origin.Position + Vector3.new(0.1, 3.2, -0.3),
		Rotation = Vector3.new(15, 30, 45),
	}
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Matches(First: CFrame, Second: CFrame): boolean
		return (First.Position - Second.Position).Magnitude < 0.005
			and First.UpVector:Dot(Second.UpVector) > 0.999999 and First.LookVector:Dot(Second.LookVector) > 0.999999
	end
	local TerrainRegion = Region3.new(Center - Vector3.one * 12, Center + Vector3.one * 12):ExpandToGrid(4)
	local TerrainMaterials, TerrainOccupancies = workspace.Terrain:ReadVoxels(TerrainRegion, 4)
	local WindFrames: { { Object: Instance, Frame: CFrame } } = {}
	Service.Client.WindMoved:Connect(function(Frames: { { Object: Instance, Frame: CFrame } })
		WindFrames = Frames
	end)
	local function WindMatches(Frame: CFrame): boolean
		local FoundPart, FoundBone = false, false
		for _, Entry in WindFrames do
			if Entry.Object == Object then
				FoundPart = Matches(Entry.Frame, Frame)
			elseif Entry.Object == WindBone then
				FoundBone = Matches(Entry.Frame, Frame * WindBone.CFrame)
			end
		end

		return #WindFrames == 2 and FoundPart and FoundBone
	end

	local Success, Error = pcall(function()
		Service.KnitInit()
		Service.KnitStart()
		Check(not Service:Transform(Player, Request), "Transform requires an active editor session")
		Service.Client.Editing:Fire(Player, true)
		Check(Character:GetAttribute("RealmEditing") == true, "Accepted editor sessions publish the server-owned editing state")
		Check(Service:Transform(Player, Request), "Transform accepts precise translation and rotation on all three axes")
		local Expected = Building.GetTransform(Origin, Request.Position, Request.Rotation)
		Check(Matches(Object:GetPivot(), Expected), "Commit the full orientation, preserving the asset's original rotation")
		Check(WindMatches(Expected), "Publish authoritative wind origins for the moved part and its bones")
		Check(Matches(Realm:GetPivot() * CFrame.new(table.unpack(Record.Transform)), Expected), "Persist all twelve transform components")
		Check(Record.Angle == nil and Object:GetAttribute("PlacementAngle") == nil, "Clear the obsolete yaw-only placement angle")
		Check(#Objects:GetChildren() == 1 and #Context.Data.Realm.PlacedObjects == 1, "Keep the same object and saved identity")
		Check(not Service:Transform(Player, Request), "Reject stale edits instead of compounding a rotation twice")
		Check(Service:ChangeHistory(Player, "Undo") and Matches(Object:GetPivot(), Origin), "Undo restores the entire original orientation")
		Check(WindMatches(Origin), "Undo publishes restored wind origins")
		Check(Record.Angle == 15, "Undo restores the original placement angle")
		Check(Service:ChangeHistory(Player, "Redo") and Matches(Object:GetPivot(), Expected), "Redo restores all three rotation axes")
		Check(WindMatches(Expected), "Redo publishes restored wind origins")
		Request.Origin = Object:GetPivot()
		Request.Position = Request.Origin.Position
		Request.Rotation = Vector3.zero
		Check(Service:Transform(Player, Request) and History:GetCounts(Player, Realm) == 1, "Unchanged transforms do not consume history")
		for _, Invalid in { Vector3.new(14, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 16), Vector3.new(0 / 0, 0, 0) } do
			Request.Rotation = Invalid
			Check(not Service:Transform(Player, Request), "Reject unsnapped or nonfinite angles on every axis")
		end
		Request.Rotation = Vector3.new(-15, 360, 90)
		Request.Position = Center + Vector3.xAxis * 64
		Check(not Service:Transform(Player, Request), "Reject transforms outside the owned realm")
		Request.Position = Vector3.new(math.huge, 0, 0)
		Check(not Service:Transform(Player, Request), "Reject nonfinite positions")
		Request.Position = Expected.Position
		local Obstacle = Instance.new("Part")
		Obstacle.Anchored = true
		Obstacle.Size = Vector3.one * 10
		Obstacle.Position = Expected.Position
		Obstacle.Parent = Realm
		Check(not Service:Transform(Player, Request), "Reject blocked transforms without mutating the object")
		Obstacle:Destroy()
		Object:SetAttribute("RealmId", 42)
		Check(not Service:Transform(Player, Request), "Reject another player's object")
		Object:SetAttribute("RealmId", Player.UserId)
		Check(Matches(Object:GetPivot(), Expected), "Rejected requests preserve the last committed transform")
		Request.Rotation = Vector3.zero
		Request.Origin = CFrame.new(Vector3.new(0 / 0, 0, 0))
		Check(not Service:Transform(Player, Request), "Reject malformed reference transforms")

		local Floor = Instance.new("Part")
		Floor.Anchored = true
		Floor.Size = Vector3.new(60, 2, 60)
		Floor.Position = Center
		Floor.Parent = Realm
		local MoveRequest = {
			PlacementId = Record.Id, Position = Center + Vector3.new(-8.037, 1, 0.126),
			Normal = Vector3.yAxis, Angle = 0,
		}
		Check(Service:Move(Player, MoveRequest), "The old Move tool accepts a previously transformed object")
		local Moved = Object:GetPivot()
		Check(WindMatches(Moved), "The old Move tool also publishes updated wind origins")
		Check(Moved.UpVector:Dot(Expected.UpVector) > 0.999999 and Moved.LookVector:Dot(Expected.LookVector) > 0.999999,
			"The old Move tool preserves the full rotation")
		Check(math.abs(Moved.Position.X - MoveRequest.Position.X) < 0.005
			and math.abs(Moved.Position.Z - MoveRequest.Position.Z) < 0.005 and Record.Angle == nil,
			"Surface movement keeps continuous coordinates and the full-rotation metadata")
		Check(Service:ChangeHistory(Player, "Undo") and Matches(Object:GetPivot(), Expected), "Undo surface movement restores the full transform")
		Check(Service:ChangeHistory(Player, "Redo") and Matches(Object:GetPivot(), Moved), "Redo surface movement preserves the full transform")
		MoveRequest.Angle = 15
		Check(Service:Move(Player, MoveRequest), "The old Move tool can still rotate a tilted object")
		local Rotated = CFrame.Angles(0, math.rad(-15), 0) * Moved.Rotation
		Check(Object:GetPivot().UpVector:Dot(Rotated.UpVector) > 0.999999
			and Object:GetPivot().LookVector:Dot(Rotated.LookVector) > 0.999999, "Surface rotation preserves pitch and roll")

		Floor:Destroy()
		workspace.Terrain:FillBlock(CFrame.new(Center - Vector3.yAxis * 2), Vector3.new(12, 8, 12), Enum.Material.Grass)
		task.wait(0.1)
		local TerrainParams = RaycastParams.new()
		TerrainParams.FilterType = Enum.RaycastFilterType.Include
		TerrainParams.FilterDescendantsInstances = { workspace.Terrain }
		local Hit = workspace:Raycast(Center + Vector3.yAxis * 10, -Vector3.yAxis * 30, TerrainParams)
		Check(Hit ~= nil and Hit.Instance == workspace.Terrain, "The fixture contains native terrain")
		local BeforeBurial = Object:GetPivot()
		Request.Origin, Request.Position, Request.Rotation = BeforeBurial, Center - Vector3.yAxis * 2, Vector3.zero
		Check(Service:Transform(Player, Request), "Transform can embed the object in native terrain")
		local Buried = Object:GetPivot()
		Check((Buried.Position - Request.Position).Magnitude < 0.005, "Terrain does not lift the transformed object back to the surface")
		Check(Service:ChangeHistory(Player, "Undo") and Matches(Object:GetPivot(), BeforeBurial), "Undo restores the position before burial")
		Check(Service:ChangeHistory(Player, "Redo") and Matches(Object:GetPivot(), Buried), "Redo preserves an embedded transform")
		Request.Origin = Buried
		local Blocker = Instance.new("Part")
		Blocker.Anchored = true
		Blocker.Size = Vector3.one * 8
		Blocker.Position = Buried.Position
		Blocker.Parent = Objects
		Check(not Service:Transform(Player, Request), "Terrain overlap does not allow overlap with other placed objects")
		Blocker:Destroy()
		Service.Client.Editing:Fire(Player, false)
		Check(Character:GetAttribute("RealmEditing") == false, "Closing an editor session clears the server-owned editing state")
	end)
	workspace.Terrain:WriteVoxels(TerrainRegion, 4, TerrainMaterials, TerrainOccupancies)
	Realm:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " realm transform integration checks passed"
end
