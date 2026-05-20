local Knit = require(game.ReplicatedStorage.Packages.Knit)

local OceanService = Knit.CreateService({
	Name = "OceanService",
	Client = {},
})

function OceanService:GenerateArea(Name: string, Radius: number, Intensity: number, Position: Vector3)
	-- local Part = Instance.new("Part")
	-- Part.Name = Name
	-- Part.Size = Vector3.new(1, 1, 1)
	-- Part.CanCollide = false
	-- Part.Anchored = true
	-- Part.Transparency = 1
	-- Part:SetAttribute("Radius", Radius)
	-- Part:SetAttribute("Intensity", Intensity)
	-- Part.Position = Position
	-- Part.Parent = workspace.WaveZones
end

return OceanService
