local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RugService = Knit.CreateService({
	Name = "RugService",
	Client = {
		UnlockedRug = Knit.CreateSignal(),
	},
})

local DataService
local AlertService
local RenderService
local LevelService

local MAX_RUG_DISTANCE = 10
local SPAWN_HEIGHT = 3

local function GetRugCFrame(Rug: Instance)
	local RugPart = Rug:FindFirstChild("Rug")
	if RugPart and RugPart:IsA("BasePart") then
		return RugPart.CFrame
	end

	if Rug:IsA("Model") or Rug:IsA("BasePart") then
		return Rug:GetPivot()
	end

	return nil
end

local function GetClosestRug(Character: Model)
	local Rugs = workspace:FindFirstChild("Rugs")
	if not Rugs then
		return nil
	end

	local ClosestRug
	local ClosestDistance = MAX_RUG_DISTANCE

	for _, Rug in Rugs:GetChildren() do
		local RugCFrame = GetRugCFrame(Rug)
		if not RugCFrame then
			continue
		end

		local Distance = (RugCFrame.Position - Character:GetPivot().Position).Magnitude
		if Distance < ClosestDistance then
			ClosestRug = Rug
			ClosestDistance = Distance
		end
	end

	return ClosestRug
end

function RugService:SetSpawnRug(Player: Player, Rug: Instance)
	local Rugs = workspace:FindFirstChild("Rugs")
	if not Rugs or Rug.Parent ~= Rugs or Rug:GetAttribute("NotSetSpawn") ~= nil then
		return
	end

	local PlayerData = DataService:GetData(Player)
	if not PlayerData or PlayerData.SpawnRug == Rug.Name then
		return
	end

	PlayerData.SpawnRug = Rug.Name
	AlertService:AlertPlayer(Player, "Spawnpoint set to " .. Rug.Name .. ".", "Success")
end

function RugService:SetSpawnRugByName(Player: Player, RugName: string)
	local PlayerData = DataService:GetData(Player)
	local Rugs = workspace:FindFirstChild("Rugs")
	if
		typeof(RugName) ~= "string"
		or not PlayerData
		or not Rugs
		or not table.find(PlayerData.UnlockedRugs, RugName)
	then
		return
	end

	local Rug = Rugs:FindFirstChild(RugName)
	if Rug then
		self:SetSpawnRug(Player, Rug)
	end
end

function RugService.Client:SetSpawnRug(Player: Player, RugName: string)
	self.Server:SetSpawnRugByName(Player, RugName)
end

function RugService:GetSpawnCFrame(Player: Player)
	local PlayerData = DataService:GetData(Player)
	local Rugs = workspace:FindFirstChild("Rugs")
	local SpawnRug = PlayerData and PlayerData.SpawnRug
	if not Rugs or typeof(SpawnRug) ~= "string" or SpawnRug == "" then
		return nil
	end

	local Rug = Rugs:FindFirstChild(SpawnRug)
	if not Rug or Rug:GetAttribute("NotSetSpawn") ~= nil then
		return nil
	end

	local RugCFrame = GetRugCFrame(Rug)
	return if RugCFrame then RugCFrame * CFrame.new(0, SPAWN_HEIGHT, 0) else nil
end

function RugService:UnlockRug(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	local Rug = GetClosestRug(Character)
	if not Rug then
		return
	end

	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	if not table.find(PlayerData.UnlockedRugs, Rug.Name) then
		table.insert(PlayerData.UnlockedRugs, Rug.Name)
		RenderService:RenderForAllPlayers("Misc", "MeditateNewRug", { Character = Character })
		AlertService:AlertPlayer(Player, "Unlocked " .. Rug.Name .. "!", "Success")
		LevelService:GiveExp(Player, 100)
		RugService.Client.UnlockedRug:Fire(Player, PlayerData.UnlockedRugs)
	end

	self:SetSpawnRug(Player, Rug)
end

function RugService.Client:UnlockRug(Player: Player)
	self.Server:UnlockRug(Player)
end

function RugService:GetUnlockedRugs(Player: Player)
	local PlayerData = DataService:GetData(Player)
	return PlayerData.UnlockedRugs
end

function RugService.Client:GetUnlockedRugs(Player: Player)
	return self.Server:GetUnlockedRugs(Player)
end

function RugService.KnitInit()
	DataService = Knit.GetService("DataService")
	AlertService = Knit.GetService("AlertService")
	RenderService = Knit.GetService("RenderService")
	LevelService = Knit.GetService("LevelService")
end

function RugService.KnitStart() end

return RugService
