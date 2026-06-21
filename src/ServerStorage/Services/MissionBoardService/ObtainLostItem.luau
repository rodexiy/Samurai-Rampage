local ObtainLostItem = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local MissionBoardService = Knit.GetService("MissionBoardService")
local AIService = Knit.GetService("AIService")
local MobService = Knit.GetService("MobService")
local QuestService = Knit.GetService("QuestService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AlertService = Knit.GetService("AlertService")
local InteractionService = Knit.GetService("InteractionService")
local ObjectiveService = Knit.GetService("ObjectiveService")

local Vases = ReplicatedStorage.Assets.Models.Vases:GetChildren()
local AllEnemies = {}
local BoardPosition = Vector3.new(131, 32, -26)

local function GetObjectiveName(Mission: { any }): string
	return "MissionBoardObtainLostItem_" .. Mission.Id
end

local function GetTargetName(Mission: { any }): string
	return "Find Hidden Item " .. Mission.Id
end

function ObtainLostItem:Randomize(Player: Player)
	local HiddenArea = MissionBoardService:GetRandomPointInSpawn()
	local HiddenPosition

	repeat
		local OffsetedPosition = HiddenArea + Vector3.new(math.random(256, 256), 2500, math.random(-256, 256))
		HiddenPosition = MissionBoardService:RaycastDown(OffsetedPosition)
	until HiddenPosition ~= nil

	local Distance = math.ceil((BoardPosition - HiddenArea).Magnitude)
	local Description = "Find a hidden item approximately " .. Distance .. " meters away."
	local BaseExp = 200
	local RandomFactor = math.random(95, 105) / 100
	local DistanceMultiplier = math.clamp((Distance / 500), 1, 5)

	local Exp = math.floor((BaseExp * DistanceMultiplier) * RandomFactor)

	return {
		Name = "ObtainLostItem",
		DisplayName = "Lost Item",
		Description = Description,
		Exp = Exp,
		Tetsu = math.floor(Exp * 0.5),
		MissionData = {
			HiddenArea = HiddenArea,
			HiddenPosition = HiddenPosition,
		},
		Image = "rbxassetid://83249363669921",
	}
end

function ObtainLostItem:Select(Player: Player, Mission: { any })
	local HiddenPosition = Mission.MissionData.HiddenPosition
	Mission.MissionData.ObjectiveName = GetObjectiveName(Mission)

	local Vase = Vases[math.random(1, #Vases)]:Clone()
	Mission.MissionData.Vase = Vase

	Vase:PivotTo(
		CFrame.new(HiddenPosition + Vector3.new(0, Vase.PrimaryPart.Size.Y / 2, 0))
			* CFrame.Angles(0, math.rad(math.random(1, 360)), 0)
	)

	local AreaModel: Model = Instance.new("Model")
	AreaModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	AreaModel.Name = "Area"
	AreaModel.Parent = workspace

	local Area = Instance.new("Part")
	AreaModel.PrimaryPart = Area
	Area.Name = "Area"
	Area.Anchored = true
	Area.CanCollide = false
	Area.Transparency = 1
	Area.Size = Vector3.new(1, 1, 1)
	Area.CFrame = CFrame.new(HiddenPosition) * CFrame.new(0, 32, 0)
	Area.Parent = AreaModel
	Mission.MissionData.AreaModel = AreaModel

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.ActionText = "Pick lost item"
	Prompt.Parent = Area
	Prompt.RequiresLineOfSight = false
	Prompt.HoldDuration = 0
	Prompt.Parent = Vase

	Vase.Parent = workspace

	-- Criar o objetivo
	ObjectiveService:AddObjective(Player, Mission.MissionData.ObjectiveName, {
		{
			Name = "Locate the lost item",
			TargetAmount = 1,
			CurrentAmount = 0,
		},
	}, Mission.DisplayName)

	task.wait(0.5)

	Mission.MissionData.PromptConnection = Prompt.Triggered:Connect(function(PlayerWhoTriggered: Player)
		if PlayerWhoTriggered ~= Player then
			AlertService:AlertPlayer(Player, "This item is not for you.", "Error")
			return
		end

		local Character = Player.Character
		if not Character then
			return
		end

		local Distance = (Character:GetPivot().Position - Prompt.Parent:GetPivot().Position).Magnitude
		if Distance > Prompt.MaxActivationDistance + 5 then
			return
		end

		Vase:Destroy()

		ObjectiveService:UpdateProgress(Player, Mission.MissionData.ObjectiveName, 1, 1)

		MissionBoardService:FinishedMission(Player, Mission)
	end)

	QuestService:CreateTarget(Player, GetTargetName(Mission), Area)
end

function ObtainLostItem:Destroy(Player: Player, Mission: { any })
	QuestService:RemoveTarget(Player, GetTargetName(Mission))

	if Mission.MissionData.PromptConnection then
		Mission.MissionData.PromptConnection:Disconnect()
		Mission.MissionData.PromptConnection = nil
	end

	local Vase = Mission.MissionData.Vase
	if Mission.MissionData.AreaModel then
		Mission.MissionData.AreaModel:Destroy()
	end
	if Vase then
		Vase:Destroy()
	end
end

return ObtainLostItem
