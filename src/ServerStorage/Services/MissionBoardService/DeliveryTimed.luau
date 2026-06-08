local DeliveryTimed = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local AlertService = Knit.GetService("AlertService")
local MissionBoardService = Knit.GetService("MissionBoardService")
local ObjectiveService = Knit.GetService("ObjectiveService")
local QuestService = Knit.GetService("QuestService")

local ObjectiveNamePrefix = "MissionBoardDeliveryTimed"
local TargetNamePrefix = "Timed Delivery"
local BoardPosition = Vector3.new(131, 32, -26)

local MIN_TIME_LIMIT = 75
local MAX_TIME_LIMIT = 360
local BASE_TIME_LIMIT = 45
local ASSUMED_TRAVEL_SPEED = 16
local TIME_BUFFER_MULTIPLIER = 1.8

local BASE_EXP = 180
local EXP_PER_STUD = 0.6
local TETSU_RATIO = 0.35

local function GetObjectiveName(Mission: { any }): string
	return ObjectiveNamePrefix .. "_" .. Mission.Id
end

local function GetTargetName(Mission: { any }): string
	return TargetNamePrefix .. " " .. Mission.Id
end

local function GetDeliveryAreasFolder(): Instance?
	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	local Models = Assets and Assets:FindFirstChild("Models")
	return Models and Models:FindFirstChild("TimedDeliveryAreas")
end

local function GetAreaCFrame(Area: Instance): CFrame?
	if Area:IsA("BasePart") then
		return Area.CFrame
	end

	if Area:IsA("Model") then
		return Area:GetBoundingBox()
	end

	return nil
end

local function GetDeliveryAreas(): { Instance }
	local Folder = GetDeliveryAreasFolder()
	if not Folder then
		return {}
	end

	local Areas = {}
	for _, Area in Folder:GetChildren() do
		if GetAreaCFrame(Area) then
			table.insert(Areas, Area)
		end
	end

	return Areas
end

local function GetStartPosition(Player: Player): Vector3
	local Character = Player.Character
	if Character and Character.Parent then
		return Character:GetPivot().Position
	end

	return BoardPosition
end

local function GetTimeLimit(Distance: number): number
	local TravelTime = Distance / ASSUMED_TRAVEL_SPEED
	return math.floor(math.clamp(BASE_TIME_LIMIT + (TravelTime * TIME_BUFFER_MULTIPLIER), MIN_TIME_LIMIT, MAX_TIME_LIMIT))
end

local function GetRewards(Distance: number): (number, number)
	local RandomFactor = math.random(95, 105) / 100
	local Exp = math.floor((BASE_EXP + (Distance * EXP_PER_STUD)) * RandomFactor)
	local Tetsu = math.floor(Exp * TETSU_RATIO)

	return Exp, Tetsu
end

local function FormatTime(Seconds: number): string
	local Minutes = math.floor(Seconds / 60)
	local RemainingSeconds = Seconds % 60

	if Minutes <= 0 then
		return tostring(RemainingSeconds) .. "s"
	end

	return tostring(Minutes) .. "m " .. tostring(RemainingSeconds) .. "s"
end

local function GetAreaByName(AreaName: string): Instance?
	local Folder = GetDeliveryAreasFolder()
	if not Folder then
		return nil
	end

	return Folder:FindFirstChild(AreaName)
end

local function ConfigureAreaPart(Part: BasePart)
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanQuery = true
	Part.CanTouch = false
end

local function CreateDeliveryTarget(AreaTemplate: Instance, DestinationCFrame: CFrame): Model
	local AreaModel = Instance.new("Model")
	AreaModel.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	AreaModel.Name = "TimedDeliveryTarget"

	local AreaClone = AreaTemplate:Clone()
	if AreaClone:IsA("BasePart") then
		AreaClone.CFrame = DestinationCFrame
		ConfigureAreaPart(AreaClone)
		AreaClone.Parent = AreaModel
		AreaModel.PrimaryPart = AreaClone
	elseif AreaClone:IsA("Model") then
		AreaClone:PivotTo(DestinationCFrame)
		for _, Descendant in AreaClone:GetDescendants() do
			if Descendant:IsA("BasePart") then
				ConfigureAreaPart(Descendant)
			end
		end

		for _, Child in AreaClone:GetChildren() do
			Child.Parent = AreaModel
		end

		AreaClone:Destroy()
		AreaModel.PrimaryPart = AreaModel.PrimaryPart or AreaModel:FindFirstChildWhichIsA("BasePart", true)
	end

	AreaModel.Parent = workspace

	return AreaModel
end

local function IsCharacterInsideTarget(Character: Model, TargetModel: Model): boolean
	local RootPart = Character:FindFirstChild("HumanoidRootPart")
	if not RootPart then
		return false
	end

	local TargetCFrame, TargetSize = TargetModel:GetBoundingBox()
	local RootPosition = RootPart.Position
	local TargetPosition = TargetCFrame.Position

	local HorizontalDistance = Vector2.new(
		RootPosition.X - TargetPosition.X,
		RootPosition.Z - TargetPosition.Z
	).Magnitude
	local HorizontalRadius = math.max(TargetSize.X, TargetSize.Z) * 0.5
	local VerticalTolerance = math.max(TargetSize.Y + 8, 12)

	if math.abs(RootPosition.Y - TargetPosition.Y) > VerticalTolerance then
		return false
	end

	return HorizontalDistance <= HorizontalRadius
