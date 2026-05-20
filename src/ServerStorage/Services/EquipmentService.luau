local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local EquipmentService = Knit.CreateService({
	Name = "EquipmentService",
	Client = {},
})

local DataService
local FlagService
local ItemService

local CustomEquipmentFunctions = {

	Flag = function(Character: Model)
		FlagService:LoadFlag(Character)
	end,
}

local EquipmentTypes = {
	"Head",
	"Face",
	"Torso",
	"Legs",
	"Back",
	"Eyes",
	"Waist",
	"Prosthetic",
	"Artifact",
}

EquipmentService.EquipmentTypes = EquipmentTypes

function EquipmentService:GetEquipmentModel(EquipmentName: string)
	return game.ReplicatedStorage.Assets.Equipables:FindFirstChild(EquipmentName, true)
end

function EquipmentService:CheckForMetal(Character: Model)
	local HasMetal = false
	for _, Type in EquipmentTypes do
		local EquipmentName = Character:GetAttribute(Type)
		if not EquipmentName then
			continue
		end

		local ItemData = ItemService:GetItemData(EquipmentName)
		if ItemData.MetalArmor then
			HasMetal = true
			break
		end
	end

	Character:SetAttribute("HasMetalArmor", HasMetal)
end

function EquipmentService:UnloadEquipment(Character: Model, Type: string)
	local Assets = Character.Assets
	if not Character.Assets.Equipables:FindFirstChild(Type) then
		local Folder = Instance.new("Folder")
		Folder.Name = Type
		Folder.Parent = Character.Assets.Equipables
	end

	for _, Model in Assets.Equipables[Type]:GetChildren() do
		if Model:GetAttribute("HidePart0") then
			Character[Model.Name].Transparency = 0
		end
	end

	if Type == "Head" then
		for _, Hair in Character:GetChildren() do
			if Hair.Name == "Hair" then
				for _, Part in Hair:GetDescendants() do
					if not Part:IsA("BasePart") then
						continue
					end
					Part.Transparency = 0
				end
			end
		end
	end

	Character:SetAttribute(Type, nil)
	for _, Asset in Assets.Equipables[Type]:GetChildren() do
		Asset:RemoveTag("SmartBone")
	end
	Assets.Equipables[Type]:ClearAllChildren()

	EquipmentService:CheckForMetal(Character)

	local Player = Players:GetPlayerFromCharacter(Character)

	if Player then
		local PlayerData = DataService:GetData(Player)
		if not PlayerData.Equipped[Type] then
			if Type == "Torso" then
				EquipmentService:LoadEquipment(Character, "Torso", "VillagerShirt")
			elseif Type == "Legs" then
				EquipmentService:LoadEquipment(Character, "Legs", "VillagerPants")
			end
		end
	end
end

function EquipmentService:CheckForShirtOrPants(Character: Model)
	local Player = Players:GetPlayerFromCharacter(Character)

	if Player then
		local PlayerData = DataService:GetData(Player)
		if not PlayerData.Equipped.Torso then
			EquipmentService:LoadEquipment(Character, "Torso", "VillagerShirt")
		end
		if not PlayerData.Equipped.Legs then
			EquipmentService:LoadEquipment(Character, "Legs", "VillagerPants")
		end
	end
end

function EquipmentService:LoadEquipment(Character: Model, Type: string, EquipmentName: string)
	local Player = Players:GetPlayerFromCharacter(Character)

	if Player then
		local PlayerData = DataService:GetData(Player)
		if PlayerData.Equipped[Type] then
			EquipmentService:UnloadEquipment(Character, Type)
		end
	end

	local ItemData = ItemService:GetItemData(EquipmentName)
	if ItemData and ItemData.HideHair then
		if Type == "Head" then
			for _, Hair in Character:GetChildren() do
				if Hair.Name == "Hair" then
					for _, Part in Hair:GetDescendants() do
						if not Part:IsA("BasePart") then
							continue
						end
						Part.Transparency = 1
					end
				end
			end
		end
	end

	Character:SetAttribute(Type, EquipmentName)

	local EquipmentModel = EquipmentService:GetEquipmentModel(EquipmentName)
	if not EquipmentModel then
		return
	end

	for _, part in EquipmentModel:GetChildren() do
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

		if not Character.Assets.Equipables:FindFirstChild(Type) then
			local Folder = Instance.new("Folder")
			Folder.Name = Type
			Folder.Parent = Character.Assets.Equipables
		end
		partClone.Parent = Character.Assets.Equipables[Type]
	end

	if CustomEquipmentFunctions[EquipmentName] then
		CustomEquipmentFunctions[EquipmentName](Character)
	end

	EquipmentService:CheckForMetal(Character)
end

function EquipmentService:LoadEquipmentFromCharacter(Character: Model)
	for _, Type in EquipmentTypes do
		local EquipmentName = Character:GetAttribute(Type)
		if not EquipmentName then
			continue
		end
		EquipmentService:LoadEquipment(Character, Type, EquipmentName)
	end
end

function EquipmentService:LoadEquipments(Player: Player)
	local PlayerData = DataService:GetData(Player)

	local Character = Player.Character
	if not Character then
		return
	end
	for Type, Equipment in PlayerData.Equipped do
		Character:SetAttribute(Type, Equipment)
	end

	EquipmentService:LoadEquipmentFromCharacter(Character)
	EquipmentService:CheckForShirtOrPants(Character)
end

function EquipmentService.KnitInit()
	DataService = Knit.GetService("DataService")
	FlagService = Knit.GetService("FlagService")
	ItemService = Knit.GetService("ItemService")
end

function EquipmentService.KnitStart() end

return EquipmentService
