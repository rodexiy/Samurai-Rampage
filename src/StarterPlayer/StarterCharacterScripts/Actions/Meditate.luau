local ContextActionService = game:GetService("ContextActionService")
local Meditate = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Player = game.Players.LocalPlayer
local Character = Player.Character

local Params = RaycastParams.new()
Params.FilterDescendantsInstances = { workspace:WaitForChild("Entity") }
Params.FilterType = Enum.RaycastFilterType.Exclude

local CharacterShared = require(game.ReplicatedStorage.Shared.CharacterShared)

local Animation = game.ReplicatedStorage.Assets.Animations.Misc.Meditate
local AnimationController = Knit.GetController("AnimationController")
local MenuController = Knit.GetController("MenuController")
local DeviceController = Knit.GetController("DeviceController")
local RugService = Knit.GetService("RugService")
local FastTravelController = Knit.GetController("FastTravelController")

function Meditate.Stop()
	if not Character:GetAttribute("Meditating") then
		return
	end
	Character:SetAttribute("Meditating", false)

	CharacterShared:UpdateBoth(Character)
	AnimationController:StopAnimationFind(Character, "Meditate")

	MenuController:CloseAllMenus()
end

function Meditate.callback(inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end

	if Character:GetAttribute("Meditating") then
		Meditate.Stop()
		return
	end

	local ray: RaycastResult = workspace:Raycast(Character.PrimaryPart.Position, Vector3.new(0, -3, 0), Params)

	if (not ray or not ray.Instance:FindFirstAncestor("Rugs")) and not Player:GetAttribute("MeditateAnywhere") then
		return
	end

	if Character.Humanoid.FloorMaterial == Enum.Material.Air then
		return
	end

	FastTravelController:LoadLocations()
	AnimationController:PlayAnimation(Character, Animation)
	MenuController:OpenMenu("Meditate")
	Character:SetAttribute("Meditating", true)
	RugService:UnlockRug(Player)
	CharacterShared:UpdateBoth(Character)
end

Meditate.keys = { Enum.KeyCode.M }

DeviceController:BindAction("Meditate", Meditate.callback, "Meditate", UDim2.fromScale(0.1, 0.475))

Character:GetAttributeChangedSignal("BeenHitted"):Connect(function()
	if Character:GetAttribute("BeenHitted") then
		Meditate.Stop()
	end
end)

return Meditate
