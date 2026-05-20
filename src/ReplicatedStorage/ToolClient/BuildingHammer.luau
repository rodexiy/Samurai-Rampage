local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildingHammer = {}

local Player = game.Players.LocalPlayer

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local RealmController = Knit.GetController("RealmController")
local GridPlacement = require(ReplicatedStorage.Shared.GridPlacement)

function BuildingHammer.Activated(Character: Model, Tool: Tool)
	local PlayerGui = Player.PlayerGui
	local Temporary = PlayerGui:WaitForChild("Temporary")
end

function BuildingHammer.Equipped(Character: Model, Tool: Tool)
	local PlayerGui = Player.PlayerGui
	local Temporary = PlayerGui:WaitForChild("Temporary")

	local Realm = RealmController:GetRealm()
	if Realm then
		GridPlacement:ToggleBuildingAreas(Realm, { "Wall", "Floor", "Ceiling" }, true)
	end
end

function BuildingHammer.Unequipped(Character: Model, Tool: Tool)
	local PlayerGui = Player.PlayerGui
	local Temporary = PlayerGui:WaitForChild("Temporary")

	local Realm = RealmController:GetRealm()
	if Realm then
		GridPlacement:ToggleBuildingAreas(Realm, { "Wall", "Floor", "Ceiling" }, false)
	end
end

return BuildingHammer
