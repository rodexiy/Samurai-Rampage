local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local FeintController = Knit.CreateController({ Name = "FeintController" })
local Player = Players.LocalPlayer
local WeaponService
local DeviceController

local function Feint(State: Enum.UserInputState)
	local Character = Player.Character
	if State == Enum.UserInputState.Begin and Character and Character:GetAttribute("TalentFeint")
		and Character:GetAttribute("WeaponEquipped") then
		WeaponService:WeaponInput("Feint", {})
	end
end

local function BindCharacter(Character: Model)
	local function Refresh()
		DeviceController:UnbindAction("Feint")
		if Character:GetAttribute("TalentFeint") and Character:GetAttribute("WeaponEquipped") then
			DeviceController:BindAction("Feint", Feint, "Feint", UDim2.fromScale(0.65, 0.725))
		end
	end

	Character:GetAttributeChangedSignal("TalentFeint"):Connect(Refresh)
	Character:GetAttributeChangedSignal("WeaponEquipped"):Connect(Refresh)
	Refresh()
end

function FeintController.KnitInit()
	WeaponService = Knit.GetService("WeaponService")
	DeviceController = Knit.GetController("DeviceController")
end

function FeintController.KnitStart()
	UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if not Processed and Input.UserInputType == Enum.UserInputType.MouseButton2 then
			Feint(Enum.UserInputState.Begin)
		end
	end)
	Player.CharacterAdded:Connect(BindCharacter)
	if Player.Character then
		BindCharacter(Player.Character)
	end
end

return FeintController
