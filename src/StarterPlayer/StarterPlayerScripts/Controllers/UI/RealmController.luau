local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RealmController = Knit.CreateController({
	Name = "RealmController",
})

local AlertController
local RealmService

local Player = game.Players.LocalPlayer
local PlayerGui
local Menu
local Meditate
local FastTravelBackground
local MentalRealmButton

local TeleportCharacter = require(game.ReplicatedStorage.Shared.Utils.TeleportCharacter)
local TileTransition =
	require(game.ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Libraries"):WaitForChild("TileTransition"))

local Debounce = false

local Info = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local Camera = workspace.CurrentCamera

function RealmController:Travel()	

	if Player:GetAttribute("InCombat") then
		AlertController:Alert("Can't teleport while in combat", "Error")
		return
	end

	if Debounce then
		return
	end

	Debounce = true

	TweenService:Create(Camera, Info, { FieldOfView = 1 }):Play()

	local Character = Player.Character
	if Character then
		Character:SetAttribute("RealmTeleporting", true)
	end

	task.wait(0.5)
	RealmService:Teleport()
	task.wait(0.5)
	TweenService:Create(Camera, Info, { FieldOfView = 75 }):Play()

	if Character then
		Character:SetAttribute("RealmTeleporting", false)
	end

	task.wait(5)
	Debounce = false
end

function RealmController:GetRealm(Player: Player)
	Player = Player or Players.LocalPlayer
	for _, Realm in workspace.Realms:GetChildren() do
		if Realm:GetAttribute("OwnerId") == Player.UserId then
			return Realm
		end
	end
end

function RealmController.KnitInit()
	RealmService = Knit.GetService("RealmService")
	AlertController = Knit.GetController("AlertController")
end

function RealmController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Menu = PlayerGui:WaitForChild("Menu")
	Meditate = Menu:WaitForChild("Meditate")
	FastTravelBackground = Meditate:WaitForChild("FastTravelBackground"):WaitForChild("background")
	MentalRealmButton = FastTravelBackground:WaitForChild("MentalRealm")

	MentalRealmButton.Activated:Connect(function()
		if RunService:IsStudio() then
			RealmController:Travel()
		end
	end)
end

return RealmController
