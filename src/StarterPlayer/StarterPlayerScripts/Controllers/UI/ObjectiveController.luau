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

function ObjectiveController:RenderObjective(
	ObjectiveName: string,
	SubObjectives: { { Name: string, TargetAmount: number, CurrentAmount: number } }
)
	ObjectiveHUD.Enabled = true

	AbandonQuest.Visible = ObjectiveName ~= "PrisonLabor"

	for _, child in ipairs(Content:GetChildren()) do
		if child.Name ~= "Template" and child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, Data in ipairs(SubObjectives) do
		local SubFrame = Template:Clone()
		SubFrame.Name = Data.Name
		SubFrame.ObjectiveName.Text = Data.Name
		SubFrame.Amount.Text = string.format("%d/%d", Data.CurrentAmount, Data.TargetAmount)
		SubFrame.Progress.Bar.Size = UDim2.new(Data.CurrentAmount / Data.TargetAmount, 0, 1, 0)
		SubFrame.Visible = true
		SubFrame.Parent = Content
	end
end

function ObjectiveController:UpdateObjective(
	SubObjective: { Name: string, TargetAmount: number, CurrentAmount: number }
)
	local SubFrame = Content:FindFirstChild(SubObjective.Name)
	if not SubFrame then
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

	ObjectiveService.ObjectiveCleared:Connect(function(Completed)
		for _, child in ipairs(Content:GetChildren()) do
			if child.Name ~= "Template" and child:IsA("Frame") then
				child:Destroy()
			end
		end

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

		ObjectiveHUD.Enabled = false
	end)

	local Objective = ObjectiveService:GetObjectives(Player)
	if Objective then
		for _, Objective in pairs(Objective) do
			ObjectiveController:RenderObjective(Objective.Name, Objective.Objectives)
		end
	end
end

return ObjectiveController
