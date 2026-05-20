local Mobs = {}

for index, module in pairs(script:GetDescendants()) do
	if module:IsA("ModuleScript") then
		local required = require(module)

		Mobs[module.Name] = required
	end
end

return Mobs
