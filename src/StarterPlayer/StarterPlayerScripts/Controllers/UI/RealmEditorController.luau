local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RealmEditorController = Knit.CreateController({ Name = "RealmEditorController" })
local Player = Players.LocalPlayer
local Changed = Instance.new("BindableEvent")
local AvailabilityChanged = Instance.new("BindableEvent")
RealmEditorController.Changed = Changed.Event
RealmEditorController.AvailabilityChanged = AvailabilityChanged.Event

local Freecam, MenuController, AlertController
local Active = false
local Available: boolean? = nil
local Blocked = {
	"Died", "Downed", "Ragdoll", "InCombat", "RealmTeleporting", "InWisdomWorld",
	"Mounted", "InHorse", "Climbing", "WallRunning", "Vaulting", "Meditating",
	"Attack", "Attacking", "Blocking", "BowDrawing", "SkillLockMovement",
}

function RealmEditorController:GetRealm(): Model?
	local Folder = workspace:FindFirstChild("Realms")
	if Folder then
		for _, Realm in Folder:GetChildren() do
			if Realm:IsA("Model") and Realm:GetAttribute("OwnerId") == Player.UserId then
				return Realm
			end
		end
	end

	return nil
end

function RealmEditorController:CanOpen(): boolean
	local Character = Player.Character
	local Realm = self:GetRealm()
	local Humanoid = Character and Character:FindFirstChildWhichIsA("Humanoid")
	if not Character or not Character.PrimaryPart or not Humanoid or Humanoid.Health <= 0
		or not Character:GetAttribute("InRealm") or not Realm or not Character:IsDescendantOf(Realm)
		or not Realm:GetAttribute("Loaded") or Realm:GetAttribute("Unloading") or Player:GetAttribute("InCombat") then
		return false
	end
	for _, Attribute in Blocked do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end

	return true
end

function RealmEditorController:IsOpen(): boolean
	return Active
end

function RealmEditorController:Close()
	if not Active then
		return
	end

	Active = false
	Freecam:Stop()
	MenuController:SetHudFocus(false)
	Changed:Fire(false)
end

function RealmEditorController:Open(): boolean
	if Active then
		return true
	end
	local Realm = self:GetRealm()
	if not self:CanOpen() or not Realm then
		return false
	end
	if not Freecam:Start(Realm) then
		AlertController:Alert("Camera is currently in use", "Warn")
		return false
	end

	Active = true
	MenuController:CloseAllMenus()
	MenuController:SetHudFocus(true)
	Changed:Fire(true)

	return true
end

local function RefreshAvailability()
	local CanOpen = RealmEditorController:CanOpen()
	if not CanOpen then
		RealmEditorController:Close()
	end
	if CanOpen ~= Available then
		Available = CanOpen
		AvailabilityChanged:Fire(CanOpen)
	end
end

local function BindCharacter(Character: Model)
	for _, Attribute in Blocked do
		Character:GetAttributeChangedSignal(Attribute):Connect(RefreshAvailability)
	end
	Character:GetAttributeChangedSignal("InRealm"):Connect(RefreshAvailability)
	Character.AncestryChanged:Connect(RefreshAvailability)
	RefreshAvailability()
end

local function BindRealm(Realm: Instance)
	if Realm:IsA("Model") then
		for _, Attribute in { "Loaded", "Unloading", "OwnerId" } do
			Realm:GetAttributeChangedSignal(Attribute):Connect(RefreshAvailability)
		end
	end
	RefreshAvailability()
end

local function BindFolder(Folder: Instance)
	if Folder.Name ~= "Realms" then
		return
	end
	Folder.ChildAdded:Connect(BindRealm)
	Folder.ChildRemoved:Connect(RefreshAvailability)
	for _, Realm in Folder:GetChildren() do
		BindRealm(Realm)
	end
end

function RealmEditorController.KnitInit()
	Freecam = Knit.GetController("RealmFreecamController")
	MenuController = Knit.GetController("MenuController")
	AlertController = Knit.GetController("AlertController")
end

function RealmEditorController.KnitStart()
	Freecam.Stopped:Connect(function()
		RealmEditorController:Close()
	end)
	Player:GetAttributeChangedSignal("InCombat"):Connect(RefreshAvailability)
	Player.CharacterAdded:Connect(BindCharacter)
	Player.CharacterRemoving:Connect(function()
		RealmEditorController:Close()
	end)
	if Player.Character then
		BindCharacter(Player.Character)
	end
	workspace.ChildAdded:Connect(BindFolder)
	local Folder = workspace:FindFirstChild("Realms")
	if Folder then
		BindFolder(Folder)
	end
	RefreshAvailability()
end

return RealmEditorController
