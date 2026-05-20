local SkillTrees = {}

for index, module in pairs(script:GetDescendants()) do
	if module:IsA("ModuleScript") then
		local required = require(module)

		SkillTrees[module.Name] = required
	end
end

return SkillTrees
