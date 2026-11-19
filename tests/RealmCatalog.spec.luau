return function(Catalog: any): string
	local Tab = Instance.new("Folder")
	Tab.Name = "Decorations"
	local Chairs = Instance.new("Folder")
	Chairs.Name = "Chairs"
	Chairs.Parent = Tab
	local Lamps = Instance.new("Folder")
	Lamps.Name = "Lamps"
	Lamps.Parent = Tab
	local Chair = Instance.new("Part")
	Chair.Name = "Seat"
	Chair:SetAttribute("DisplayName", "Wood Chair")
	Chair:SetAttribute("Description", "Simple garden furniture")
	Chair.Parent = Chairs
	local Lamp = Instance.new("Part")
	Lamp.Name = "Seat"
	Lamp:SetAttribute("DisplayName", "Paper Lamp")
	Lamp.Parent = Lamps
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local Success, Error = pcall(function()
		Check(#Catalog.GetObjects(Tab, nil, "") == 2, "ALL includes every category without losing duplicate-named assets")
		Check(#Catalog.GetObjects(Tab, "Chairs", "") == 1, "Category views keep their scope")
		local Results = Catalog.GetObjects(Tab, nil, "  WOOD   chairs ")
		Check(#Results == 1 and Results[1].Key.Category == "Chairs" and Results[1].Key.Name == "Seat",
			"Search ignores case and excess spaces and retains the real placement key")
		Check(#Catalog.GetObjects(Tab, nil, "garden") == 1, "Search descriptions")
		Check(#Catalog.GetObjects(Tab, nil, "lamps") == 1, "Search categories")
		Check(#Catalog.GetObjects(Tab, "Chairs", "paper") == 0, "Search respects the selected category")
		Check(#Catalog.GetObjects(Tab, nil, "%.*") == 0, "Treat search punctuation as literal text")
	end)
	Tab:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " realm catalog checks passed"
end
