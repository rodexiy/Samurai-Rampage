local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local EquipmentService = Knit.CreateService({
	Name = "EquipmentService",
	Client = {},
})

local DataService
local ItemService

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

function EquipmentService:SetEquipmentAttribute(Character: Model, Type: string, EquipmentName: string?)
	Character:SetAttribute(Type, EquipmentName)
	EquipmentService:CheckForMetal(Character)
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
	EquipmentService:SetEquipmentAttribute(Character, Type, nil)

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

	EquipmentService:SetEquipmentAttribute(Character, Type, EquipmentName)
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

	EquipmentService:CheckForMetal(Character)
	EquipmentService:CheckForShirtOrPants(Character)
end

function EquipmentService.KnitInit()
	DataService = Knit.GetService("DataService")
	ItemService = Knit.GetService("ItemService")
end

function EquipmentService.KnitStart() end

return EquipmentService
