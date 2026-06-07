local RunService = game:GetService("RunService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local FastTravelController = Knit.CreateController({
	Name = "FastTravelController",
})

local RugService
local AlertController

local Player = game.Players.LocalPlayer
local PlayerGui
local Menu
local Meditate
local FastTravelBackground

local TeleportCharacter = require(game.ReplicatedStorage.Shared.Utils.TeleportCharacter)
local TileTransition =
	require(game.ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Libraries"):WaitForChild("TileTransition"))

local Debounce = false

local EasyVisuals = require(game.ReplicatedStorage.Assets.Libraries.EasyVisuals)
local CurrentVisual

local function UpdateClosest()
	local Character = Player.Character
	if not Character then
		return
	end
	for _, Button in FastTravelBackground.content:GetChildren() do
		local Rug = workspace.Rugs:FindFirstChild(Button.Name)
		if not Rug then
			continue
		end

		if (Character:GetPivot().Position - Rug:GetPivot().Position).Magnitude < 10 then
			if CurrentVisual then
				CurrentVisual:Destroy()
			end
			CurrentVisual = EasyVisuals.new(Button, "GoldStroke", 1, 1)
		end
	end
end

function FastTravelController:LoadLocations(Locations: { any })
	if not workspace:FindFirstChild("Rugs") then
		FastTravelBackground.Visible = false
		return
	end

	local Locations = Locations or RugService:GetUnlockedRugs(Player)

	for _, Button in FastTravelBackground.content:GetChildren() do
		if Button:IsA("TextButton") then
			Button:Destroy()
		end
	end

	for _, Location in Locations do
		local Rug = workspace.Rugs:FindFirstChild(Location)
		if not Rug then
			continue
		end

		local Template = FastTravelBackground.Template:Clone()
		Template.Name = Location
		Template.Text = Location
		Template.Visible = true
		Template.Activated:Connect(function()
			local Character = Player.Character
			if Character then
				if (Character:GetPivot().Position - Rug:GetPivot().Position).Magnitude < 10 then
					AlertController:Alert("Can't teleport to the same location", "Error")
					return
				end
			end

			if Player:GetAttribute("InCombat") then
				AlertController:Alert("Can't teleport while in combat", "Error")
				return
			end

			if Debounce then
				AlertController:Alert("Wait to teleport again", "Error")
				return
			end

			Debounce = true

			task.delay(5, function()
				Debounce = false
			end)

			TileTransition.In()

			TeleportCharacter(Character, Rug:GetPivot() * CFrame.new(math.random(-3, 3), 2.5, math.random(-3, 3)))
			RugService:SetSpawnRug(Location)
			UpdateClosest()

			TileTransition.Out()
		end)

		Template.Parent = FastTravelBackground.content
	end
end

function FastTravelController.KnitInit()
	RugService = Knit.GetService("RugService")
	AlertController = Knit.GetController("AlertController")
end

function FastTravelController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Menu = PlayerGui:WaitForChild("Menu")
	Meditate = Menu:WaitForChild("Meditate")
	FastTravelBackground = Meditate:WaitForChild("FastTravelBackground"):WaitForChild("background")

	if not workspace:FindFirstChild("Rugs") then
		FastTravelBackground.Visible = false
		return
	end

	Meditate:GetPropertyChangedSignal("Enabled"):Connect(function()
		if Meditate.Enabled then
			UpdateClosest()
		else
			if CurrentVisual then
				CurrentVisual:Destroy()
			end
		end
	end)
	RugService.UnlockedRug:Connect(function(Locations)
		FastTravelController:LoadLocations(Locations)
	end)

	workspace.Rugs.ChildAdded:Connect(function(Rug)
		FastTravelController:LoadLocations()
	end)
end

return FastTravelController
