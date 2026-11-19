return function(Service: any, History: any, Context: any): string
	local Checks = 0
	local Origin = Vector3.new(29000, 500, 29000)
	local Realm = Instance.new("Model")
	Realm.WorldPivot = CFrame.new(Origin)
	Realm:SetAttribute("OwnerId", 90003)
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
	local Player = { UserId = 90003, Character = Character }
	function Player:GetAttribute(_Name: string): any
		return nil
	end
	Context.Realm = Realm
	Context.Capacity = math.huge
	Context.Data = { Inventory = { { Name = "WoodLog", Stack = 1 }, { Name = "WoodLog", Stack = 1 } },
		Realm = { PlacedObjects = {}, PendingResourceRefunds = {} } }
	local Data = Context.Data.Realm
	local function Count(): number
		local Total = 0
		for _, Item in Context.Data.Inventory do
			Total += if Item.Name == "WoodLog" then Item.Stack else 0
		end

		return Total
	end
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Place(Offset: number): boolean
		return Service:Place(Player, {
			Asset = { Tab = "Decorations", Category = "Chair", Name = "Simple Wood Stool" },
			Position = Origin + Vector3.new(Offset, 1, 0), Normal = Vector3.yAxis, Angle = 0,
			ResourcesSpent = {}, Cost = { WoodLog = 0 },
		})
	end
	local Success, Error = pcall(function()
		Service.KnitInit()
		Service.KnitStart()
		Service.Client.Editing:Fire(Player, true)
		Check(Place(0), "Build using split inventory stacks")
		local Id = Data.PlacedObjects[1].Id
		Check(Count() == 0 and Data.PlacedObjects[1].ResourcesSpent.WoodLog == 2, "Ignore client-supplied prices and save the real debit")
		Check(not Place(8) and #Data.PlacedObjects == 1, "Insufficient inventory cannot build another object")
		Check(Service:ChangeHistory(Player, "Undo") and Count() == 2 and #Objects:GetChildren() == 0, "Undo placement returns all materials")
		Check(Service:ChangeHistory(Player, "Redo") and Count() == 0 and #Objects:GetChildren() == 1, "Redo charges the original materials")
		Check(Service:Move(Player, { PlacementId = Id, Position = Origin + Vector3.new(8, 1, 0), Normal = Vector3.yAxis, Angle = 15 })
			and Count() == 0, "Moving never charges materials")
		Check(Service:Delete(Player, Id) and Count() == 1, "Deleting a two-log chair returns one log, rounded down from seventy percent")
		Check(not Service:Delete(Player, Id) and Count() == 1, "Duplicate deletion cannot repeat the refund")
		Check(Service:ChangeHistory(Player, "Undo") and Count() == 0 and Data.PlacedObjects[1].Id == Id,
			"Undo deletion takes back the refund and preserves the paid object")
		Check(Service:ChangeHistory(Player, "Redo") and Count() == 1, "Redo deletion returns only its original refund")
		Context.Data.Inventory = {}
		local Cursor = History:GetCounts(Player, Realm)
		Check(not Service:ChangeHistory(Player, "Undo") and #Objects:GetChildren() == 0 and History:GetCounts(Player, Realm) == Cursor,
			"An unaffordable refund reversal preserves world state and history")
		Context.Data.Inventory = { { Name = "WoodLog", Stack = 1 } }
		Check(Service:ChangeHistory(Player, "Undo") and Count() == 0, "Restoration succeeds when the refund is available again")
		Check(Service:ChangeHistory(Player, "Undo") and Count() == 0, "Undo movement does not affect resources")
		Check(Service:ChangeHistory(Player, "Undo") and Count() == 2 and #Data.PlacedObjects == 0, "Undo original placement recovers exactly its full cost")
		Context.Data.Inventory = {}
		Check(not Service:ChangeHistory(Player, "Redo") and #Objects:GetChildren() == 0, "Redo placement cannot recreate an object for free after its materials are spent")
	end)
	Realm:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " realm economy checks passed"
end
