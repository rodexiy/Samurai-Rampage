local Players = game:GetService("Players")

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RugDiscoveryController = Knit.CreateController({
	Name = "RugDiscoveryController",
})

local Player = Players.LocalPlayer

local COMPASS_DISTANCE = 100
local PROMPT_DISTANCE = 10
local TARGET_PREFIX = "UnknownRug:"
local DISCOVERED_RUG_ICON = "rbxassetid://136206430829037"

local RugService
local QuestTargetController

local UnlockedRugs = {}
local TargetsByRug = {}
local PromptsByRug = {}

local function GetRugPart(Rug: Instance): BasePart?
	local RugPart = Rug:FindFirstChild("Rug")
	if RugPart and RugPart:IsA("BasePart") then
		return RugPart
	end
	if Rug:IsA("BasePart") then
		return Rug
	end
	return Rug:FindFirstChildWhichIsA("BasePart", true)
end

local function IsUnlocked(Rug: Instance): boolean
	return UnlockedRugs[Rug.Name] == true
end

local function GetRugDisplayName(Rug: Instance): string
	local DisplayName = Rug:GetAttribute("DisplayName")
	if typeof(DisplayName) == "string" and DisplayName ~= "" then
		return DisplayName
	end

	return Rug.Name
end

local function GetRugLabel(Rug: Instance): string
	return if IsUnlocked(Rug) then GetRugDisplayName(Rug) else "Unknown Rug"
end

local function TriggerMeditate()
	local Character = Player.Character
	local Client = Character and Character:FindFirstChild("Client")
	local InputControllerModule = Client and Client:FindFirstChild("InputController")
	if not InputControllerModule or not InputControllerModule:IsA("ModuleScript") then
		return
	end

	local InputController = require(InputControllerModule)
	InputController.Caller("Meditate", Enum.UserInputState.Begin)
end

local function CreateMeditatePrompt(Rug: Instance, RugPart: BasePart)
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "MeditatePrompt"
	Prompt.ActionText = "Meditate"
	Prompt.ObjectText = GetRugLabel(Rug)
	Prompt.Style = Enum.ProximityPromptStyle.Custom
	Prompt.KeyboardKeyCode = Enum.KeyCode.M
	Prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = PROMPT_DISTANCE
	Prompt.RequiresLineOfSight = false
	Prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	Prompt.Triggered:Connect(TriggerMeditate)
	Prompt.Parent = RugPart
	PromptsByRug[Rug] = Prompt
end

local function RemoveTarget(Rug: Instance)
	if TargetsByRug[Rug] then
		QuestTargetController:RemoveTarget(TARGET_PREFIX .. Rug.Name)
		TargetsByRug[Rug] = nil
	end

	local Prompt = PromptsByRug[Rug]
	if Prompt then
		Prompt:Destroy()
		PromptsByRug[Rug] = nil
	end
end

local function AddTarget(Rug: Instance)
	if TargetsByRug[Rug] then
		return
	end

	local RugPart = GetRugPart(Rug)
	if not RugPart then
		return
	end

	local Options = {
		CompassOnly = true,
		CompassMaxDistance = COMPASS_DISTANCE,
		CompassLabel = GetRugLabel(Rug),
	}
	if IsUnlocked(Rug) then
		Options.CompassMode = "MissionName"
		Options.CompassIconImage = DISCOVERED_RUG_ICON
	else
		Options.CompassIconText = "?"
	end

	local Target = QuestTargetController:CreateTarget(TARGET_PREFIX .. Rug.Name, RugPart, Options)
	if Target then
		TargetsByRug[Rug] = Target
	end
	-- if not IsUnlocked(Rug) then
		CreateMeditatePrompt(Rug, RugPart)
	-- end
end

local function RefreshTargets()
	local Rugs = workspace:FindFirstChild("Rugs")
	if not Rugs then
		return
	end

	local ExistingRugs = {}
	for Rug in TargetsByRug do
		table.insert(ExistingRugs, Rug)
	end
	for _, Rug in ExistingRugs do
		RemoveTarget(Rug)
	end

	for _, Rug in Rugs:GetChildren() do
		AddTarget(Rug)
	end
end

local function SetUnlockedRugs(Locations)
	table.clear(UnlockedRugs)
	if typeof(Locations) == "table" then
		for _, RugName in Locations do
			if typeof(RugName) == "string" then
				UnlockedRugs[RugName] = true
			end
		end
	end
	RefreshTargets()
end

function RugDiscoveryController.KnitInit()
	RugService = Knit.GetService("RugService")
	QuestTargetController = Knit.GetController("QuestTargetController")
end

function RugDiscoveryController.KnitStart()
	local Rugs = workspace:WaitForChild("Rugs")
	SetUnlockedRugs(RugService:GetUnlockedRugs())

	RugService.UnlockedRug:Connect(SetUnlockedRugs)
	Rugs.ChildAdded:Connect(function(Rug)
		AddTarget(Rug)
	end)
	Rugs.ChildRemoved:Connect(function(Rug)
		RemoveTarget(Rug)
	end)
end

return RugDiscoveryController
