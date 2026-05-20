local Races = {}

for index, module in pairs(script:GetDescendants()) do
	if module:IsA("ModuleScript") then
		local required = require(module)

		Races[required.Name] = required
	end
end

return Races
