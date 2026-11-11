local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local Player = Players.LocalPlayer
local Character = Player.Character

local WeaponService
local DeviceController = Knit.GetController("DeviceController")
local StrongAttack = {
	callback = function(inputState: Enum.UserInputState, _InputObject: InputObject?)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end
		if not Character:GetAttribute("WeaponEquipped")
			or Character:GetAttribute("Meditating") or Character:GetAttribute("BowEquipped") then
			return
		end

		Character:SetAttribute("ClientStrongAttack", true)

		task.delay(0.2, function()
			Character:SetAttribute("ClientStrongAttack", false)
		end)
		WeaponService:WeaponInput("StrongAttack", { RootCFrame = Character:GetPivot() })
	end,

	keys = { Enum.KeyCode.R },
}

Character:GetAttributeChangedSignal("WeaponEquipped"):Connect(function()
	if Character:GetAttribute("WeaponEquipped") then
		DeviceController:BindAction(
			"StrongAttack",
			StrongAttack.callback,
			"Strong Attack",
			UDim2.fromScale(0.75, 0.725)
		)
	else
		DeviceController:UnbindAction("StrongAttack")
	end
end)

function StrongAttack.Start()
	WeaponService = Knit.GetService("WeaponService")
end

return StrongAttack
