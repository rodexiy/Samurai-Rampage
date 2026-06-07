local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TopBarController = Knit.CreateController({
	Name = "TopBarController",
})

local MenuController
local DeviceController
local PlaceController
local AlertController

local TopbarPlus
local EasyVisuals = require(game.ReplicatedStorage.Assets.Libraries.EasyVisuals)

local Player = game.Players.LocalPlayer

function TopBarController:LoadHub()
	if PlaceController:IsArena() then
		return
	end

	local Icons = {}

	if PlaceController:IsSHURA() then
		local Trading = TopbarPlus.new():oneClick(true):setLabel("Trading"):setImage(9695309046)

		table.insert(Icons, Trading)
		Trading.selected:Connect(function()
			if Player:GetAttribute("InCombat") then
				AlertController:Alert("Can't teleport while in combat", "Error")
				return
			end

			if RunService:IsStudio() then
				AlertController:Alert("Can't teleport in Studio", "Error")
				return
			end

			local success, err = pcall(function()
				TeleportService:Teleport(PlaceController:GetPlaceId("Trading"), Player)
			end)

			if success then
				AlertController:Alert("Teleporting...", "Success")
			else
				AlertController:Alert(err, "Error")
			end
		end)
	elseif PlaceController:IsTrading() then
		local Shura = TopbarPlus.new():oneClick(true):setLabel("SHURA"):setImage(101359319417413)
		table.insert(Icons, Shura)

		Shura.selected:Connect(function()
			if RunService:IsStudio() then
				AlertController:Alert("Can't teleport in Studio", "Error")
				return
			end

			local success, err = pcall(function()
				TeleportService:Teleport(PlaceController:GetPlaceId("SHURA"), Player)
			end)

			if success then
				AlertController:Alert("Teleporting...", "Success")
			else
				AlertController:Alert(err, "Error")
			end
		end)
	end

	local mHub = TopbarPlus.new():setLabel("Hub"):oneClick(true):setImage(7485051715)
	table.insert(Icons, mHub)

	local PrivateServer = TopbarPlus.new():oneClick(true):setLabel("Private Server"):setImage(14193653203)
	table.insert(Icons, PrivateServer)

	PrivateServer.selected:Connect(function()
		Player.PlayerGui.Temporary.PrivateServer.Enabled = not Player.PlayerGui.Temporary.PrivateServer.Enabled
	end)

	mHub.selected:Connect(function()
		if RunService:IsStudio() then
			AlertController:Alert("Can't teleport in Studio", "Error")
			return
		end

		local success, err = pcall(function()
			TeleportService:Teleport(PlaceController:GetPlaceId("Hub"), Player)
		end)

		if success then
			AlertController:Alert("Teleporting...", "Success")
		else
			AlertController:Alert(err, "Error")
		end
	end)

	TopbarPlus.new():setImage(18777407436):setDropdown(Icons)
end

local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))

local GroupId = 32878451
local RunService = game:GetService("RunService")
local function isPlayerAdmin(player: Player)
	local response = false
	local succ, rank = pcall(player.GetRankInGroup, player, GroupId or 0)

	if not succ then
		task.wait(0.5)
		return isPlayerAdmin(player)
	end

	if rank < 250 then
		return false
	end
	return true
end

function TopBarController:BindTopbar()
	if not RunService:IsStudio() then
		local Location =
			TopbarPlus.new():setLabel(game.Workspace:GetAttribute("ServerLocation")):setImage(101359319417413):lock()

		workspace:GetAttributeChangedSignal("ServerLocation"):Connect(function()
			Location:setLabel(game.Workspace:GetAttribute("ServerLocation"))
		end)
	end

	local Time = TopbarPlus.new():setLabel("00:00:00"):lock()

	Lighting:GetPropertyChangedSignal("TimeOfDay"):Connect(function()
		Time:setLabel(Lighting.TimeOfDay:sub(1, 5))
	end)

	local Settings = TopbarPlus.new():setImage(108728167119436):oneClick()

	Settings.selected:Connect(function()
		MenuController:OpenMenu("Settings")
	end)

	-- local Journal = TopbarPlus.new():setLabel("Journal"):oneClick()
	-- Journal.selected:Connect(function()
	-- 	MenuController:OpenMenu("Journal")
	-- end)

	local Crafting = TopbarPlus.new():setImage(127637152352990):oneClick()
	Crafting.selected:Connect(function()
		MenuController:OpenMenu("Crafting")
	end)

	self:LoadHub()

	if not PlaceController:IsArena() then
		local Store = TopbarPlus.new():setImage(18100081635):oneClick()
		Store.selected:Connect(function()
			MenuController:OpenMenu("Store")
		end)

		local StoreIconImage = Store.widget:FindFirstChild("IconImage", true)

		if StoreIconImage then
			EasyVisuals.new(StoreIconImage, "Gold", 0.35, 0.75, true)
		end
	end

	if isPlayerAdmin(game.Players.LocalPlayer) then
		Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
	end

	if isPlayerAdmin(game.Players.LocalPlayer) then
		local Cmd = TopbarPlus.new():setImage(11656483170):oneClick()
		Cmd.selected:Connect(function()
			Cmdr:Toggle()
		end)

		local CmdIconImage = Cmd.widget:FindFirstChild("IconImage", true)
		if CmdIconImage then
			EasyVisuals.new(CmdIconImage, "Death", 0.35, 0.75, true)
		end
	end
end

function TopBarController.KnitInit()
	MenuController = Knit.GetController("MenuController")
	DeviceController = Knit.GetController("DeviceController")
	AlertController = Knit.GetController("AlertController")
	PlaceController = Knit.GetController("PlaceController")
end

function TopBarController.KnitStart()
	TopbarPlus = require(game.ReplicatedStorage.Assets.Libraries.TopbarPlus)

	if isPlayerAdmin(game.Players.LocalPlayer) or RunService:IsStudio() then
		Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
	end

	repeat
		task.wait()
	until not workspace:GetAttribute("InMainMenu")
	TopBarController:BindTopbar()
end

return TopBarController
