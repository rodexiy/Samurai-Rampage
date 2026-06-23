return function(Registry)
	local MissionNames = string.split(script:GetAttribute("MissionNames") or "", ",")
	if #MissionNames == 1 and MissionNames[1] == "" then
		table.clear(MissionNames)
	end

	Registry:RegisterType(
		"storyMission",
		Registry.Cmdr.Util.MakeEnumType("story mission", MissionNames)
	)
end
