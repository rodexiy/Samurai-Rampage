local CollectionService = game:GetService("CollectionService")

return function(Building: any): string
	local Checks = 0
	local Asset = Instance.new("Model")
	local Container = Instance.new("Folder")
	local First = Instance.new("Part")
	First.Name = "Part"
	First:SetAttribute("Role", "First")
	First.Parent = Asset
	local Second = Instance.new("Part")
	Second.Name = "Part"
	Second:SetAttribute("Role", "Second")
	Second.Parent = Asset
	local Skipped = Instance.new("Part")
	Skipped.Name = "Part"
	Skipped.Archivable = false
	Skipped.Parent = Asset
	CollectionService:AddTag(Asset, "WindShake")
	CollectionService:AddTag(First, "WindShake")
	CollectionService:AddTag(Second, "SmartBone")
	CollectionService:AddTag(Skipped, "SmartBone")
	CollectionService:AddTag(First, "RealmCloneUnrelatedTag")
	local Copy: PVInstance? = nil
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function HasMarkers(Object: Instance): boolean
		local Instances = Object:QueryDescendants("Instance")
		table.insert(Instances, Object)
		for _, Node in Instances do
			for Name in Node:GetAttributes() do
				if string.match(Name, "^RealmClone_") then
					return true
				end
			end
		end

		return false
	end
	local Success, Error = pcall(function()
		local Clone, RestoreTags = Building.Clone(Asset)
		Copy = Clone
		Check(CollectionService:HasTag(Asset, "WindShake") and CollectionService:HasTag(First, "WindShake")
			and CollectionService:HasTag(Second, "SmartBone") and CollectionService:HasTag(Skipped, "SmartBone"),
			"Restore every source tag immediately after cloning")
		Check(not CollectionService:HasTag(Clone, "WindShake"), "Do not activate wind simulation on an unpositioned clone")
		local Parts = Clone:QueryDescendants("BasePart")
		Check(#Parts == 2, "Respect non-archivable descendants")
		for _, Node in Parts do
			Check(not CollectionService:HasTag(Node, "WindShake") and not CollectionService:HasTag(Node, "SmartBone"),
				"Preview descendants start without wind and bone simulation tags")
		end
		Check(not HasMarkers(Asset) and not HasMarkers(Clone), "Temporary clone identifiers never remain on either object")
		Clone.Parent = Container
		Clone:PivotTo(CFrame.new(100, 20, 30))
		RestoreTags()
		Check(CollectionService:HasTag(Clone, "WindShake"), "Activate root tags after placement")
		for _, Node in Parts do
			if Node:GetAttribute("Role") == "First" then
				Check(CollectionService:HasTag(Node, "WindShake") and not CollectionService:HasTag(Node, "SmartBone"),
					"Restore tags to the correct child when names are duplicated")
				Check(CollectionService:HasTag(Node, "RealmCloneUnrelatedTag"), "Preserve unrelated tags")
			else
				Check(CollectionService:HasTag(Node, "SmartBone") and not CollectionService:HasTag(Node, "WindShake"),
					"Preserve separate bone and wind memberships")
			end
		end
		RestoreTags()
		Check(CollectionService:HasTag(Clone, "WindShake"), "Tag restoration can only activate once")
		Asset.Archivable = false
		local Cloned = pcall(function()
			Building.Clone(Asset)
		end)
		Check(not Cloned and CollectionService:HasTag(Asset, "WindShake") and CollectionService:HasTag(Second, "SmartBone"),
			"Restore source tags even when the clone cannot be created")
		Check(not HasMarkers(Asset), "Failed cloning does not leave source metadata behind")
	end)
	if Copy then
		Copy:Destroy()
	end
	Container:Destroy()
	Asset:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " realm cloning checks passed"
end
