local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local PrisonService = Knit.CreateService({
	Name = "PrisonService",
	Client = {},
})

local DataService
local SharedConstants = require(game.ReplicatedStorage.Shared.Constants)
local TeleportCharacter = require(game.ReplicatedStorage.Shared.Utils.TeleportCharacter)
local QuestService
local ObjectiveService
local WeaponService
local InCombatService
local InventoryService
local AlertService
local TetsuService
local RenderService
local PlaceService
local PRISON_BOUNTY = SharedConstants.PRISON_BOUNTY

local Cells

local function GetAvailableCell()
	local FreeCells = {}
	for _, Cell in ipairs(Cells) do
		if not Cell:GetAttribute("Occupied") then
			table.insert(FreeCells, Cell)
		end
	end
	if #FreeCells > 0 then
		return FreeCells[math.random(1, #FreeCells)]
	else
		return Cells[math.random(1, #Cells)]
	end
end

function PrisonService:SendToCell(Character: Model, Duration: number)
	local Player = Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end

	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	local Cell = GetAvailableCell()
	if not Cell then
		return
	end

	Cell:SetAttribute("Occupied", true)
	Character:SetAttribute("InCell", true)
	WeaponService:Equip(Character, false)

	TeleportCharacter(Character, Cell:GetPivot())

	PlayerData.PrisonTime = Duration

	repeat
		task.wait()
	until Player:GetAttribute("KnitClientLoaded") or not Player or not Player.Parent

	RenderService:RenderForPlayer(Player, "Misc", "Countdown", { Character = Character, InitialValue = Duration })

	while PlayerData.Prison.PrisonTime > 0 do
		task.wait(1)
		PlayerData.Prison.PrisonTime -= 1
		if not Player.Parent then
			Cell:SetAttribute("Occupied", false)
			return
		end
	end

	PlayerData.Prison.PrisonTime = 0
	Cell:SetAttribute("Occupied", false)
	Character:SetAttribute("InCell", nil)

	local Forward = Cell:GetPivot().LookVector
	local OutsideCFrame = Cell:GetPivot() + (Forward * 15)
	if Character then
		TeleportCharacter(Character, OutsideCFrame)
	end
end

function PrisonService:SendToLabor(Character: Model)
	local Player = Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end
	QuestService:AbandonQuest(Player)

	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end
	local Success = QuestService:GiveQuest(Player, "PrisonLabor", PlayerData.Prison.Labor.AmountToCollect)
	if not Success then
		return
	end

	PlayerData.Prison.PrisonTime = 0

	Character:PivotTo(workspace.Map.Prison.Labor.CFrame)
end

function PrisonService:AwardArrest(Player: Player, PlayerToJail: Player)
	local PlayerData = DataService:GetData(Player)
	PlayerData.Reputation += 1
	AlertService:AlertPlayer(Player, "REPUTATION: " .. PlayerData.Reputation, "Default")

	local PlayerToJailData = DataService:GetData(PlayerToJail)
	local Bounty = PlayerToJailData.Bounty
	PlayerToJailData.Bounty = 0

	TetsuService:AddTetsu(Player, Bounty)
	AlertService:AlertPlayer(
		Player,
		"You received " .. Bounty .. " Tetsu for arresting " .. PlayerToJail.Name,
		"Default"
	)
end

function PrisonService:PunishArrest(PlayerToJail: Player)
	local PlayerToJailData = DataService:GetData(PlayerToJail)
	PlayerToJailData.Bounty = 0
	PlayerToJailData.Prison.Labor.AmountToCollect = 10
end

function PrisonService:Arrested(CharacterWhoSent: Model, CharacterToJail: Model, LeavingGame: boolean)
	if (CharacterWhoSent:GetPivot().Position - CharacterToJail:GetPivot().Position).Magnitude > 10 then
		return
	end
	local PlayerToJail = Players:GetPlayerFromCharacter(CharacterToJail)
	if not PlayerToJail then
		return
	end
	if
		PlayerToJail:GetAttribute("Bounty") >= PRISON_BOUNTY
		and CharacterToJail:GetAttribute("Downed")
		and not CharacterToJail:GetAttribute("Died")
	then
		local Player = Players:GetPlayerFromCharacter(CharacterWhoSent)
		if PlayerToJail and Player then
			PrisonService:AwardArrest(Player, PlayerToJail)
		end

		PrisonService:PunishArrest(PlayerToJail)
		PrisonService:SendToLabor(CharacterToJail)
	end
end

function PrisonService.Client:Arrested(Player: Player, CharacterToJail: Model)
	if not PlaceService:IsSHURA() then
		return
	end
	
	if not Player.Character or not CharacterToJail then
		return
	end
	self.Server:Arrested(Player.Character, CharacterToJail)
end

function PrisonService:CheckJoin(Player: Player)
	if not PlaceService:IsSHURA() then
		return
	end

	local PlayerData = DataService:GetData(Player)

	if not Player or not Player.Parent then
		return
	end
	if PlayerData.Prison.PrisonTime > 0 then
		self:SendToCell(Player.Character, PlayerData.Prison.PrisonTime)
	end

	if PlayerData.Prison.PrisonTime == 0 and PlayerData.Prison.Labor.AmountToCollect > 0 then
		self:SendToLabor(Player.Character)
	end
end

function PrisonService:HandlePlayerLeave(Player: Player)
	if not PlaceService:IsSHURA() then
		return
	end

	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	-- Studio mode: reset instantly
	if RunService:IsStudio() then
		--PlayerData.Prison.PrisonTime = 0
		PlayerData.Prison.Labor.AmountToCollect = 0
		PlayerData.Prison.Labor.Collected = 0
		return
	end

	-- Ignore low-bounty players
	if PlayerData.Bounty < PRISON_BOUNTY then
		return
	end

	-- Handle pending labor progress
	if PlayerData.Prison.Labor.AmountToCollect > 0 then
		PlayerData.Prison.Labor.AmountToCollect -= PlayerData.Prison.Labor.Collected
		PlayerData.Prison.Labor.Collected = 0
		return
	end

	-- Handle combat logout arrests
	local isEligibleForArrest = Player:GetAttribute("InCombat")
		and PlayerData.Prison.PrisonTime == 0
		and PlayerData.Prison.Labor.AmountToCollect == 0

	if not isEligibleForArrest then
		return
	end

	local CombatOpponents = InCombatService:GetInCombatWith(Player.Character)
	if not CombatOpponents then
		return
	end

	local LeftInCombatWithPlayer = false
	for _, OpponentCharacter in CombatOpponents do
		-- Skip AI
		if OpponentCharacter:GetAttribute("IsAI") then
			continue
		end

		local OpponentPlayer = Players:GetPlayerFromCharacter(OpponentCharacter)
		if not OpponentPlayer then
			continue
		end

		-- Check if opponent has handcuffs in hotbar
		local HasHandcuffs = InventoryService:GetItemHotbarIndex(OpponentPlayer, "Handcuffs")
		if not HasHandcuffs then
			LeftInCombatWithPlayer = true
			continue
		end

		-- Arrest logic
		PrisonService:AwardArrest(OpponentPlayer, Player)
		PrisonService:PunishArrest(Player)
		LeftInCombatWithPlayer = false
		break
	end

	if LeftInCombatWithPlayer then
		PlayerData.Prison.PrisonTime = 30
	end
end

function PrisonService.KnitInit()
	PlaceService = Knit.GetService("PlaceService")
	DataService = Knit.GetService("DataService")
	QuestService = Knit.GetService("QuestService")
	ObjectiveService = Knit.GetService("ObjectiveService")
	WeaponService = Knit.GetService("WeaponService")
	InCombatService = Knit.GetService("InCombatService")
	InventoryService = Knit.GetService("InventoryService")
	AlertService = Knit.GetService("AlertService")
	TetsuService = Knit.GetService("TetsuService")
	RenderService = Knit.GetService("RenderService")
	
	 if workspace:FindFirstChild("Map") then
		if workspace.Map:FindFirstChild("Prison") then
			if workspace.Map.Prison:FindFirstChild("Cells") then
				Cells = workspace.Map.Prison.Cells:GetChildren() 
			end
		end
	 end
end

return PrisonService
