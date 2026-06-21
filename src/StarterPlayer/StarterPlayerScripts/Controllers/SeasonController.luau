local CollectionService = game:GetService("CollectionService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SeasonController = Knit.CreateController({
    Name = "SeasonController",
})

local CurrentSeason = workspace:GetAttribute("Season")

function color3torgb(color3)
	return color3.R * 255, color3.G * 255, color3.B * 255
end

local SeasonColors = {
	Winter = Color3.fromRGB(232, 238, 240),
	Autumn = Color3.fromRGB(224, 125, 4),
	Spring = Color3.fromRGB(),
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

local function random_bright()
	local tones = {
		Color3.fromRGB(224, 125, 4),
		Color3.fromRGB(15, 115, 7),
		Color3.fromRGB(162, 4, 224),
		Color3.fromRGB(147, 41, 19),
	}

	return tones[math.random(1, #tones)]
end

local function getRandomColorOffseted(color)
	local r, g, b = color3torgb(color)

	return Color3.fromRGB(
		math.min(r + math.random(-5, 25), 255),
		math.min(g + math.random(-5, 25), 255),
		math.min(b + math.random(-5, 25), 255)
	)
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

local function isLeafFoliage(instance: Instance): boolean
	local current: Instance? = instance

	while current and current ~= workspace do
		if current:HasTag("Leaves") or current:HasTag("WindShake") then
			return true
		end

		current = current.Parent
	end

	return false
end

local function getWinterFoliageColor(instance: Instance): Color3
	local colors = if isLeafFoliage(instance) then WinterLeafColors else WinterGrassColors

	return colors[math.random(1, #colors)]
end

local function getSeasonalFoliageColor(instance: Instance): Color3?
	local treeColor = getTreeSeasonColor(instance)
	if treeColor then
		return treeColor
	end

	if CurrentSeason == "Winter" then
		return getWinterFoliageColor(instance)
	end

	local seasonColor = SeasonColors[CurrentSeason]
	if seasonColor then
		return getRandomColorOffseted(seasonColor)
	end

	return nil
end

local function hasFoliageTag(instance: Instance)
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

local function getTaggedFoliage()
	local foliage = {}
	local seen = {}

	for _, tag in FoliageTags do
		for _, instance in CollectionService:GetTagged(tag) do
			if seen[instance] then
				continue
			end

			seen[instance] = true
			table.insert(foliage, instance)
		end
	end

	return foliage
end

local function applySurfaceAppearanceColor(instance: Instance, color: Color3?)
	for _, descendant in instance:GetDescendants() do
		if not descendant:IsA("SurfaceAppearance") then
			continue
		end

		local summerColor = descendant:GetAttribute(SUMMER_COLOR_ATTRIBUTE)
		if typeof(summerColor) ~= "Color3" then
			summerColor = descendant.Color
			descendant:SetAttribute(SUMMER_COLOR_ATTRIBUTE, summerColor)
		end

		descendant.Color = color or summerColor
	end
end

local function applyFoliageColor(instance: BasePart, color: Color3?)
	local summerColor = instance:GetAttribute(SUMMER_COLOR_ATTRIBUTE)
	if typeof(summerColor) ~= "Color3" then
		summerColor = instance.Color
		instance:SetAttribute(SUMMER_COLOR_ATTRIBUTE, summerColor)
	end

	instance.Color = color or summerColor
	applySurfaceAppearanceColor(instance, color)
end

local function getFoliageModel(instance: Instance): Model?
	if instance:IsA("Model") then
		return instance
	end

	return instance:FindFirstAncestorOfClass("Model")
end

local function applySpringColorToModel(model: Model, source: Instance, instant: boolean?)
	local treeColor = getTreeSeasonColor(source)
	local base = treeColor or model:GetAttribute("SpringColor") or random_bright()

	model:SetAttribute("SpringColor", base)

	for _, modelLeave in model:GetDescendants() do
		if not modelLeave:IsA("BasePart") or not hasFoliageTag(modelLeave) then
			continue
		end

		applyFoliageColor(modelLeave, treeColor or getRandomColorOffseted(base))

		if not instant then
			task.wait()
		end
	end
end

function SeasonController:ChangeSpecificGrassColor(instance)
	if not instance:IsA("BasePart") then
		applySurfaceAppearanceColor(instance, getSeasonalFoliageColor(instance))
		return
	end

	task.spawn(function()
		if CurrentSeason ~= "Spring" or not instance:HasTag("WindShake") then
			return
		end

		local model = getFoliageModel(instance)
		if model then
			applySpringColorToModel(model, instance, true)
		end
	end)

	local terrainColor = SeasonColors[CurrentSeason]

	if terrainColor and CurrentSeason ~= "Spring" then

	else
		terrainColor = Color3.fromRGB(75, 125, 42)
	end

	workspace.Terrain:SetMaterialColor(Enum.Material.Grass, terrainColor)
	workspace.Terrain:SetMaterialColor(Enum.Material.LeafyGrass, terrainColor)


	if hasFoliageTag(instance) then
		if not instance:GetAttribute("DefaultMaterial") then
			instance:SetAttribute("DefaultMaterial", instance.Material.Name)
		end

		local color = getSeasonalFoliageColor(instance)

		if CurrentSeason == "Spring" then
			if not instance:HasTag("WindShake") then
				applyFoliageColor(instance, color)
			end
		else
			applyFoliageColor(instance, color)
		end

		if instance:GetAttribute("DefaultMaterial") == "Ground" and CurrentSeason == "Winter" then
			instance.Material = Enum.Material.Snow
		else
			instance.Material = Enum.Material[instance:GetAttribute("DefaultMaterial")]
		end

	end
end

function SeasonController:ChangeGrassColor(Instant: boolean)
	if CurrentSeason == "Spring" then
		local processedModels = {}

		for _, leave in CollectionService:GetTagged("WindShake") do
			local model = getFoliageModel(leave)
			if not model or processedModels[model] then
				continue
			end

			processedModels[model] = true
			applySpringColorToModel(model, leave, Instant)
		end
	end

	local terrainColor = SeasonColors[CurrentSeason]

	if terrainColor and CurrentSeason ~= "Spring" then
	else
		terrainColor = Color3.fromRGB(75, 125, 42)
	end

	workspace.Terrain:SetMaterialColor(Enum.Material.Grass, terrainColor)
	workspace.Terrain:SetMaterialColor(Enum.Material.LeafyGrass, terrainColor)

	for _, grass: BasePart in getTaggedFoliage() do
		if not grass:IsA("BasePart") then
			applySurfaceAppearanceColor(grass, getSeasonalFoliageColor(grass))
			continue
		end

		if not grass:GetAttribute("DefaultMaterial") then
			grass:SetAttribute("DefaultMaterial", grass.Material.Name)
		end

		local color = getSeasonalFoliageColor(grass)

		if CurrentSeason == "Spring" then
			if not grass:HasTag("WindShake") then
				applyFoliageColor(grass, color)
			end
		else
			applyFoliageColor(grass, color)
		end

		if grass:GetAttribute("DefaultMaterial") == "Ground" and CurrentSeason == "Winter" then
			grass.Material = Enum.Material.Snow
		else
			grass.Material = Enum.Material[grass:GetAttribute("DefaultMaterial")]
		end

        if not Instant then
            task.wait()
        end
	end
end


function SeasonController.KnitInit()
end

function SeasonController.KnitStart()
    repeat
        task.wait()
        CurrentSeason = workspace:GetAttribute("Season")
    until CurrentSeason

    SeasonController:ChangeGrassColor()

    workspace:GetAttributeChangedSignal("Season"):Connect(function()
        CurrentSeason = workspace:GetAttribute("Season")
        SeasonController:ChangeGrassColor()
    end)

	for _, tag in FoliageTags do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			SeasonController:ChangeSpecificGrassColor(instance)
		end)
	end
end

return SeasonController
