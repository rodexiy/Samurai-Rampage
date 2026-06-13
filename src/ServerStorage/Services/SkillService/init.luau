local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SkillService = Knit.CreateService({
	Name = "SkillService",
	Client = {},
})

local InventoryService
local AlertService
local ItemService
local RaceService
local ArtifactService
local DataService

local Skills = {}
local SkillDatas = {}
local AttackOverwrites = {}

function SkillService:GetAttackOverwrite(Character: Model)
	return AttackOverwrites[Character]
end

function SkillService:GetGroundInMousePosition(MousePosition: Vector3, AmountDown: number)
	local AmountDown = AmountDown or 10
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { workspace.Entity, workspace.FaceHeadFolder }

	local RaycastResult = workspace:Raycast(MousePosition, Vector3.new(0, -AmountDown, 0), Params)

	if RaycastResult then
		return RaycastResult.Position, RaycastResult
	end
end

function SkillService:GetPositionInRange(Reference: Vector3, MousePosition: Vector3, MaxDistance: number)
	local MaxDistance = MaxDistance or 80
	local Distance = math.min((Reference - MousePosition).Magnitude, MaxDistance)

	return (CFrame.new(Reference, MousePosition) * CFrame.new(0, 0, -Distance)).Position
end

local WaitingForRelease = {}
function SkillService:WaitForRelease(Character: Model, Skill: string)
	if WaitingForRelease[Character] == Skill then
		return
	end

	WaitingForRelease[Character] = Skill
	repeat
		task.wait(0.1)
	until SkillService:GetSkillState(Character, Skill) ~= "Charge"

	WaitingForRelease[Character] = nil

	if SkillService:GetSkillState(Character, Skill) == nil then
		return false
	end

	return true
end

function SkillService:UseSkill(Character: Model, SkillName: string, Data: { any })
	if not Skills[SkillName] then
		return
	end

	if not Character:GetAttribute("IsAI") then
		local _Player = Players:GetPlayerFromCharacter(Character)
		local SkillData = ItemService:GetItemData(SkillName)
		if _Player and not InventoryService:GetPlayerItemByName(_Player, SkillName) then
			return
		end
	end

	if not Data then
		Data = {
			RootCFrame = Character:GetPivot(),
			MousePosition = Character:GetAttribute("MousePosition"),
		}
	end
	if not Data.RootCFrame then
		Data.RootCFrame = Character:GetPivot()
		Data.MousePosition = Character:GetAttribute("MousePosition")
	end

	if not Data.MousePosition then
		if Data.MouseHit then
			Data.MousePosition = Data.MouseHit.Position
		else
			Data.MousePosition = Character:GetAttribute("MousePosition")
		end
	end

	return Skills[SkillName].Caller(Character, Data)
end
function SkillService.Client:UseSkill(Player: Player, SkillName: string, Data: { any })
	local Character = Player.Character
	if not Character then
		return
	end

	self.Server:UseSkill(Character, SkillName, Data)
end

function SkillService:GetSkillsDataForCharacter(Character: Model)
	if not SkillDatas[Character] then
		SkillDatas[Character] = {}
	end

	return SkillDatas[Character]
end
function SkillService:GetSkillState(Character: Model, Skill: string)
	if not SkillDatas[Character] then
		SkillDatas[Character] = {}
	end

	return SkillDatas[Character][Skill]
end

function SkillService:SetSkillData(Character: Model, skillName: string, state: string)
	local SkillData = SkillService:GetSkillsDataForCharacter(Character)
	SkillData[skillName] = state
	Character:SetAttribute("SkillState", state)
	return SkillData[skillName]
end

--skill no state Charge poderão ser canceladas
function SkillService:TryCancelSkillData(Character: Model)
	local SkillData = SkillService:GetSkillsDataForCharacter(Character)
	for skill, state in pairs(SkillData) do
		if state == "Charge" then
			Character:SetAttribute("SkillLockMovement", false)
			Character:SetAttribute("UnlockMouse", true)
			task.delay(0.25, function()
				Character:SetAttribute("UnlockMouse", nil)
			end)

			SkillService:SetSkillData(Character, skill, nil)

			if Skills[skill] and Skills[skill].Cancel then
				Skills[skill].Cancel(Character)
			end
		end
	end
end
-- usar quando o humanoid morrer

function SkillService:ClearSkillData(Character: Model)
	if not SkillDatas[Character] then
		return
	end
	for k in SkillDatas[Character] do
		SkillDatas[Character][k] = nil
	end

	self:RemoveAttackOverwrite(Character)

	SkillDatas[Character] = nil
end

function SkillService:SetAttackOverwrite(Character: Model, func: any)
	AttackOverwrites[Character] = func
end
function SkillService:RemoveAttackOverwrite(Character: Model)
	AttackOverwrites[Character] = nil
end

function SkillService:LoadSkills(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	local PlayerData = DataService:GetData(Player)

	local RaceSkills = RaceService:GetRaceData(Character:GetAttribute("Race")).Skills
	local ArtifactData = ArtifactService:GetArtifactData(PlayerData.Artifact)

	for _, skill in PlayerData.Inventory do
		local skillData = ItemService:GetItemData(skill.Name)
		if
			skillData.Requirements
			and skillData.Requirements.Race
			and skillData.Requirements.Race ~= Character:GetAttribute("Race")
		then
			InventoryService:RemoveItemFromPlayer(Player, skill.Name, skill.Stack)
		end
	end

	if RaceSkills then
		for _, skill in RaceSkills do
			if InventoryService:GetPlayerItemByName(Player, skill) then
				continue
			end

			InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem(skill, 1))
		end
	end

	if ArtifactData then
		for _, skill in ArtifactData.Skills or {} do
			if InventoryService:GetPlayerItemByName(Player, skill) then
				continue
			end

			InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem(skill, 1))
		end
	end
end

local MousePositionUpdater = game.ReplicatedStorage.Assets.Public.MousePositionUpdater :: UnreliableRemoteEvent

function SkillService.KnitInit()
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	AlertService = Knit.GetService("AlertService")
	ItemService = Knit.GetService("ItemService")
	RaceService = Knit.GetService("RaceService")
	ArtifactService = Knit.GetService("ArtifactService")
end

function SkillService.KnitStart()
	for _, v in script:GetDescendants() do
		if v:IsA("ModuleScript") then
			Skills[v.Name] = require(v)
		end
	end

	for _, v in Skills do
		if v.Start then
			v.Start(Skills)
		end
	end

	MousePositionUpdater.OnServerEvent:Connect(function(Player, Position)
		local Character = Player.Character
		if not Character then
			return
		end

		Character:SetAttribute("MousePosition", Position)
	end)
end

return SkillService
