local Knit = require(game.ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local InventoryController = Knit.GetController("InventoryController")
local StatusController = Knit.GetController("StatusController")

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
repeat
	task.wait()
until Character:GetAttribute("Loaded") or not Character.Parent

local AttributesToUpdate = {
	"MaxHealth",
	"MaxStamina",
	"MaxPosture",
	"RunningWalkSpeed",
	"RunSpeedMultiplier",
	"RunSpeedIncrease",
	"Weapon",
	"LeftWeapon",
	"SwordDamage",
}

Character:GetAttributeChangedSignal("Health"):Connect(function()
	StatusController:UpdateHealth()
end)

for _, Attribute in AttributesToUpdate do
	Character:GetAttributeChangedSignal(Attribute):Connect(function()
		InventoryController:UpdateStatus()
	end)
end

StatusController:UpdateHealth()
InventoryController:UpdateStatus()
