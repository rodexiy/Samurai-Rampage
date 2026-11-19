local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Building = require(ReplicatedStorage.Shared.RealmBuilding)

local RealmCatalog = {}
export type Entry = { Asset: PVInstance, Key: Building.AssetKey, CategoryName: string }

function RealmCatalog.Matches(Query: string, Fields: { string }): boolean
	local Text = string.lower(table.concat(Fields, " "))
	for Word in string.gmatch(string.lower(Query), "%S+") do
		if not string.find(Text, Word, 1, true) then
			return false
		end
	end

	return true
end

function RealmCatalog.GetObjects(Tab: Instance, CategoryName: string?, Query: string): { Entry }
	local Entries = {}
	for _, Category in Tab:GetChildren() do
		if not Category:IsA("Folder") or (CategoryName and Category.Name ~= CategoryName) then
			continue
		end
		for _, Asset in Category:GetChildren() do
			if not (Asset:IsA("Model") or Asset:IsA("BasePart")) or #Building.GetParts(Asset) == 0 then
				continue
			end
			local DisplayCategory = Category:GetAttribute("DisplayName") or Category.Name
			if RealmCatalog.Matches(Query, { Asset.Name, Asset:GetAttribute("DisplayName") or Asset.Name,
				DisplayCategory, Category.Name, Asset:GetAttribute("Description") or "" }) then
				table.insert(Entries, {
					Asset = Asset,
					Key = { Tab = Tab.Name, Category = Category.Name, Name = Asset.Name },
					CategoryName = DisplayCategory,
				})
			end
		end
	end
	table.sort(Entries, function(A: Entry, B: Entry): boolean
		local AName, BName = A.Asset:GetAttribute("DisplayName") or A.Asset.Name, B.Asset:GetAttribute("DisplayName") or B.Asset.Name
		return if AName == BName then A.Key.Category < B.Key.Category else AName < BName
	end)

	return Entries
end

return RealmCatalog
