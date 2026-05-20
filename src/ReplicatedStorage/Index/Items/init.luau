local Items = {}

for index, module in pairs(script:GetDescendants()) do
	if module:IsA("ModuleScript") then
		local required = require(module)

		Items[required.Name] = required
	end
end

return Items
