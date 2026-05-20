local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RaceService = Knit.CreateService({
	Name = "RaceService",
	Client = {},
})

local RewardService
local InventoryService
local ItemService
local SkillService
local CharacterService
local DataService

local Races = require(game.ReplicatedStorage.Shared.Index.Races)
local RaceAssets = game.ReplicatedStorage.Assets.Races

local RaceFunctionsAdd = {
	Oni = function(Character: Model)
		for _, Hair in Character:GetChildren() do
			if Hair:IsA("Accessory") then
				local SpecialMesh: SpecialMesh = Hair:FindFirstChild("SpecialMesh", true)
				if SpecialMesh then
					SpecialMesh:SetAttribute("TextureId", SpecialMesh.TextureId)
					SpecialMesh.Parent:SetAttribute("Color", SpecialMesh.Parent.Color)

					SpecialMesh.TextureId = ""
					SpecialMesh.Parent.Color = Color3.fromRGB(222, 222, 222)
				end
			end
		end
	end,
}

local RaceFunctionsRem = {
	Oni = function(Character: Model)
		for _, Hair in Character:GetChildren() do
			if Hair:IsA("Accessory") then
				local SpecialMesh: SpecialMesh = Hair:FindFirstChild("SpecialMesh", true)
				if SpecialMesh then
					SpecialMesh.TextureId = SpecialMesh:GetAttribute("TextureId")
					SpecialMesh.Parent.Color = SpecialMesh.Parent:GetAttribute("Color")
				end
			end
		end
	end,
}

function RaceService:UnloadRace(Character: Model)
	local Assets = Character.Assets
	if not Character.Assets:FindFirstChild("Race") then
		local Folder = Instance.new("Folder")
		Folder.Name = "Race"
		Folder.Parent = Character.Assets
	end

	Assets.Race:ClearAllChildren()
end

function RaceService:GetRaceModel(Character: Model)
	local RaceModel = RaceAssets:FindFirstChild(Character:GetAttribute("Race"))
		:FindFirstChild(Character:GetAttribute("RaceVariant"))
	return RaceModel
end

function RaceService:LoadRace(Character: Model)
	RaceService:UnloadRace(Character)

	local RaceModel = RaceService:GetRaceModel(Character)
	if not RaceModel then
		return
	end

	local RaceBodyColors = RaceModel:FindFirstChildWhichIsA("BodyColors")

	local Player = Players:GetPlayerFromCharacter(Character)
	if RaceBodyColors then
		local CharBodyColors = Character:FindFirstChildWhichIsA("BodyColors")
		if CharBodyColors then
			CharBodyColors:Destroy()
		end
		local RaceBodyColors = RaceBodyColors:Clone()
		RaceBodyColors.Parent = Character
	elseif Player then
		CharacterService:LoadHairByUserId(Character, Player.UserId)
	end

	for _, part in RaceModel:GetChildren() do
		if part:IsA("BodyColors") then
			continue
		end
		if not Character:FindFirstChild(part.Name) or part.Name == "Parts" then
			continue
		end

		local CharacterPart = Character[part.Name]
		local partClone = part:Clone()

		for _, part in partClone:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Anchored = false
				part.Massless = true
			end
		end

		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = CharacterPart

		if partClone:IsA("Model") then
			Weld.Part1 = partClone.PrimaryPart
			Weld.Parent = partClone.PrimaryPart

			if partClone:GetAttribute("HidePart0") then
				CharacterPart.Transparency = 1
			end
		else
			if partClone:GetAttribute("HidePart0") then
				CharacterPart.Transparency = 1
			end

			Weld.Part1 = partClone
			Weld.Parent = partClone
		end

		partClone:PivotTo(CharacterPart:GetPivot())

		if not Character.Assets.Race then
			local Folder = Instance.new("Folder")
			Folder.Name = "Type"
			Folder.Parent = Character.Assets
		end
		partClone.Parent = Character.Assets.Race
	end

	local CharacterAssets = Character:FindFirstChild("Assets")
	if not CharacterAssets then
		return
	end
	local Race = CharacterAssets.Race
	local Pupil = Race:FindFirstChild("Pupil", true)

	if Pupil then
		Pupil.Color = Character:GetAttribute("EyesColor")
	end
end

function RaceService:LoadRaceAssets(Character: Model)
	local Race = Character:GetAttribute("Race")
	local OldRace = Character:GetAttribute("OldRace")
	if OldRace and RaceFunctionsRem[OldRace] then
		RaceFunctionsRem[OldRace](Character)
	end

	if RaceFunctionsAdd[Race] then
		RaceFunctionsAdd[Race](Character)
	end

	RaceService:LoadRace(Character)
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player then
		SkillService:LoadSkills(Player)
	end
end

function RaceService:RollRandomRace(Player: Player)
	local Race = RewardService:GetRandomRewardFromWeight(Races)

	DataService:GetData(Player).Race = Race
	RaceService:RollRandomVariant(Player)

	local Character = Player.Character
	if Character then
		if Character:GetAttribute("Race") then
			Character:SetAttribute("OldRace", Character:GetAttribute("Race"))
		end
		Character:SetAttribute("Race", Race)

		self:LoadRaceAssets(Character)
	end

	return Race
end

function RaceService:RollRandomVariant(Player: Player)
	local Character = Player.Character
	local PlayerData = DataService:GetData(Player)

	local Race = PlayerData.Race
	local Assets = RaceAssets:FindFirstChild(Race)
	if Assets then
		local Variants = Assets:GetChildren()
		local Variant = Variants[math.random(1, #Variants)]

		PlayerData.RaceVariant = Variant.Name

		if Character then
			Character:SetAttribute("RaceVariant", Variant.Name)
		end
	end
end

function RaceService:GetRaceData(RaceName: string)
	return Races[RaceName]
end

function RaceService.KnitInit()
	RewardService = Knit.GetService("RewardService")
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	ItemService = Knit.GetService("ItemService")
	SkillService = Knit.GetService("SkillService")
	CharacterService = Knit.GetService("CharacterService")
end

function RaceService.KnitStart() end

return RaceService
