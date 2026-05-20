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
	Winter = Color3.fromRGB(255, 255, 255),
	Autumn = Color3.fromRGB(224, 125, 4),
	Spring = Color3.fromRGB(15, 115, 7),
}

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

function SeasonController:ChangeSpecificGrassColor(instance)
      task.spawn(function()
		if instance:HasTag("WindShake") then

			if CurrentSeason == "Spring" then
				local model = instance.Parent
				if model:IsA("Model") then
					local base = model:GetAttribute("SpringColor") or random_bright()
                    model:SetAttribute("SpringColor", base)
                    
					for _, modelLeave in model:GetDescendants() do
						if modelLeave:GetAttribute("SpringRandomized") then
							break
						end

						if modelLeave:IsA("BasePart") then
							if not modelLeave:HasTag("Grass") then
								continue
							end
							modelLeave.Color = getRandomColorOffseted(base)
							modelLeave:SetAttribute("SpringRandomized", true)
						end
					end
				end
			end
		end
	end)

	local terrainColor = SeasonColors[CurrentSeason]

	if terrainColor and CurrentSeason ~= "Spring" then
		terrainColor = Color3.fromRGB(
			math.max(terrainColor.R * 255 + 20, 0),
			math.max(terrainColor.G * 255 + 20, 0),
			math.max(terrainColor.B * 255 + 20, 0)
		)
	else
		terrainColor = Color3.fromRGB(111, 126, 62)
	end

	workspace.Terrain:SetMaterialColor(Enum.Material.Grass, terrainColor)


	if instance:HasTag("Grass") then
		if not instance:GetAttribute("DefaultColor") then
			instance:SetAttribute("DefaultColor", instance.Color)
			instance:SetAttribute("DefaultMaterial", instance.Material.Name)
		end

		local color = SeasonColors[CurrentSeason]

		if color then
			color = getRandomColorOffseted(color)
		else
			color = instance:GetAttribute("DefaultColor")
		end

		if CurrentSeason == "Spring" then
			if not instance:HasTag("WindShake") then
				instance.Color = color or instance:GetAttribute("DefaultColor")
			end
		else
			instance:SetAttribute("SpringRandomized", nil)
            instance.Parent.Parent:SetAttribute("SpringColor", nil)

			instance.Color = color
		end

		if instance:GetAttribute("DefultMaterial") == "Ground" and CurrentSeason == "Winter" then
			instance.Material = Enum.Material.Snow
		else
			instance.Material = Enum.Material[instance:GetAttribute("DefaultMaterial")]
		end

	end
end

function SeasonController:ChangeGrassColor(Instant: boolean)
    for _, leave: BasePart in CollectionService:GetTagged("WindShake") do
        if CurrentSeason == "Spring" then
            local model = leave.Parent
            if model and model:IsA("Model") then
                local base = model:GetAttribute("SpringColor") or random_bright()
                model:SetAttribute("SpringColor", base)

                for _, modelLeave in model:GetDescendants() do
                    if modelLeave:GetAttribute("SpringRandomized") then
                        break
                    end

                    if modelLeave:IsA("BasePart") then
                        if not modelLeave:HasTag("Grass") then
                            continue
                        end
                        modelLeave.Color = getRandomColorOffseted(base)
                        modelLeave:SetAttribute("SpringRandomized", true)
                        if not Instant then
                            task.wait()
                        end
                    end
                end
            end
        end
    end

	local terrainColor = SeasonColors[CurrentSeason]

	if terrainColor and CurrentSeason ~= "Spring" then
		terrainColor = Color3.fromRGB(
			math.max(terrainColor.R * 255 + 20, 0),
			math.max(terrainColor.G * 255 + 20, 0),
			math.max(terrainColor.B * 255 + 20, 0)
		)
	else
		terrainColor = Color3.fromRGB(111, 126, 62)
	end

	workspace.Terrain:SetMaterialColor(Enum.Material.Grass, terrainColor)

	for _, grass: BasePart in CollectionService:GetTagged("Grass") do
		if not grass:GetAttribute("DefaultColor") then
			grass:SetAttribute("DefaultColor", grass.Color)
			grass:SetAttribute("DefaultMaterial", grass.Material.Name)
		end

		local color = SeasonColors[CurrentSeason]

		if color then
			color = getRandomColorOffseted(color)
		else
			color = grass:GetAttribute("DefaultColor")
		end

		if CurrentSeason == "Spring" then
			if not grass:HasTag("WindShake") then
				grass.Color = color or grass:GetAttribute("DefaultColor")
			end
		else
			grass:SetAttribute("SpringRandomized", nil)
			grass.Color = color
		end

		if grass:GetAttribute("DefultMaterial") == "Ground" and CurrentSeason == "Winter" then
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

    CollectionService:GetInstanceAddedSignal("Grass"):Connect(function(instance)
        SeasonController:ChangeSpecificGrassColor(instance)
    end)
end

return SeasonController