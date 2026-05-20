local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local MobService = Knit.CreateService({
	Name = "MobService",
	Client = {},
})

local CharacterService
local ValuesService
local WeaponService
local EquipmentService
local HitboxService
local StatusDisplayManager = require(game.ReplicatedStorage.Shared.Utils.StatusDisplayManager)

local MobData = require(game.ReplicatedStorage.Shared.Index.Mobs)
function MobService:SetNetworkOwner(Mob: Model)
	local HumanoidRootPart = Mob:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart and HumanoidRootPart:CanSetNetworkOwnership() then
		HumanoidRootPart:SetNetworkOwnershipAuto(false)
		HumanoidRootPart:SetNetworkOwner(nil)
	end
end

function MobService:GetMobData(Character: Model)
	return MobData[Character:GetAttribute("MobName") or Character.Name]
end

function MobService:LoadAssets(Character: Model)
	WeaponService:LoadWeapon(Character)
	EquipmentService:LoadEquipmentFromCharacter(Character)
end

function MobService:CreateAssetsFolder(Mob: Model)
	local Assets = Mob:FindFirstChild("Assets") or Instance.new("Folder")
	Assets.Name = "Assets"
	Assets.Parent = Mob

	local Weapon = Assets:FindFirstChild("Weapon") or Instance.new("Folder")
	Weapon.Name = "Weapon"
	Weapon.Parent = Assets

	local Equipables = Assets:FindFirstChild("Equipables") or Instance.new("Folder")
	Equipables.Name = "Equipables"
	Equipables.Parent = Assets
end

local Hairs = game.ReplicatedStorage.Assets.Hairs
function MobService:LoadRandomHair(Character: Model, Gender: string)
	local RandomHair = Hairs[Gender]:GetChildren()[math.random(1, #Hairs[Gender]:GetChildren())]
	local Hair = RandomHair:Clone()
	Hair.Parent = Character
end

function MobService:LoadRandomFace(Character: Model, Gender: string)
	local RandomFace = game.ReplicatedStorage.Assets.Faces[Gender]:GetChildren()[math.random(
		1,
		#game.ReplicatedStorage.Assets.Faces[Gender]:GetChildren()
	)]
	local FaceHolder = RandomFace:Clone()

	local Eyes = FaceHolder:FindFirstChild("EyesFace")
	if Eyes then
		Eyes.Color3 = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
	end

	for _, Decal in FaceHolder:GetChildren() do
		Decal.Parent = Character.Head
	end

	FaceHolder:Destroy()
end

function MobService:CreateMob(MobName: string, Equipment: string)
	if not game.ServerStorage.ServerAssets:FindFirstChild("Mobs") then
		return
	end
	local Mob = game.ServerStorage.ServerAssets.Mobs:FindFirstChild(MobName)
	if not Mob then
		return
	end

	local MobClone: Model = Mob:Clone()
	MobClone.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	MobClone:PivotTo(CFrame.new(0, 0, 0))

	local RootPart: BasePart = MobClone:FindFirstChild("HumanoidRootPart")
	if RootPart then
		MobClone.PrimaryPart = RootPart
	end

	MobClone.Parent = workspace
	MobClone:SetAttribute("IsAI", true)
	MobClone:SetAttribute("MobId", MobName .. "_" .. HttpService:GenerateGUID(false))

	MobService:CreateAssetsFolder(MobClone)

	CharacterService:SetAttributes(MobClone)

	if MobClone:GetAttribute("HitboxType") == "R6" then
		HitboxService:LoadR6Hitbox(MobClone)
	end

	if Equipment then
		local Config = script.Parent.Configs:WaitForChild(Equipment)

		if not Config then
			return
		end

		local Config = require(Config)

		for Attribute, Equipments in Config.Equipment or {} do
			local Equipment = Equipments[math.random(1, #Equipments)]

			if Equipment == "None" then
				Equipment = nil
			end

			MobClone:SetAttribute(Attribute, Equipment)
		end
	end

	MobService:SetNetworkOwner(MobClone)

	CharacterService:SetStates(MobClone)
	CharacterService:BindEvents(MobClone)
	ValuesService:UpdateAll(MobClone, true)
	CharacterService:BindRegeneration(MobClone)

	MobService:LoadAssets(MobClone)

	MobClone:SetAttribute("MobName", MobName)

	CharacterService:SetCollisionGroup(MobClone)

	MobService:SetNetworkOwner(MobClone)
	MobClone.Parent = nil

	MobClone:GetPropertyChangedSignal("Parent"):Connect(function()
		if MobClone and MobClone.Parent == workspace.Entity then
			MobService:SetNetworkOwner(MobClone)
		end
	end)

	Mob.HumanoidRootPart:GetPropertyChangedSignal("Anchored"):Connect(function()
		if not Mob.HumanoidRootPart.Anchored then
			MobService:SetNetworkOwner(MobClone)
		end
	end)

	local Humanoid: Humanoid = MobClone:FindFirstChild("Humanoid")
	Humanoid.NameOcclusion = Enum.NameOcclusion.OccludeAll
	Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	if MobName == "Bandit" then
		MobService:LoadRandomHair(MobClone, "Male")
		MobService:LoadRandomFace(MobClone, "Male")
	end

	return MobClone
end

function MobService:SpawnMob(MobName: string, Location: CFrame, Equipment: string?)
	local MobClone = MobService:CreateMob(MobName, Equipment)

	MobClone:PivotTo(Location)
	MobClone.Parent = workspace.Entity

	return MobClone
end

function MobService.KnitInit()
	CharacterService = Knit.GetService("CharacterService")
	ValuesService = Knit.GetService("ValuesService")
	WeaponService = Knit.GetService("WeaponService")
	EquipmentService = Knit.GetService("EquipmentService")
	HitboxService = Knit.GetService("HitboxService")
end

function MobService.KnitStart() end

return MobService
