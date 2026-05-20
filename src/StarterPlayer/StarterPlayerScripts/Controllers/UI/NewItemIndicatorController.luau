local Debris = game:GetService("Debris")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local NewItemIndicatorController = Knit.CreateController({
	Name = "NewItemIndicatorController",
})

local InventoryService
local SoundEffectController

local Player = game.Players.LocalPlayer
local PlayerGui
local Hud
local NewItemIndicator
local content
local Template

local EasyVisuals = require(game.ReplicatedStorage.Assets.Libraries.EasyVisuals)

local Items = require(game.ReplicatedStorage.Shared.Index.Items)

function NewItemIndicatorController:NewItem(ItemName: string, Amount: number)
	local ItemData = Items[ItemName]
	local Rarity = "Common"
	if ItemData and ItemData.Rarity then
		Rarity = ItemData.Rarity
	end

	local NewItem = Template:Clone()
	NewItem.Text = ItemData.DisplayName .. " x" .. Amount
	Debris:AddItem(NewItem, 3)
	NewItem.Visible = true
	NewItem.Parent = content

	local Visual = EasyVisuals.new(NewItem, Rarity, 1, 0.25)

	task.delay(3, function()
		Visual:Destroy()
	end)

	SoundEffectController:PlaySoundEffect("ItemAdded", true)
end

function NewItemIndicatorController:KnitInit()
	InventoryService = Knit.GetService("InventoryService")
	SoundEffectController = Knit.GetController("SoundEffectController")
end

function NewItemIndicatorController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Hud = PlayerGui:WaitForChild("Hud")
	NewItemIndicator = Hud:WaitForChild("NewItemIndicator")
	content = NewItemIndicator:WaitForChild("content")
	Template = NewItemIndicator:WaitForChild("Template")

	InventoryService.ItemAdded:Connect(function(ItemName, Amount)
		NewItemIndicatorController:NewItem(ItemName, Amount)
	end)
end

return NewItemIndicatorController
