local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ArtifactService = Knit.CreateService({ Name = "ArtifactService", Client = {} })
local ItemService, SkillService, SkillTreeService, DataService, EquipmentService

function ArtifactService:ResetArtifact(Player: Player)
	local PlayerData = DataService:GetData(Player)
	local ArtifactName = PlayerData and PlayerData.Artifact
	if not ArtifactName then
		return
	end

	SkillTreeService:ResetSpecificSkillTree(Player, ArtifactName:gsub(" ", ""))
	PlayerData.Artifact = nil

	local Character = Player.Character
	if Character then
		Character:SetAttribute("Artifact", nil)
		EquipmentService:UnloadEquipment(Character, "Artifact")
	end
	SkillService:LoadSkills(Player)
end

function ArtifactService:GetArtifactData(ArtifactName: string?): { [string]: any }?
	return if ArtifactName then ItemService:GetItemData(ArtifactName) else nil
end

function ArtifactService.KnitInit()
	DataService = Knit.GetService("DataService")
	ItemService = Knit.GetService("ItemService")
	SkillService = Knit.GetService("SkillService")
	SkillTreeService = Knit.GetService("SkillTreeService")
	EquipmentService = Knit.GetService("EquipmentService")
end

return ArtifactService
