-- Run the production service with isolated Knit signals and realm/profile dependencies.
return function(Service: any, Context: any): string
	local Checks = 0
	local Realm = Instance.new("Model")
	Realm:SetAttribute("OwnerId", 90001)
	Realm:SetAttribute("Loaded", true)
	local Objects = Instance.new("Folder")
	Objects.Name = "PlacedObjects"
	Objects.Parent = Realm
	local Character = Instance.new("Model")
	Character:SetAttribute("InRealm", true)
	Character.Parent = Realm
	local Root = Instance.new("Part")
	Root.Parent = Character
	Character.PrimaryPart = Root
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Parent = Character
	local Player = { UserId = 90001, Character = Character }

	function Player:GetAttribute(_Name: string): any
		return nil
	end
	Context.Realm = Realm
	Context.Data = { Realm = { PlacedObjects = {} } }

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Add(Id: string, Cost: any, Parent: Instance?, Owner: number?): Model
		local Object = Instance.new("Model")
		Object:SetAttribute("PlacementId", Id)
		Object:SetAttribute("RealmId", Owner or Player.UserId)
		Object.Parent = Parent or Objects
		table.insert(Context.Data.Realm.PlacedObjects, { Id = Id, ResourcesSpent = Cost })

		return Object
	end

	local Success, Error = pcall(function()
		Service.KnitInit()
		Service.KnitStart()
		Service.Client.Editing:Fire(Player, true)

		local Refund = Service:GetDeletionRefund({ WoodLog = 10, Stone = 3, PlantFiber = 1 })
		Check(Refund.WoodLog == 7 and Refund.Stone == 2, "Refund seventy percent of each resource, rounded down")
		Check(Refund.PlantFiber == nil, "Omit resources whose refund rounds to zero")
		Check(next(Service:GetDeletionRefund(nil)) == nil, "Legacy free objects have no refund")
		Check(next(Service:GetDeletionRefund({ Negative = -5, Fraction = 2.5, Infinite = math.huge, Invalid = "20" })) == nil,
			"Ignore invalid spent-resource data")

		local Target = Add("paid", { WoodLog = 10, Stone = 3 })
		local Untouched = Add("keep", {})
		local Accepted, _, Returned = Service:Delete(Player, "paid")
		Check(Accepted and Target.Parent == nil, "Delete the selected owned object")
		Check(Untouched.Parent == Objects and #Context.Data.Realm.PlacedObjects == 1,
			"Remove only the selected saved record")
		Check(Returned.WoodLog == 7 and Returned.Stone == 2, "Report the server-calculated refund")
		Check(Context.Data.Realm.PendingResourceRefunds.WoodLog == 7, "Persist the pending resource credit")
		Check(not Service:Delete(Player, "paid"), "Reject duplicate deletion")
		Check(Context.Data.Realm.PendingResourceRefunds.WoodLog == 7, "Duplicate requests cannot refund twice")

		Add("second", { WoodLog = 20 })
		Check(Service:Delete(Player, "second"), "Delete another paid object")
		Check(Context.Data.Realm.PendingResourceRefunds.WoodLog == 21, "Accumulate refunds without losing earlier credits")
		Add("legacy", nil)
		Check(Service:Delete(Player, "legacy"), "Delete records created before costs existed")
		Check(Context.Data.Realm.PendingResourceRefunds.WoodLog == 21, "Free objects do not manufacture resources")

		local Foreign = Add("foreign", { WoodLog = 100 }, nil, 12345)
		Check(not Service:Delete(Player, "foreign") and Foreign.Parent == Objects, "Reject another owner's object")
		local Structure = Add("structure", { WoodLog = 100 }, Realm)
		Check(not Service:Delete(Player, "structure") and Structure.Parent == Realm, "Protect template structures")
		local Unsaved = Add("unsaved", {})
		table.remove(Context.Data.Realm.PlacedObjects)
		Check(not Service:Delete(Player, "unsaved") and Unsaved.Parent == Objects, "Reject objects without a saved placement")
		Check(not Service:Delete(Player, { PlacementId = "keep", Refund = { WoodLog = 999 } }), "Reject forged deletion arguments")

		Character:SetAttribute("InCombat", true)
		Check(not Service:Delete(Player, "keep"), "Reject deletion when the character cannot edit")
		Character:SetAttribute("InCombat", false)
		Service.Client.Editing:Fire(Player, false)
		Check(not Service:Delete(Player, "keep"), "Reject deletion outside an editor session")
		Check(Untouched.Parent == Objects, "Rejected requests preserve objects")
		Service.Client.Editing:Fire(Player, true)
		Check(Service:Delete(Player, "keep"), "Deletion works after opening a new editor session")
	end)

	Realm:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " realm deletion checks passed"
end
