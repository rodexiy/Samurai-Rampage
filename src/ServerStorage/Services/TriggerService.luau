local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TriggerService = Knit.CreateService({
	Name = "TriggerService",
	Client = {
		CompletedTriggers = Knit.CreateSignal(),
	},
})

local DataService

local function CopyTriggers(Triggers)
	local Copy = {}
	if typeof(Triggers) ~= "table" then
		return Copy
	end

	for _, TriggerName in Triggers do
		if typeof(TriggerName) == "string" then
			table.insert(Copy, TriggerName)
		end
	end

	return Copy
end

local function IsValidTriggerName(TriggerName: string): boolean
	for _, Parent in { ReplicatedStorage, workspace } do
		local TriggerFolder = Parent:FindFirstChild("Triggers")
		if not TriggerFolder then
			continue
		end

		if TriggerFolder:FindFirstChild(TriggerName) then
			return true
		end

		for _, Trigger in TriggerFolder:GetChildren() do
			if Trigger:GetAttribute("TriggerName") == TriggerName then
				return true
			end
		end
	end

	return false
end

function TriggerService:GetCompletedTriggers(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return {}
	end

	PlayerData.CompletedTriggers = PlayerData.CompletedTriggers or {}
	return CopyTriggers(PlayerData.CompletedTriggers)
end

function TriggerService:CompleteTrigger(Player: Player, TriggerName: string)
	if typeof(TriggerName) ~= "string" or TriggerName == "" or not IsValidTriggerName(TriggerName) then
		return false
	end

	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return false
	end

	PlayerData.CompletedTriggers = PlayerData.CompletedTriggers or {}
	if not table.find(PlayerData.CompletedTriggers, TriggerName) then
		table.insert(PlayerData.CompletedTriggers, TriggerName)
	end

	TriggerService.Client.CompletedTriggers:Fire(Player, CopyTriggers(PlayerData.CompletedTriggers))
	return true
end

function TriggerService:SendCompletedTriggers(Player: Player)
	TriggerService.Client.CompletedTriggers:Fire(Player, self:GetCompletedTriggers(Player))
end

function TriggerService.Client:GetCompletedTriggers(Player: Player)
	return self.Server:GetCompletedTriggers(Player)
end

function TriggerService.Client:CompleteTrigger(Player: Player, TriggerName: string)
	return self.Server:CompleteTrigger(Player, TriggerName)
end

function TriggerService.KnitInit()
	DataService = Knit.GetService("DataService")
end

function TriggerService.KnitStart() end

return TriggerService
