local Stances = {}

for index, module in pairs(script:GetDescendants()) do
	if module:IsA("ModuleScript") then
		local required = require(module)

		Stances[module.Name] = required
	end
end

return Stances
