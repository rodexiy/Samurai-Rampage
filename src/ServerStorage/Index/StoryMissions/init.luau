local Missions = {}

for _, Module in script:GetChildren() do
	if Module:IsA("ModuleScript") then
		table.insert(Missions, require(Module))
	end
end

table.sort(Missions, function(First, Second)
	return First.Order < Second.Order
end)

return Missions
