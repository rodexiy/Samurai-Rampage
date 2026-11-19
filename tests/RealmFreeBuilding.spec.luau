local Players = game:GetService("Players")

return function(Service: any, History: any, ResourceService: any, Context: any, Command: any): string
	local Checks = 0
	local Center = Vector3.new(30000, 500, 30000)
	local Realm = Instance.new("Model")
	Realm.WorldPivot = CFrame.new(Center)
	Realm:SetAttribute("OwnerId", 90004)
	Realm:SetAttribute("Loaded", true)
	Realm:SetAttribute("TerrainCenter", Center)
	Realm:SetAttribute("TerrainSize", Vector3.one * 64)
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(60, 2, 60)
	Floor.Position = Center
	Floor.Parent = Realm
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
	Realm.Parent = workspace
	local Player = { UserId = 90004, Name = "FreeBuilder", Parent = Players, Character = Character }
	function Player:GetAttribute(_Name: string): any
		return nil
	end
	local OtherPlayer = { Name = "OtherBuilder", Parent = Players }
	Context.Realm = Realm
	Context.Data = { Inventory = {}, Realm = { PlacedObjects = {}, PendingResourceRefunds = {} } }
	Context.Capacity = math.huge
	local Data = Context.Data.Realm
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Place(Offset: number): boolean
		return Service:Place(Player, {
			Asset = { Tab = "Decorations", Category = "Chair", Name = "Simple Wood Stool" },
			Position = Center + Vector3.new(Offset, 1, 0), Normal = Vector3.yAxis, Angle = 0,
			Cost = {}, ResourcesSpent = {},
		})
	end
	local function Count(): number
		local Amount = Data.PendingResourceRefunds.WoodLog or 0
		for _, Item in Context.Data.Inventory do
			if Item.Name == "WoodLog" then
				Amount += Item.Stack
			end
		end

		return Amount
	end

	local Success, Error = pcall(function()
		Service.KnitInit()
		Service.KnitStart()
		Check(ResourceService:AreResourcesRequired(Player), "Resource costs are enabled by default")
		Service.Client.Editing:Fire(Player, true)
		Check(not Place(0), "An empty inventory cannot build by default")
		local Response = Command({ Executor = Player }, false)
		Check(string.find(Response, "disabled", 1, true) ~= nil and not ResourceService:AreResourcesRequired(Player),
			"Command defaults to its executor and disables resource costs")
		Check(ResourceService:AreResourcesRequired(OtherPlayer), "Free building only affects selected players")
		Check(Place(0), "Free building accepts an empty inventory")
		Check(next(Data.PlacedObjects[1].ResourcesSpent) == nil and Count() == 0,
			"Free placements record no debit and consume no resources")
		local Id = Data.PlacedObjects[1].Id
		Command({ Executor = OtherPlayer }, true, { Player })
		Check(ResourceService:AreResourcesRequired(Player), "An explicit target can have resource costs restored")
		Check(Service:ChangeHistory(Player, "Undo") and Count() == 0, "Undo a free placement without creating materials")
		Check(Service:ChangeHistory(Player, "Redo") and Count() == 0, "Redo remains free after costs are restored")
		Check(Service:Delete(Player, Id) and Count() == 0, "Deleting a free object grants no resource refund")
		Check(Service:ChangeHistory(Player, "Undo") and Count() == 0, "Undo free deletion needs no resources")
		Check(not Place(8), "Restoring requirements blocks new unaffordable builds")
		Context.Data.Inventory = { { Name = "WoodLog", Stack = 2 } }
		Check(Place(8) and Count() == 0, "Restored requirements charge the actual recipe")
		Check(Data.PlacedObjects[2].ResourcesSpent.WoodLog == 2, "Paid objects retain their actual resource debit")
		Command({ Executor = Player }, false)
		Check(Service:ChangeHistory(Player, "Undo") and Count() == 2, "Undo a paid placement returns its actual cost in free mode")
		Check(Service:ChangeHistory(Player, "Redo") and Count() == 0,
			"Redo reverses the paid refund in free mode instead of duplicating materials")
		Check(not ResourceService:SetResourcesRequired(Player, "false"), "Reject nonboolean settings")
		Check(not ResourceService:SetResourcesRequired({ Parent = nil }, false), "Reject disconnected players")
		local InvalidAsset = Instance.new("Part")
		InvalidAsset:SetAttribute("Cost_UnknownResource", 2)
		Check(ResourceService:GetPlacementCost(Player, InvalidAsset) == nil, "Free mode still validates recipe definitions")
		InvalidAsset:Destroy()
		Check(History:GetCounts(Player, Realm) == 2, "Free and paid placements keep consistent history")
	end)
	ResourceService:SetResourcesRequired(Player, true)
	Realm:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " realm free building checks passed"
end
