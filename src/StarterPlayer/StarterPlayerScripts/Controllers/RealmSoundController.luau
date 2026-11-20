local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Building = require(ReplicatedStorage.Shared.RealmBuilding)

local RealmSoundController = Knit.CreateController({ Name = "RealmSoundController" })
local SoundEffectController
local Templates: { [string]: Sound } = {}
local SOUND_IDS = {
	Wood = "rbxassetid://100885263044327",
	Stone = "rbxassetid://17806433387",
	Vegetation = "rbxassetid://6644702473",
	Delete = "rbxassetid://81689681804306",
}
local MATERIAL_TYPES = {
	[Enum.Material.Wood] = "Wood",
	[Enum.Material.WoodPlanks] = "Wood",
	[Enum.Material.Rock] = "Stone",
	[Enum.Material.Basalt] = "Stone",
	[Enum.Material.Slate] = "Stone",
	[Enum.Material.Sandstone] = "Stone",
	[Enum.Material.Limestone] = "Stone",
	[Enum.Material.Granite] = "Stone",
	[Enum.Material.Marble] = "Stone",
	[Enum.Material.Cobblestone] = "Stone",
	[Enum.Material.Brick] = "Stone",
	[Enum.Material.Concrete] = "Stone",
	[Enum.Material.Grass] = "Vegetation",
	[Enum.Material.LeafyGrass] = "Vegetation",
}

function RealmSoundController:GetBuildSound(Asset: PVInstance, Category: string?): string?
	local Wood = Asset:GetAttribute("Cost_WoodLog")
	local Stone = Asset:GetAttribute("Cost_Stone")
	local Fiber = Asset:GetAttribute("Cost_PlantFiber")
	Wood = if typeof(Wood) == "number" then Wood else 0
	Stone = if typeof(Stone) == "number" then Stone else 0
	Fiber = if typeof(Fiber) == "number" then Fiber else 0
	if Category == "Vegetation" or Asset:GetAttribute("Category") == "Vegetation"
		or (Fiber > 0 and Wood == 0 and Stone == 0) then
		return "Vegetation"
	end
	if Stone > Wood then
		return "Stone"
	elseif Wood > 0 then
		return "Wood"
	end

	local Volumes: { [string]: number } = {}
	local LargestVolume = 0
	local SoundType: string? = nil
	for _, Part in Building.GetParts(Asset) do
		local MaterialType = MATERIAL_TYPES[Part.Material]
		if MaterialType and Part.Transparency < 1 then
			local Size = Part.Size
			local Volume = (Volumes[MaterialType] or 0) + Size.X * Size.Y * Size.Z
			Volumes[MaterialType] = Volume
			if Volume > LargestVolume then
				LargestVolume, SoundType = Volume, MaterialType
			end
		end
	end

	return SoundType
end

function RealmSoundController.KnitInit()
	SoundEffectController = Knit.GetController("SoundEffectController")
end

function RealmSoundController.KnitStart()
	local Folder = Instance.new("Folder")
	Folder.Name = "RealmSounds"
	Folder.Parent = SoundService
	for Name, Id in SOUND_IDS do
		local Sound = Instance.new("Sound")
		Sound.Name = Name
		Sound.SoundId = Id
		Sound.Volume = 0.5
		Sound.Parent = Folder
		Templates[Name] = Sound
	end

	Knit.GetController("RealmPlacementController").Placed:Connect(function(Asset: PVInstance, Category: string)
		local SoundType = RealmSoundController:GetBuildSound(Asset, Category)
		if SoundType then
			SoundEffectController:PlaySoundEffect(Templates[SoundType], true, SoundService)
		end
	end)
	Knit.GetController("RealmDeletionController").Completed:Connect(function(Success: boolean)
		if Success then
			SoundEffectController:PlaySoundEffect(Templates.Delete, true, SoundService)
		end
	end)
end

return RealmSoundController
