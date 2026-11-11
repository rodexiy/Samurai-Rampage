local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local Player = Players.LocalPlayer
local Character = Player.Character

local WeaponService
local DeviceController = Knit.GetController("DeviceController")
local Attack = {
	callback = function(inputState: Enum.UserInputState, _InputObject: InputObject?)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end

		if not Character:GetAttribute("WeaponEquipped")
			or Character:GetAttribute("Meditating") or Character:GetAttribute("BowEquipped") then
			return
		end

		Character:SetAttribute("ClientAttacking", true)
		task.delay(0.2, function()
			Character:SetAttribute("ClientAttacking", false)
		end)

		WeaponService:WeaponInput("Attack", { RootCFrame = Character:GetPivot() })
	end,

	keys = {},
}

if DeviceController:IsMobile() then
	Character:GetAttributeChangedSignal("WeaponEquipped"):Connect(function()
		if Character:GetAttribute("WeaponEquipped") then
			DeviceController:BindAction("Attack", Attack.callback, "Attack", UDim2.fromScale(0.775, 0.55))
		else
			DeviceController:UnbindAction("Attack")
		end
	end)
else
	table.insert(Attack.keys, Enum.UserInputType.MouseButton1)
end

function Attack.Start()
	WeaponService = Knit.GetService("WeaponService")
end

return Attack
