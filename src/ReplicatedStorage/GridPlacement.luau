local GridPlacement = {}

-- posicionar no chao, parede e em cima de moveis com BuildingArea

type AreaType = "Floor" | "Wall" | "Ceiling" | { string }

function GridPlacement:NormalizeAreaType(Area: AreaType)
	if type(Area) == "string" then
		return { Area }
	end

	return Area
end

function GridPlacement:ToggleBuildingAreas(Plot: Model, Area: AreaType, Enabled: boolean)
	local Area = self:NormalizeAreaType(Area)

	local function toggleAreasInChildren(parent: Instance, AreaName: string)
		local Transparency = if Enabled then 0 else 1
		for _, BuildingArea in parent:GetChildren() do
			if BuildingArea.Name == AreaName then
				for _, Texture in BuildingArea:GetChildren() do
					Texture.Transparency = Transparency
				end
			end
		end
	end


	for _, AreaName in Area do
		toggleAreasInChildren(Plot.BuildingAreas, AreaName)
		for _, Object: Instance in Plot.Objects:GetChildren() do
			if Object:FindFirstChild("BuildingAreas") then
				toggleAreasInChildren(Object, AreaName)
			end
		end
	end
end

return GridPlacement
