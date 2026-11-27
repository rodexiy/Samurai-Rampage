local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local TopBarController = Knit.CreateController({
	Name = "TopBarController",
})

local PlaceController
local AlertController
local RealmEditorController
local DeviceController
local MobileControlsController

local TopbarPlus
local RealmEditorIcon
local SavedIconStates: { [any]: boolean } = {}

local Player = game.Players.LocalPlayer

local function HideOtherIcon(Icon: any)
	if Icon == RealmEditorIcon then
		return
	end
	if SavedIconStates[Icon] == nil then
		SavedIconStates[Icon] = Icon.isEnabled
	end
	Icon:setEnabled(false)
end

local function SetRealmEditorFocus(Active: boolean)
	if Active then
		for _, Icon in TopbarPlus.getIcons() do
			HideOtherIcon(Icon)
		end
	else
		for Icon, Enabled in SavedIconStates do
			if Icon.widget.Parent then
				Icon:setEnabled(Enabled)
			end
		end
		table.clear(SavedIconStates)
	end
end

function TopBarController:GetRealmEditorGui(): ScreenGui?
	if not RealmEditorIcon then
		return nil
	end

	return RealmEditorIcon.widget:FindFirstAncestorWhichIsA("ScreenGui") :: ScreenGui?
end

function TopBarController:BindMobileControls()
	local Edit = TopbarPlus.new():setName("EditMobileControls"):setLabel("Edit controls"):setOrder(10)
	local Reset = TopbarPlus.new():setName("ResetMobileControls"):setLabel("Reset controls"):setOrder(11):oneClick()
	local function UpdateAvailability()
		local Available = DeviceController:IsMobile() and not RealmEditorController:IsOpen()
		Edit:setEnabled(Available)
		Reset:setEnabled(Available)
	end
	UpdateAvailability()
	DeviceController.DeviceChanged:Connect(UpdateAvailability)
	RealmEditorController.Changed:Connect(UpdateAvailability)

	Edit.selected:Connect(function()
		if not MobileControlsController:SetEditing(true) then
			Edit:deselect()
		end
	end)
	Edit.deselected:Connect(function()
		MobileControlsController:SetEditing(false)
	end)
	MobileControlsController.Changed:Connect(function(Editing: boolean)
		Edit:setLabel(if Editing then "Done" else "Edit controls")
		if Editing then
			Edit:select()
		else
			Edit:deselect()
		end
	end)
	Reset.selected:Connect(function()
		MobileControlsController:RequestReset()
	end)
end

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
local function isPlayerAdmin(player: Player)
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

	local RealmEditor = TopbarPlus.new():setName("RealmEditor"):setLabel("Edit Realm"):setImage(11656483170)
	RealmEditorIcon = RealmEditor
	RealmEditor:setEnabled(RealmEditorController:IsOpen() or RealmEditorController:CanOpen())
	RealmEditor.selected:Connect(function()
		if not RealmEditorController:Open() then
			RealmEditor:deselect()
		end
	end)
	RealmEditor.deselected:Connect(function()
		RealmEditorController:Close()
	end)
	RealmEditorController.AvailabilityChanged:Connect(function(Enabled: boolean)
		RealmEditor:setEnabled(Enabled or RealmEditorController:IsOpen())
	end)
	RealmEditorController.Changed:Connect(function(Opened: boolean)
		SetRealmEditorFocus(Opened)
		if Opened then
			RealmEditor:setLabel("Exit editor")
			RealmEditor:select()
		else
			RealmEditor:setLabel("Edit Realm")
			RealmEditor:deselect()
		end
	end)

	self:LoadHub()
	self:BindMobileControls()

	if isPlayerAdmin(game.Players.LocalPlayer) then
		Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
	end

	if isPlayerAdmin(game.Players.LocalPlayer) then
		local Cmd = TopbarPlus.new():setImage(11656483170):oneClick()
		Cmd.selected:Connect(function()
			Cmdr:Toggle()
		end)


	end
end

function TopBarController.KnitInit()
	AlertController = Knit.GetController("AlertController")
	PlaceController = Knit.GetController("PlaceController")
	RealmEditorController = Knit.GetController("RealmEditorController")
	DeviceController = Knit.GetController("DeviceController")
	MobileControlsController = Knit.GetController("MobileControlsController")
end

function TopBarController.KnitStart()
	TopbarPlus = require(ReplicatedStorage.Assets.Libraries.TopbarPlus)
	TopbarPlus.highlightKey = false
	TopbarPlus.iconAdded:Connect(function(Icon: any)
		if RealmEditorController:IsOpen() then
			HideOtherIcon(Icon)
		end
	end)

	if isPlayerAdmin(game.Players.LocalPlayer) or RunService:IsStudio() then
		Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
	end

	repeat
		task.wait()
	until not workspace:GetAttribute("InMainMenu")
	TopBarController:BindTopbar()
end

return TopBarController
