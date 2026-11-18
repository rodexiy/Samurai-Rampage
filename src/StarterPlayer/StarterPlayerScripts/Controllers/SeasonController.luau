local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SeasonController = Knit.CreateController({
	Name = "SeasonController",
})

local CurrentSeason: string?
local PendingFoliage: { [Instance]: boolean } = {}
local FoliageUpdateQueued = false

local SeasonColors = {
	Winter = Color3.fromRGB(232, 238, 240),
	Autumn = Color3.fromRGB(224, 125, 4),
	Spring = Color3.fromRGB(0, 0, 0),
}

local WinterLeafColors = {
	Color3.fromRGB(105, 124, 132),
	Color3.fromRGB(122, 140, 147),
	Color3.fromRGB(140, 156, 162),
	Color3.fromRGB(158, 171, 176),
}

local WinterGrassColors = {
	Color3.fromRGB(187, 202, 207),
	Color3.fromRGB(199, 212, 216),
	Color3.fromRGB(210, 220, 223),
	Color3.fromRGB(220, 228, 230),
}

-- Summer colors are captured from the authored Studio state.
local TreeSeasonColors = {
	Tree_11 = {
		Spring = Color3.fromRGB(153, 23, 23),
	},
}

local FoliageTags = {
	"Grass",
	"Leaves",
	"WindShake",
}

local SUMMER_COLOR_ATTRIBUTE = "SummerColor"

