local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Meditate = {}

local Knit = require(ReplicatedStorage.Packages.Knit)

local Player = Players.LocalPlayer
local Character = Player.Character

local Params = RaycastParams.new()
Params.FilterDescendantsInstances = { workspace:WaitForChild("Entity") }
Params.FilterType = Enum.RaycastFilterType.Exclude

local CharacterShared = require(ReplicatedStorage.Shared.CharacterShared)

local Animation = ReplicatedStorage.Assets.Animations.Misc.Meditate
local AnimationController = Knit.GetController("AnimationController")
local MenuController = Knit.GetController("MenuController")
local RugService = Knit.GetService("RugService")
local StatService = Knit.GetService("StatService")
local FastTravelController = Knit.GetController("FastTravelController")

local MAX_RUG_DISTANCE = 10
local MeditationActive = Character:GetAttribute("Meditating") == true

local function IsNearRug(): boolean
	local Rugs = workspace:FindFirstChild("Rugs")
	if not Rugs then
		return false
	end

	local CharacterPosition = Character:GetPivot().Position
	for _, Rug in Rugs:GetChildren() do
		local RugPart = Rug:FindFirstChild("Rug")
		local RugPosition
		if RugPart and RugPart:IsA("BasePart") then
			RugPosition = RugPart.Position
		elseif Rug:IsA("Model") or Rug:IsA("BasePart") then
			RugPosition = Rug:GetPivot().Position
		end

		if RugPosition and (RugPosition - CharacterPosition).Magnitude < MAX_RUG_DISTANCE then
			return true
		end
	end

	return false
end

local function ClearMeditation()
	MeditationActive = false
	CharacterShared:UpdateBoth(Character)
	AnimationController:StopAnimationFind(Character, "Meditate")

	MenuController:CloseAllMenus()
end

function Meditate.Stop()
	if not MeditationActive and not Character:GetAttribute("Meditating") then
		return
	end

	MeditationActive = false
	Character:SetAttribute("Meditating", false)
	StatService.SetMeditating:Fire(false)
	ClearMeditation()
end

function Meditate.callback(inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	if Character:GetAttribute("RealmEditing") then
		return
	end

	if MeditationActive or Character:GetAttribute("Meditating") then
		if Character:GetAttribute("RealmTeleporting") then
			return
		end
		Meditate.Stop()
		return
	end

	if Player:GetAttribute("InIntroCutscene") then
		return
	end

	local ray: RaycastResult = workspace:Raycast(Character.PrimaryPart.Position, Vector3.new(0, -3, 0), Params)
	local IsInWisdomWorld = Character:GetAttribute("InWisdomWorld") or Player:GetAttribute("InWisdomWorld")

	if IsInWisdomWorld then
		return
	end
	if (not ray or not ray.Instance:FindFirstAncestor("Rugs"))
		and not IsNearRug()
		and not Player:GetAttribute("MeditateAnywhere")
	then
		return
	end

	if not IsInWisdomWorld and Character.Humanoid.FloorMaterial == Enum.Material.Air then
		return
	end

	FastTravelController:LoadLocations()
	MeditationActive = true
	AnimationController:PlayAnimation(Character, Animation)
	MenuController:OpenMenu("Meditate")
	Character:SetAttribute("Meditating", true)
	StatService.SetMeditating:Fire(true)
	RugService:UnlockRug(Player)
	CharacterShared:UpdateBoth(Character)
end

Meditate.keys = { Enum.KeyCode.M }

Character:GetAttributeChangedSignal("Meditating"):Connect(function()
	if MeditationActive and not Character:GetAttribute("Meditating") then
		ClearMeditation()
	end
end)

Character:GetAttributeChangedSignal("InRealm"):Connect(Meditate.Stop)

Character:GetAttributeChangedSignal("BeenHitted"):Connect(function()
	if Character:GetAttribute("BeenHitted") then
		Meditate.Stop()
	end
end)


return Meditate
