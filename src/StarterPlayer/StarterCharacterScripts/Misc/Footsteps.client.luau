local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Character = script.Parent.Parent.Parent :: Model

-- A single controller handles local and nearby players without duplicate step listeners.
Knit.OnStart():andThen(function()
	if Players.LocalPlayer.Character == Character then
		Knit.GetController("FootstepsController"):TrackCharacter(Character)
	end
end)
