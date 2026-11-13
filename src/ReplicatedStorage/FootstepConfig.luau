local FootstepConfig = {
	AudibleDistance = 60,
	RollOffMinDistance = 5,
	VoicesPerLayer = 2,
	PreloadedVoicesPerSound = 2,
	MaximumVoicesPerSound = 8,
	MinimumStepInterval = 0.045,
	MinimumSpeed = 0.5,
	MinimumTrackWeight = 0.1,
	ProbeHeight = 0.35,
	ProbeDepth = 0.75,
	FootprintLifetime = 5,
	MaximumFootprints = 64,
	Volume = 0.25,
	GrassVolume = 0.175,
	ArmorVolume = 0.275,
	MinimumPitch = 0.95,
	MaximumPitch = 1.05,
	Marker = "Step",
	AnimationNames = { walk = true, run = true, running = true },
	BlockedAttributes = {
		"Mounted", "InHorse", "Died", "Downed", "Ragdoll", "Rolling", "RollClientDebounce", "Meditating",
	},
	FootprintMaterials = {
		[Enum.Material.Sand] = true,
		[Enum.Material.Snow] = true,
		[Enum.Material.Mud] = true,
	},
}

local FootstepLibrary = {
	[Enum.Material.Fabric] = {
		"rbxassetid://9126748130",
		"rbxassetid://9126747861",
		"rbxassetid://9126747720",
		"rbxassetid://9126747529",
	},

	[Enum.Material.Concrete] = {
		"rbxassetid://9126746167",
		"rbxassetid://9126746098",
		"rbxassetid://9126745995",
		"rbxassetid://9126745877",
	},

	[Enum.Material.Ground] = {
		"rbxassetid://9126744390",
		"rbxassetid://9126744718",
		"rbxassetid://9126744263",
		"rbxassetid://9126744157",
	},

	[Enum.Material.Glass] = {
		"rbxassetid://9126742971",
		"rbxassetid://9126742461",
		"rbxassetid://9126742875",
		"rbxassetid://9126742786",
	},

	[Enum.Material.Grass] = {
		"rbxassetid://9126742396",
		"rbxassetid://9126741427",
		"rbxassetid://9126742333",
		"rbxassetid://9126742215",
	},

	[Enum.Material.Metal] = {
		"rbxassetid://9126736470",
		"rbxassetid://9126734921",
		"rbxassetid://9126736274",
		"rbxassetid://9126736354",
	},

	[Enum.Material.Sand] = {
		"rbxassetid://9126733118",
		"rbxassetid://9126733408",
		"rbxassetid://9126733225",
	},

	[Enum.Material.Snow] = {
		"rbxassetid://9126732128",
		"rbxassetid://9126731099",
		"rbxassetid://9126732016",
	},

	[Enum.Material.CeramicTiles] = {
		"rbxassetid://9126730713",
		"rbxassetid://9126730782",
		"rbxassetid://9126731037",
		"rbxassetid://9126730980",
	},

	[Enum.Material.Wood] = {
		"rbxassetid://9126931624",
		"rbxassetid://9126931515",
		"rbxassetid://9126931417",
		"rbxassetid://9126931322",
	},

	[Enum.Material.Foil] = {
		"rbxassetid://9117941991",
		"rbxassetid://9126206046",
		"rbxassetid://9117941618",
	},

	MetalArmor = {
		"rbxassetid://110129591935584",
		"rbxassetid://126117292523764",
		"rbxassetid://72214847101361",
		"rbxassetid://94149035850177",
		"rbxassetid://123030876157106",
	},
}

FootstepLibrary[Enum.Material.LeafyGrass] = FootstepLibrary[Enum.Material.Grass]
FootstepLibrary[Enum.Material.WoodPlanks] = FootstepLibrary[Enum.Material.Wood]
FootstepLibrary[Enum.Material.Slate] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.Cobblestone] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.Rock] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.Asphalt] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.Basalt] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.Brick] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.Cardboard] = FootstepLibrary[Enum.Material.Fabric]
FootstepLibrary[Enum.Material.ClayRoofTiles] = FootstepLibrary[Enum.Material.CeramicTiles]
FootstepLibrary[Enum.Material.CorrodedMetal] = FootstepLibrary[Enum.Material.Metal]
FootstepLibrary[Enum.Material.SmoothPlastic] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.Plastic] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.Sandstone] = FootstepLibrary[Enum.Material.Sand]
FootstepLibrary[Enum.Material.Salt] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.Rubber] = FootstepLibrary[Enum.Material.Fabric]
FootstepLibrary[Enum.Material.Pebble] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.Mud] = FootstepLibrary[Enum.Material.Ground]
FootstepLibrary[Enum.Material.Granite] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.DiamondPlate] = FootstepLibrary[Enum.Material.Metal]
FootstepLibrary[Enum.Material.Marble] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.CrackedLava] = FootstepLibrary[Enum.Material.Concrete]
FootstepLibrary[Enum.Material.Ice] = FootstepLibrary[Enum.Material.Glass]
FootstepLibrary[Enum.Material.Glacier] = FootstepLibrary[Enum.Material.Glass]
FootstepLibrary[Enum.Material.Leather] = FootstepLibrary[Enum.Material.Fabric]
FootstepLibrary[Enum.Material.Limestone] = FootstepLibrary[Enum.Material.Concrete]

FootstepConfig.Sounds = FootstepLibrary

function FootstepConfig.GetSounds(Material: Enum.Material): { string }?
	if Material == Enum.Material.Air or Material == Enum.Material.Water then
		return nil
	end

	return FootstepLibrary[Material] or FootstepLibrary[Enum.Material.Concrete]
end

function FootstepConfig.GetVolume(Material: Enum.Material): number
	return if Material == Enum.Material.Grass or Material == Enum.Material.LeafyGrass
		then FootstepConfig.GrassVolume else FootstepConfig.Volume
end

return FootstepConfig
