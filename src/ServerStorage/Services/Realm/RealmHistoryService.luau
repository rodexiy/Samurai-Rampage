local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)

local RealmHistoryService = Knit.CreateService({ Name = "RealmHistoryService", Client = {} })
local LIMIT = 100

type History = { Realm: Model, Actions: { any }, Cursor: number }
local Histories: { [Player]: History } = {}

local function GetHistory(Player: Player, Realm: Model): History
	local History = Histories[Player]
	if not History or History.Realm ~= Realm then
		History = { Realm = Realm, Actions = {}, Cursor = 0 }
		Histories[Player] = History
		local Current = History
		Realm.Destroying:Once(function()
			if Histories[Player] == Current then
				Histories[Player] = nil
			end
		end)
	end

	return History
end

function RealmHistoryService:GetCounts(Player: Player, Realm: Model): (number, number)
	local History = GetHistory(Player, Realm)

	return History.Cursor, #History.Actions - History.Cursor
end

function RealmHistoryService:Record(Player: Player, Realm: Model, Action: any)
	local History = GetHistory(Player, Realm)
	for Index = #History.Actions, History.Cursor + 1, -1 do
		History.Actions[Index] = nil
	end
	table.insert(History.Actions, DeepCopy(Action))
	if #History.Actions > LIMIT then
		table.remove(History.Actions, 1)
	end
	History.Cursor = #History.Actions
end

function RealmHistoryService:Apply(Player: Player, Realm: Model, Direction: string,
	Execute: (any, boolean) -> (boolean, string?)): (boolean, string?)
	if Direction ~= "Undo" and Direction ~= "Redo" then
		return false, "Invalid history action."
	end

	local History = GetHistory(Player, Realm)
	local Undo = Direction == "Undo"
	local Index = if Undo then History.Cursor else History.Cursor + 1
	local Action = History.Actions[Index]
	if not Action then
		return false, if Undo then "Nothing to undo." else "Nothing to redo."
	end

	local Success, Reason = Execute(Action, Undo)
	if Success then
		History.Cursor += if Undo then -1 else 1
	end

	return Success, Reason
end

function RealmHistoryService.KnitStart()
	Players.PlayerRemoving:Connect(function(Player: Player)
		Histories[Player] = nil
	end)
end

return RealmHistoryService
