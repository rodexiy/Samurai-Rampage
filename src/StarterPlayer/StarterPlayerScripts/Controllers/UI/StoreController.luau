local PolicyService = game:GetService("PolicyService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local StoreController = Knit.CreateController({
	Name = "StoreController",
})

local GamepassService

local Player = game.Players.LocalPlayer
local PlayerGui
local Menu
local Store
local Background
local Content

local EasyVisuals = require(game.ReplicatedStorage.Assets.Libraries.EasyVisuals)

local Visuals = {}

local Products = {
	{
		name = "Trading Sign",
		displayName = "Trading Sign",
		price = 125,
		description = "A sign that can be written on.",
		icon = "0",
	},

	{
		name = "ResetSkillTree",
		displayName = "Reset Skill Tree",
		price = 49,
		description = "Used to reset your skill tree.",
		icon = "0",
	},

	{
		name = "RaceReroll",
		displayName = "Race Reroll",
		price = 100,
		description = "Reroll your race.",
		icon = "0",
		PaidRandomItem = true,
	},

	{
		name = "ArtifactRemover",
		displayName = "Artifact Remover",
		price = 49,
		description = "Remove your current artifact.",
		icon = "0",
	},
}

function StoreController:Load()
	local Passes = GamepassService:GetAllGamepass()
	for _, Product in Products do
		table.insert(Passes, Product)
	end
	local Policy = PolicyService:GetPolicyInfoForPlayerAsync(Player)
	for _, Gamepass in Passes do
		local Template = Background.Template:Clone()

		if Gamepass.PaidRandomItem and Policy.ArePaidRandomItemsRestricted then
			continue
		end

		Template.Name = Gamepass.name
		Template:WaitForChild("Title").Text = Gamepass.displayName
		Template:WaitForChild("Price").Text = Gamepass.price
		Template:WaitForChild("Description").Text = Gamepass.description

		Template:WaitForChild("Icon").Image = "rbxassetid://" .. Gamepass.icon
		Template:WaitForChild("Icon").BackgroundTransparency = 1
		Template.Active = true
		Template.Activated:Connect(function()
			GamepassService:BuyGamepass(Gamepass.name)
		end)
		Template.Parent = Content
		Template.Visible = true
	end
end

function StoreController:LoadVisuals()
	table.insert(Visuals, EasyVisuals.new(Background.Title, "GoldStroke", 0.35, 1))
	table.insert(Visuals, EasyVisuals.new(Background, "GoldStroke", 0.35, 2))
	for _, Gamepass in Content:GetChildren() do
		if Gamepass:IsA("ImageButton") then
			table.insert(Visuals, EasyVisuals.new(Gamepass, "GhostStroke", 1, 1))
		end
	end
end

function StoreController:UnloadVisuals()
	for _, Visual in Visuals do
		Visual:Destroy()
		Visuals[_] = nil
	end
end

function StoreController.KnitInit()
	GamepassService = Knit.GetService("GamepassService")
end

function StoreController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Menu = PlayerGui:WaitForChild("Menu")
	Store = Menu:WaitForChild("Store")
	Background = Store:WaitForChild("background")
	Content = Background:WaitForChild("content")

	Store:GetPropertyChangedSignal("Enabled"):Connect(function()
		if Store.Enabled then
			StoreController:LoadVisuals()
		else
			StoreController:UnloadVisuals()
		end
	end)

	StoreController:Load()
end

return StoreController