local function random_bright(): Color3
	local tones = {
		Color3.fromRGB(224, 125, 4),
		Color3.fromRGB(15, 115, 7),
		Color3.fromRGB(162, 4, 224),
		Color3.fromRGB(147, 41, 19),
	}

	return tones[math.random(1, #tones)]
end

local function getRandomColorOffseted(color: Color3): Color3
	return Color3.fromRGB(
		math.clamp(color.R * 255 + math.random(-5, 25), 0, 255),
		math.clamp(color.G * 255 + math.random(-5, 25), 0, 255),
		math.clamp(color.B * 255 + math.random(-5, 25), 0, 255)
	)
end

local function hasInheritedTag(instance: Instance, tag: string): boolean
	local current: Instance? = instance
	while current and current ~= workspace do
		if current:HasTag(tag) then
			return true
		end

		current = current.Parent
	end

	return false
end

local function getTreeSeasonColor(instance: Instance): Color3?
	local current: Instance? = instance
	while current and current ~= workspace do
		local seasonColors = TreeSeasonColors[current.Name]
		local color = seasonColors and seasonColors[CurrentSeason]
		if color then
			return color
		end

		current = current.Parent
	end

	return nil
end

local function hasFoliageTag(instance: Instance): boolean
	local current: Instance? = instance
	while current and current ~= workspace do
		for _, tag in FoliageTags do
			if current:HasTag(tag) then
				return true
			end
		end
		if string.find(current.Name, "Leaves", 1, true) == 1 then
			return true
		end

		current = current.Parent
	end

	return false
end

local function getSeasonalFoliageColor(instance: Instance): Color3?
	local treeColor = getTreeSeasonColor(instance)
	if treeColor then
		return treeColor
	end

	if CurrentSeason == "Spring" and hasInheritedTag(instance, "WindShake") then
		local model = if instance:IsA("Model") then instance else instance:FindFirstAncestorOfClass("Model")
		if model then
			local base = model:GetAttribute("SpringColor")
			if typeof(base) ~= "Color3" then
				base = random_bright()
				model:SetAttribute("SpringColor", base)
			end

			return getRandomColorOffseted(base)
		end
	end

	if CurrentSeason == "Winter" then
		local isLeaf = hasInheritedTag(instance, "Leaves") or hasInheritedTag(instance, "WindShake")
		local colors = if isLeaf then WinterLeafColors else WinterGrassColors
		return colors[math.random(1, #colors)]
	end

	local seasonColor = SeasonColors[CurrentSeason]
	return if seasonColor then getRandomColorOffseted(seasonColor) else nil
end

local function applyAppearanceColor(appearance: SurfaceAppearance, color: Color3?)
	local summerColor = appearance:GetAttribute(SUMMER_COLOR_ATTRIBUTE)
	if typeof(summerColor) ~= "Color3" then
		summerColor = appearance.Color
		appearance:SetAttribute(SUMMER_COLOR_ATTRIBUTE, summerColor)
	end

	appearance.Color = color or summerColor
end

local function applySurfaceAppearanceColor(instance: Instance, color: Color3?)
	if instance:IsA("SurfaceAppearance") then
		applyAppearanceColor(instance, color)
	end
	for _, appearance in instance:QueryDescendants("SurfaceAppearance") do
		applyAppearanceColor(appearance, color)
	end
end

local function applyFoliage(instance: BasePart)
	if not hasFoliageTag(instance) then
		return
	end

	local summerColor = instance:GetAttribute(SUMMER_COLOR_ATTRIBUTE)
	if typeof(summerColor) ~= "Color3" then
		summerColor = instance.Color
		instance:SetAttribute(SUMMER_COLOR_ATTRIBUTE, summerColor)
	end
	local defaultMaterial = instance:GetAttribute("DefaultMaterial")
	if typeof(defaultMaterial) ~= "string" then
		defaultMaterial = instance.Material.Name
		instance:SetAttribute("DefaultMaterial", defaultMaterial)
	end

	local color = getSeasonalFoliageColor(instance)
	instance.Color = color or summerColor
	applySurfaceAppearanceColor(instance, color)
	instance.Material = if defaultMaterial == "Ground" and CurrentSeason == "Winter"
		then Enum.Material.Snow
		else Enum.Material[defaultMaterial]
end

function SeasonController:ChangeSpecificGrassColor(instance: Instance)
	if not CurrentSeason or not instance:IsDescendantOf(workspace) then
		return
	end

	if instance:IsA("SurfaceAppearance") then
		if hasFoliageTag(instance) then
			applyAppearanceColor(instance, getSeasonalFoliageColor(instance))
		end
		return
	end

	if instance:IsA("BasePart") then
		applyFoliage(instance)
	end
	for _, part in instance:QueryDescendants("BasePart") do
		applyFoliage(part)
	end
end

function SeasonController:ChangeGrassColor()
	if not CurrentSeason then
		return
	end

	local terrainColor = if CurrentSeason ~= "Spring" then SeasonColors[CurrentSeason] else nil
	terrainColor = terrainColor or Color3.fromRGB(75, 125, 42)
	workspace.Terrain:SetMaterialColor(Enum.Material.Grass, terrainColor)
	workspace.Terrain:SetMaterialColor(Enum.Material.LeafyGrass, terrainColor)

	local seen: { [Instance]: boolean } = {}
	for _, tag in FoliageTags do
		for _, instance in CollectionService:GetTagged(tag) do
			if seen[instance] then
				continue
			end
			seen[instance] = true
			self:ChangeSpecificGrassColor(instance)
		end
	end
end

local function queueFoliage(instance: Instance)
	local target = if instance:IsA("SurfaceAppearance") then instance.Parent else instance
	if not target or not target:IsDescendantOf(workspace) or not hasFoliageTag(target) then
		return
	end

	PendingFoliage[target] = true
	if FoliageUpdateQueued then
		return
	end
	FoliageUpdateQueued = true

	task.defer(function()
		local pending = PendingFoliage
		PendingFoliage = {}
		FoliageUpdateQueued = false
		for foliage in pending do
			SeasonController:ChangeSpecificGrassColor(foliage)
		end
	end)
end

function SeasonController.KnitInit() end

function SeasonController.KnitStart()
	local function updateSeason()
		local season = workspace:GetAttribute("Season")
		CurrentSeason = if typeof(season) == "string" then season else nil
		if CurrentSeason then
			SeasonController:ChangeGrassColor()
		end
	end

	workspace:GetAttributeChangedSignal("Season"):Connect(updateSeason)
	for _, tag in FoliageTags do
		CollectionService:GetInstanceAddedSignal(tag):Connect(queueFoliage)
	end
	workspace.DescendantAdded:Connect(function(instance: Instance)
		if instance:IsA("BasePart") or instance:IsA("SurfaceAppearance") then
			queueFoliage(instance)
		end
	end)

	updateSeason()
end

return SeasonController
