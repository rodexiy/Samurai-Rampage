local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ObjectiveController = Knit.CreateController({
	Name = "ObjectiveController",
})

local ObjectiveService
local Player = game.Players.LocalPlayer

local PlayerGui: PlayerGui
local Hud: Frame
local ObjectiveHUD: Frame
local Background: Frame
local Content: Frame
local Template: Frame
local AbandonQuest: TextButton
local TimerFrames = {}

local function GetObjectiveFrameName(ObjectiveName: string, Index: number): string
	return ObjectiveName .. "_" .. tostring(Index)
end

local function RefreshObjectiveHud()
	local HasObjectives = false
	local HasAbandonableObjective = false

	for _, child in ipairs(Content:GetChildren()) do
		if child.Name ~= "Template" and child:IsA("Frame") then
			HasObjectives = true
			if child:GetAttribute("ObjectiveName") ~= "PrisonLabor" then
				HasAbandonableObjective = true
			end
		end
	end

	ObjectiveHUD.Enabled = HasObjectives
	AbandonQuest.Visible = HasAbandonableObjective
end

local function ClearRenderedObjective(ObjectiveName: string?)
	for _, child in ipairs(Content:GetChildren()) do
		if child.Name ~= "Template" and child:IsA("Frame") then
			if not ObjectiveName or child:GetAttribute("ObjectiveName") == ObjectiveName then
				TimerFrames[child] = nil
				child:Destroy()
			end
		end
	end

	RefreshObjectiveHud()
end

local function FormatTime(Seconds: number): string
	Seconds = math.max(0, math.ceil(Seconds))

	local Minutes = math.floor(Seconds / 60)
	local RemainingSeconds = Seconds % 60

	if Minutes <= 0 then
		return tostring(RemainingSeconds) .. "s"
	end

	return string.format("%d:%02d", Minutes, RemainingSeconds)
end

local function UpdateTimerFrame(SubFrame: Frame)
	local EndTime = SubFrame:GetAttribute("EndTime")
	local TimeLimit = SubFrame:GetAttribute("TimeLimit")
	if typeof(EndTime) ~= "number" or typeof(TimeLimit) ~= "number" or TimeLimit <= 0 then
		return
	end

	local TimeLeft = math.max(0, EndTime - workspace:GetServerTimeNow())
	SubFrame.Amount.Text = FormatTime(TimeLeft)
	SubFrame.Progress.Bar.Size = UDim2.new(math.clamp(TimeLeft / TimeLimit, 0, 1), 0, 1, 0)
end

function ObjectiveController:RenderObjective(
	ObjectiveName: string,
	SubObjectives: { { Name: string, TargetAmount: number, CurrentAmount: number, EndTime: number? } }
)
	ObjectiveHUD.Enabled = true

	ClearRenderedObjective(ObjectiveName)

	for Index, Data in ipairs(SubObjectives) do
		local SubFrame = Template:Clone()
		SubFrame.Name = GetObjectiveFrameName(ObjectiveName, Index)
		SubFrame:SetAttribute("ObjectiveName", ObjectiveName)
		SubFrame:SetAttribute("ObjectiveIndex", Index)
		SubFrame.ObjectiveName.Text = Data.Name
		if Data.EndTime then
			SubFrame:SetAttribute("EndTime", Data.EndTime)
			SubFrame:SetAttribute("TimeLimit", Data.TargetAmount)
			TimerFrames[SubFrame] = true
			UpdateTimerFrame(SubFrame)
		else
			SubFrame.Amount.Text = string.format("%d/%d", Data.CurrentAmount, Data.TargetAmount)
			SubFrame.Progress.Bar.Size = UDim2.new(Data.CurrentAmount / Data.TargetAmount, 0, 1, 0)
		end
		SubFrame.Visible = true
		SubFrame.Parent = Content
	end

	RefreshObjectiveHud()
end

function ObjectiveController:UpdateObjective(
	ObjectiveName: string,
	Index: number,
	SubObjective: { Name: string, TargetAmount: number, CurrentAmount: number }
)
	local SubFrame = Content:FindFirstChild(GetObjectiveFrameName(ObjectiveName, Index))
	if not SubFrame then
		return
	end

	if TimerFrames[SubFrame] then
		return
	end

	SubFrame.Amount.Text = string.format("%d/%d", SubObjective.CurrentAmount, SubObjective.TargetAmount)
	SubFrame.Progress.Bar.Size = UDim2.new(SubObjective.CurrentAmount / SubObjective.TargetAmount, 0, 1, 0)
end

function ObjectiveController:KnitStart()
	ObjectiveService = Knit.GetService("ObjectiveService")

	PlayerGui = Player:WaitForChild("PlayerGui")
	Hud = PlayerGui:WaitForChild("Hud")
	ObjectiveHUD = Hud:WaitForChild("Objective")
	Background = ObjectiveHUD:WaitForChild("Background")
	Content = Background:WaitForChild("content")
	Template = Content:WaitForChild("Template")
	AbandonQuest = Background:WaitForChild("Title"):WaitForChild("Abandon")

	ObjectiveHUD.Enabled = false
	Template.Visible = false

	ObjectiveService.ObjectiveAdded:Connect(function(ObjectiveName, Data)
		self:RenderObjective(ObjectiveName, Data.Objectives)
	end)

	ObjectiveService.ObjectiveUpdated:Connect(function(ObjectiveName, Index, SubObjective)
		self:UpdateObjective(ObjectiveName, Index, SubObjective)
	end)

	ObjectiveService.ObjectiveCleared:Connect(function(ObjectiveName, Completed)
		if typeof(ObjectiveName) == "boolean" then
			Completed = ObjectiveName
			ObjectiveName = nil
		end

		ClearRenderedObjective(ObjectiveName)

		if Completed then
			local OCUI = Hud.ObjectiveCompleted
			OCUI.Enabled = true

			TweenService:Create(OCUI.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.985, OCUI.Title.Position.Y.Scale),
			}):Play()

			task.delay(1.5, function()
				TweenService:Create(OCUI.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.fromScale(1.3, OCUI.Title.Position.Y.Scale),
				}):Play()

				task.delay(0.25, function()
					OCUI.Enabled = false
				end)
			end)
		end
	end)

	local Objective = ObjectiveService:GetObjectives(Player)
	if Objective then
		for _, Objective in pairs(Objective) do
			ObjectiveController:RenderObjective(Objective.Name, Objective.Objectives)
		end
	end

	task.spawn(function()
		while true do
			for SubFrame in TimerFrames do
				if not SubFrame.Parent then
					TimerFrames[SubFrame] = nil
					continue
				end

				UpdateTimerFrame(SubFrame)
			end

			task.wait(0.25)
		end
	end)
end

return ObjectiveController
