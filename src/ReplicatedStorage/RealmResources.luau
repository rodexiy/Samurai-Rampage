local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.Index.Items)

local RealmResources = {}

export type Cost = { [string]: number }
function RealmResources.GetCost(Asset: PVInstance): Cost?
	local Cost = {}
	for Attribute, Amount in Asset:GetAttributes() do
		local Name = string.match(Attribute, "^Cost_(.+)$")
		if Name then
			Cost[Name] = Amount
		end
	end

	return if RealmResources.IsValid(Cost) then Cost else nil
end

function RealmResources.IsValid(Cost: any): boolean
	if typeof(Cost) ~= "table" then
		return false
	end
	for Name, Amount in Cost do
		local Item = Items[Name]
		if not Item or Item.Class ~= "Resource" or typeof(Amount) ~= "number" or Amount ~= Amount
			or Amount <= 0 or Amount >= math.huge or Amount % 1 ~= 0 then
			return false
		end
	end

	return true
end

function RealmResources.GetNames(Cost: Cost): { string }
	local Names = {}
	for Name in Cost do
		table.insert(Names, Name)
	end
	table.sort(Names)

	return Names
end

return RealmResources
