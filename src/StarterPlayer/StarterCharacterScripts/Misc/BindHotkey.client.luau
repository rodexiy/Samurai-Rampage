local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local MenuController = Knit.GetController("MenuController")

MenuController:SetHudDefaultEnabled()
