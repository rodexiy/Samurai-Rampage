local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local player = game.Players.LocalPlayer :: Player
local character = player.Character :: Model
local HumanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
local Humanoid = character:WaitForChild("Humanoid") :: Humanoid

local Knit = require(game.ReplicatedStorage.Packages.Knit)

Knit.OnStart():await()
local SoundEffectController = Knit.GetController("SoundEffectController")

local RunningSound = HumanoidRootPart:WaitForChild("Running")

RunningSound.Volume = 0

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

local FootstepFolder = Instance.new("Folder")
FootstepFolder.Name = "Footsteps"
FootstepFolder.Parent = HumanoidRootPart

local SoundInstances = {}

local lastSoundId = nil
function getMoreRandomSound(materialArray)
	local soundId = nil
	if not materialArray or #materialArray == 0 then
		return
	end
	repeat
		soundId = materialArray[math.random(1, #materialArray)]
		task.wait()
	until lastSoundId ~= soundId
	lastSoundId = soundId
	return soundId
end

function createSound(soundId, parent)
	local sound = Instance.new("Sound")
	sound.Volume = 0.25
	sound.SoundId = soundId
	sound.Parent = parent

	repeat
		task.wait()
	until sound.IsLoaded

	return sound
end

for index, material in FootstepLibrary do
	task.spawn(function()
		local Name = if type(index) == "string" then index else index.Name
		SoundInstances[Name] = {}

		for _, soundId in material do
			local Sound = createSound(soundId, character.PrimaryPart)
			if Name == "MetalArmor" then
				Sound.Volume = 0.275
			elseif Name == "Grass" then
				Sound.Volume = 0.175
			end
			table.insert(SoundInstances[Name], Sound)
			Sound.Name = _
		end
	end)
end

local RightLeg = character:WaitForChild("Right Leg")
local LeftLeg = character:WaitForChild("Left Leg")

local Legs = {
	RightLeg,
	LeftLeg,
}

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.RespectCanCollide = true

local ValidFootstepMaterials = {
	Enum.Material.Sand,
	Enum.Material.Snow,
	Enum.Material.Mud,
}

local RootPart = character:WaitForChild("HumanoidRootPart")
local StepPart = game.ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Models"):WaitForChild("Footstep")
local function FootstepEffect()
	RayParams.FilterDescendantsInstances = { workspace.Entity }

	local didOne = false
	for _, Leg in Legs do
		if didOne then
			break
		end
		local FootCFrame = Leg.CFrame * CFrame.new(0, -0.9, 0)
		local ray: RaycastResult = workspace:Raycast(FootCFrame.Position, -(FootCFrame.UpVector * 0.3), RayParams)

		if ray then
			if table.find(ValidFootstepMaterials, ray.Material) then
				local StepPart = StepPart:Clone()
				local x = RootPart.CFrame:ToOrientation()
				local Position = CFrame.new(ray.Position, ray.Position + ray.Normal).Position
				StepPart.CFrame = CFrame.new(Position, Position + RootPart.CFrame.LookVector)
				StepPart.Anchored = true
				StepPart.Parent = workspace
				didOne = true
				Debris:AddItem(StepPart, 5)
			end
		end
	end
end


local Animator = Humanoid:WaitForChild("Animator")

local FootstepAnimationNames = {
	walk = true,
	run = true,
	running = true,
}

local function PlayFootstepSound()
	if Humanoid.FloorMaterial == Enum.Material.Air then
		return
	end

	if Humanoid.MoveDirection.Magnitude <= 0 then
		return
	end

	if Humanoid:GetAttribute("Rolling") or RootPart.Anchored then
		return
	end

	local materialArray = SoundInstances[Humanoid.FloorMaterial.Name]
	local sound = getMoreRandomSound(materialArray)

	if not sound then
		return
	end

	FootstepEffect()

	sound:Play()
	SoundEffectController:AddPitchEffect(sound, 0.95, 1.05)

	if character:GetAttribute("HasMetalArmor") then
		local metalArmorSound = getMoreRandomSound(SoundInstances.MetalArmor)

		if metalArmorSound then
			metalArmorSound:Play()
			SoundEffectController:AddPitchEffect(metalArmorSound, 0.95, 1.05)
		end
	end
end

local ConnectedTracks = {}

local function ConnectFootstepTrack(track: AnimationTrack)
	if ConnectedTracks[track] then
		return
	end

	local animation = track.Animation
	if not animation then
		return
	end

	local name = string.lower(animation.Name)

	if not FootstepAnimationNames[name] then
		return
	end

	ConnectedTracks[track] = true

	track:GetMarkerReachedSignal("Step"):Connect(function()
		PlayFootstepSound()
		FootstepEffect()
	end)

	track.Stopped:Connect(function()
		ConnectedTracks[track] = nil
	end)
end

for _, track in Animator:GetPlayingAnimationTracks() do
	ConnectFootstepTrack(track)
end

Animator.AnimationPlayed:Connect(function(track)
	ConnectFootstepTrack(track)
end)