end

function DeliveryTimed:Randomize(Player: Player)
	local Areas = GetDeliveryAreas()
	if #Areas == 0 then
		return {
			Name = "DeliveryTimed",
			DisplayName = "Timed Delivery",
			Description = "No delivery routes are available right now.",
			Exp = 0,
			Tetsu = 0,
			MissionData = {
				Unavailable = true,
			},
			Image = "rbxassetid://112909274709176",
		}
	end

	local Area = Areas[math.random(1, #Areas)]
	local DestinationCFrame = GetAreaCFrame(Area)
	local Distance = math.floor((DestinationCFrame.Position - GetStartPosition(Player)).Magnitude)
	local TimeLimit = GetTimeLimit(Distance)
	local Exp, Tetsu = GetRewards(Distance)

	return {
		Name = "DeliveryTimed",
		DisplayName = "Timed Delivery",
		Description = "Deliver a package " .. Distance .. " meters away within " .. FormatTime(TimeLimit) .. ".",
		Exp = Exp,
		Tetsu = Tetsu,
		MissionData = {
			DeliveryAreaName = Area.Name,
			DestinationCFrame = DestinationCFrame,
			Distance = Distance,
			TimeLimit = TimeLimit,
		},
		Image = "rbxassetid://112909274709176",
	}
end

function DeliveryTimed:Select(Player: Player, Mission: { any })
	local Data = Mission.MissionData
	if Data.Unavailable or not Data.DestinationCFrame then
		AlertService:AlertPlayer(Player, "No delivery routes are available right now.", "Error")
		MissionBoardService:DestroyMission(Player, Mission)
		return
	end

	local AreaTemplate = GetAreaByName(Data.DeliveryAreaName)
	if not AreaTemplate then
		AlertService:AlertPlayer(Player, "Delivery route could not be found.", "Error")
		MissionBoardService:DestroyMission(Player, Mission)
		return
	end

	Data.StartedAt = workspace:GetServerTimeNow()
	Data.Completed = false
	Data.Cancelled = false
	Data.ObjectiveName = GetObjectiveName(Mission)
	Data.TargetName = GetTargetName(Mission)
	Data.TargetModel = CreateDeliveryTarget(AreaTemplate, Data.DestinationCFrame)

	ObjectiveService:AddObjective(Player, Data.ObjectiveName, {
		{
			Name = "Deliver the package",
			TargetAmount = Data.TimeLimit,
			CurrentAmount = 0,
			EndTime = Data.StartedAt + Data.TimeLimit,
		},
	})

	QuestService:CreateTargetAtPosition(Player, Data.TargetName, Data.DestinationCFrame.Position)
	AlertService:AlertPlayer(Player, "Timed delivery started. Time limit: " .. FormatTime(Data.TimeLimit), "Default")

	Data.AreaCheckThread = task.spawn(function()
		if Data.Completed or Data.Cancelled then
			return
		end

		while not Data.Completed and not Data.Cancelled do
			local Character = Player.Character
			if Character and Character.Parent and IsCharacterInsideTarget(Character, Data.TargetModel) then
				local Elapsed = workspace:GetServerTimeNow() - Data.StartedAt
				if Elapsed > Data.TimeLimit then
					Data.AreaCheckThread = nil
					AlertService:AlertPlayer(Player, "Delivery failed. You ran out of time.", "Error")
					MissionBoardService:DestroyMission(Player, Mission)
					return
				end

				Data.Completed = true
				Data.AreaCheckThread = nil
				ObjectiveService:UpdateProgress(Player, Data.ObjectiveName, 1, Data.TimeLimit)
				MissionBoardService:FinishedMission(Player, Mission)
				return
			end

			task.wait(0.1)
		end
	end)

	Data.TimeoutThread = task.delay(Data.TimeLimit, function()
		if Data.Completed or Data.Cancelled then
			return
		end

		Data.Cancelled = true
		Data.TimeoutThread = nil
		AlertService:AlertPlayer(Player, "Delivery failed. You ran out of time.", "Error")
		MissionBoardService:DestroyMission(Player, Mission)
	end)
end

function DeliveryTimed:Destroy(Player: Player, Mission: { any })
	local Data = Mission.MissionData
	Data.Cancelled = true

	if Data.TimeoutThread then
		task.cancel(Data.TimeoutThread)
		Data.TimeoutThread = nil
	end

	if Data.AreaCheckThread then
		task.cancel(Data.AreaCheckThread)
		Data.AreaCheckThread = nil
	end

	QuestService:RemoveTarget(Player, Data.TargetName or GetTargetName(Mission))

	if Data.TargetModel then
		Data.TargetModel:Destroy()
		Data.TargetModel = nil
	end
end

return DeliveryTimed
