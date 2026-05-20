local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local PlayerService = Knit.CreateService({
	Name = "PlayerService",
	Client = {},
})

local DataService
local CharacterService
local ValuesService
local ItemService
local InventoryService
local GamepassService
local QuestService
local SettingsService
local PartyService
local RaceService
local PlaceService
local SkillTreeService
local MissionBoardService
local PrisonService
local RealmService

function PlayerService:PlayerAdded(Player: Player)
	if Player:HasTag("Player") then
		return
	end
	Player:AddTag("Player")

	if PlaceService:IsTrading() then
		Player:SetAttribute("CantAttack", true)
	end

	DataService:LoadData(Player)

	repeat
		task.wait()
	until DataService:IsDataLoaded(Player)

	local PlayerData = DataService:GetData(Player)

	SettingsService:LoadSettings(Player)

	GamepassService:LoadAttributes(Player)
	SkillTreeService:LoadAttributes(Player)
	self:CheckFirstJoin(Player)

	CharacterService:LoadCharacter(Player)

	Player:SetAttribute("Bounty", PlayerData.Bounty)
	Player:SetAttribute("Loaded", true)
end

local CommonKimonos = {
	"BeigeKimono",
	"BlueKimono",
	"GreenKimono",
	"RedKimono",
	"DarkKimono",
}

local RareKimonos = {
	"CaptainPinkKimono",
	"DemonGirlKimono",
	"LightningMasterKimono",
	"MoonKimono",
	"SunflowerKimono",
}

function PlayerService:CheckFirstJoin(Player: Player)
	local PlayerData = DataService:GetData(Player)

	local success, err = pcall(function()
		QuestService:CallQuestFunction(Player, "Cancel")
	end)

	if not success then
		warn(err)
	end
	local success, err = pcall(function()
		QuestService:RemoveQuest(Player)
	end)
	if not success then
		warn(err)
	end


	for _, Item in PlayerData.Inventory do
		if not ItemService:GetItemData(Item.Name) then
			InventoryService:RemoveItemFromPlayer(Player, Item.Name, Item.Stack)
		end
	end

	if not PlayerData.EyesColor then
		PlayerData.EyesColor = { math.random(0, 255), math.random(0, 255), math.random(0, 255) }
	end

	if not PlayerData.Race then
		RaceService:RollRandomRace(Player)
	end

	local HasKimono = false
	for _, Item in PlayerData.Inventory do
		if Item.Name:find("Kimono") then
			HasKimono = true
			break
		end
	end

	if not HasKimono then
		local Kimono
		if math.random(1, 1000) == 1 then
			Kimono = RareKimonos[math.random(1, #RareKimonos)]
		else
			Kimono = CommonKimonos[math.random(1, #CommonKimonos)]
		end

		InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem(Kimono, 1))
		PlayerData.Equipped.Torso = Kimono
	end

	if not InventoryService:GetPlayerItemByName(Player, "BasicKatana") then
		InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem("BasicKatana", 1))
		PlayerData.Equipped.Weapon = "BasicKatana"
	end

	if not InventoryService:GetPlayerItemByName(Player, "Fists") then
		InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem("Fists", 1))
	end

	PlayerData.LoadedFirstTime = true
end

function PlayerService:SaveData(Player: Player)
	pcall(function()
		PrisonService:HandlePlayerLeave(Player)
	end)
	DataService:SaveData(Player)
	pcall(function()
		PartyService:LeaveParty(Player)
	end)
	pcall(function()
		QuestService:AbandonQuest(Player)
	end)
	pcall(function()
		MissionBoardService:DestroyMission(Player)
	end)

	local FaceHead = workspace.FaceHeadFolder:FindFirstChild(Player.Name .. "FaceHead")
	if FaceHead then
		FaceHead:Destroy()
	end
end

function PlayerService.KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	ItemService = Knit.GetService("ItemService")
	InventoryService = Knit.GetService("InventoryService")
	GamepassService = Knit.GetService("GamepassService")
	QuestService = Knit.GetService("QuestService")
	SettingsService = Knit.GetService("SettingsService")
	PartyService = Knit.GetService("PartyService")
	RaceService = Knit.GetService("RaceService")
	PlaceService = Knit.GetService("PlaceService")
	SkillTreeService = Knit.GetService("SkillTreeService")
	MissionBoardService = Knit.GetService("MissionBoardService")
	PrisonService = Knit.GetService("PrisonService")
end

function PlayerService.KnitStart()
	game.Players.PlayerAdded:Connect(function(player)
		PlayerService:PlayerAdded(player)
	end)

	game.Players.PlayerRemoving:Connect(function(player)
		PlayerService:SaveData(player)
	end)

	for _, player in game.Players:GetPlayers() do
		PlayerService:PlayerAdded(player)
	end
end

return PlayerService
