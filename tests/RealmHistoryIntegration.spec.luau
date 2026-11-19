return function(Service: any, History: any, Context: any): string
	local Checks = 0
	local Origin = Vector3.new(28000, 500, 28000)
	local Realm = Instance.new("Model")
	Realm.Name = "RealmHistoryIntegrationTest"
	Realm.WorldPivot = CFrame.new(Origin)
	Realm:SetAttribute("OwnerId", 90002)
	Realm:SetAttribute("Loaded", true)
	Realm:SetAttribute("TerrainCenter", Origin)
	Realm:SetAttribute("TerrainSize", Vector3.one * 64)
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(60, 2, 60)
	Floor.Position = Origin
	Floor.Parent = Realm
	local Objects = Instance.new("Folder")
	Objects.Name = "PlacedObjects"
	Objects.Parent = Realm
	local Character = Instance.new("Model")
	Character:SetAttribute("InRealm", true)
	Character.Parent = Realm
	local Root = Instance.new("Part")
	Root.Anchored = true
	Root.Position = Origin + Vector3.yAxis * 20
	Root.Parent = Character
	Character.PrimaryPart = Root
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Parent = Character
	Realm.Parent = workspace
	local Player = { UserId = 90002, Character = Character }
	function Player:GetAttribute(_Name: string): any
		return nil
	end
	Context.Realm = Realm
	Context.Data = { Inventory = { { Name = "WoodLog", Stack = 30 } }, Realm = { PlacedObjects = {} } }
	Context.Capacity = 0
	local Data = Context.Data.Realm

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Place(Offset: number): boolean
		return Service:Place(Player, {
			Asset = { Tab = "Decorations", Category = "Chair", Name = "Simple Wood Stool" },
			Position = Origin + Vector3.new(Offset, 1, 0), Normal = Vector3.yAxis, Angle = 15,
		})
	end

	local Success, Error = pcall(function()
		Service.KnitInit()
		Service.KnitStart()
		Service.Client.Editing:Fire(Player, true)
		Check(Place(0), "Record a production placement")
		local Record = Data.PlacedObjects[1]
		local Id = Record.Id
		Check(Record.ResourcesSpent.WoodLog == 2 and Context.Data.Inventory[1].Stack == 28,
			"The production placement debits and snapshots the item's resource cost")
		local Inventory = Context.Data.Inventory
		Context.Data.Inventory = {}
		Check(not Place(8) and #Data.PlacedObjects == 1 and #Objects:GetChildren() == 1,
			"Insufficient resources cannot create a saved or visible object")
		Context.Data.Inventory = Inventory
		Check(History:GetCounts(Player, Realm) == 1, "Successful placement enters history")
		Check(Service:ChangeHistory(Player, "Undo"), "Undo placement")
		Check(Data.PendingResourceRefunds.WoodLog == 2, "Undo placement returns the complete paid cost")
		Check(#Objects:GetChildren() == 0 and #Data.PlacedObjects == 0, "Undo removes world and saved placement")
		Check(Service:ChangeHistory(Player, "Redo"), "Redo placement")
		Check(Data.PendingResourceRefunds.WoodLog == 0 and Context.Data.Inventory[1].Stack == 28,
			"Redo placement charges the saved cost instead of duplicating returned materials")
		Check(#Objects:GetChildren() == 1 and Data.PlacedObjects[1].Id == Id, "Redo preserves placement identity")
		local Restored = Objects:GetChildren()[1] :: Model
		local Expected = Realm:GetPivot() * CFrame.new(table.unpack(Record.Transform))
		Check((Restored:GetPivot().Position - Expected.Position).Magnitude < 0.01
			and Restored:GetPivot().LookVector:Dot(Expected.LookVector) > 0.999, "Redo preserves position and rotation")

		local MoveRequest = { PlacementId = Id, Position = Origin + Vector3.new(0, 1, 0), Normal = Vector3.yAxis, Angle = 15 }
		Check(Service:Move(Player, MoveRequest), "Moving to the original position ignores the object's own collision")
		Check(History:GetCounts(Player, Realm) == 1, "Unchanged placement does not consume history")
		MoveRequest.Position = Origin + Vector3.new(8, 1, 0)
		MoveRequest.Angle = 45
		Check(Service:Move(Player, MoveRequest), "Move an existing object")
		Check(#Objects:GetChildren() == 1 and #Data.PlacedObjects == 1 and Data.PlacedObjects[1].Id == Id,
			"Moving preserves object identity and does not create a copy")
		Check((Restored:GetPivot().Position - Expected.Position).Magnitude > 7.9 and Data.PlacedObjects[1].Angle == 45,
			"Moving saves the new position and rotation")
		Check(Service:ChangeHistory(Player, "Undo"), "Undo movement")
		Check((Restored:GetPivot().Position - Expected.Position).Magnitude < 0.01 and Data.PlacedObjects[1].Angle == 15,
			"Undo restores the original transform on the same instance")
		Check(Service:ChangeHistory(Player, "Redo"), "Redo movement")
		local Moved = Restored:GetPivot()
		MoveRequest.Position = Origin + Vector3.new(64, 1, 0)
		Check(not Service:Move(Player, MoveRequest) and (Restored:GetPivot().Position - Moved.Position).Magnitude < 0.01,
			"Reject outside-plot movement without changing the object")
		MoveRequest.Position = Origin + Vector3.new(8, 1, 0)
		MoveRequest.Angle = 0 / 0
		Check(not Service:Move(Player, MoveRequest), "Reject invalid movement rotation")
		MoveRequest.Angle = 45
		Restored:SetAttribute("RealmId", 12345)
		Check(not Service:Move(Player, MoveRequest), "Reject movement of another owner's object")
		Restored:SetAttribute("RealmId", Player.UserId)
		Check(Service:ChangeHistory(Player, "Undo"), "Return to original placement before branching history")

		Data.PlacedObjects[1].ResourcesSpent = { WoodLog = 10 }
		Check(Service:Delete(Player, Id), "Record a paid deletion")
		Check(Data.PendingResourceRefunds.WoodLog == 7, "Deletion queues the seventy-percent refund")
		local Obstacle = Instance.new("Part")
		Obstacle.Anchored = true
		Obstacle.Position = Expected.Position
		Obstacle.Size = Vector3.one * 5
		Obstacle.Parent = Realm
		Check(not Service:ChangeHistory(Player, "Undo"), "Blocked restoration is rejected")
		Check(History:GetCounts(Player, Realm) == 2 and Data.PendingResourceRefunds.WoodLog == 7,
			"Failed undo preserves cursor and refund")
		Obstacle:Destroy()
		Data.PendingResourceRefunds.WoodLog = 0
		local OwnedInventory = Context.Data.Inventory
		Context.Data.Inventory = {}
		Check(not Service:ChangeHistory(Player, "Undo"), "Consumed refunds prevent restoring a paid object for free")
		Check(#Objects:GetChildren() == 0, "A failed resource reversal does not restore the object")
		Context.Data.Inventory = OwnedInventory
		Data.PendingResourceRefunds.WoodLog = 7
		Check(Service:ChangeHistory(Player, "Undo"), "Undo deletion after validation succeeds")
		Check(#Objects:GetChildren() == 1 and Data.PlacedObjects[1].ResourcesSpent.WoodLog == 10
			and Data.PendingResourceRefunds.WoodLog == 0, "Restoration preserves saved cost and removes the refund")
		Check(Service:ChangeHistory(Player, "Redo"), "Redo deletion")
		Check(#Objects:GetChildren() == 0 and Data.PendingResourceRefunds.WoodLog == 7, "Redo applies the original refund exactly once")
		Check(not Service:ChangeHistory(Player, "Redo") and Data.PendingResourceRefunds.WoodLog == 7, "Repeated redo cannot duplicate credits")
		Check(Service:ChangeHistory(Player, "Undo"), "Restore before creating a new branch")
		Check(Place(8), "A new placement creates a new history branch")
		local _, Redo = History:GetCounts(Player, Realm)
		Check(Redo == 0 and not Service:ChangeHistory(Player, "Redo"), "New placement clears the deleted redo branch")

		Service.Client.Editing:Fire(Player, false)
		Check(not Service:ChangeHistory(Player, "Undo"), "History requires an editor session")
		Service.Client.Editing:Fire(Player, true)
		Check(Service:ChangeHistory(Player, "Undo") and #Objects:GetChildren() == 1,
			"Closing and reopening the editor preserves loaded-realm history")
	end)

	Realm:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " realm history integration checks passed"
end
