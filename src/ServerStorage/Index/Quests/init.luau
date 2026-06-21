local Quests = {}

for index, module in pairs(script:GetDescendants()) do
	if module:IsA("ModuleScript") then
		local required = require(module)

		Quests[module.Name] = required
	end
end

return Quests
