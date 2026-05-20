local Knit = require(game.ReplicatedStorage.Packages.Knit)

local QuestTargetController = Knit.CreateController({
	Name = "QuestTargetController",
})

local TargetTemplate = game.ReplicatedStorage.Assets.Billboards.QuestTarget

local Targets = {}

local QuestService

local Player = game.Players.LocalPlayer

function QuestTargetController:CreateTarget(Title: string, Parent: Instance)
	local Target = TargetTemplate:Clone()
	Target.Name = Title
	Target.Info.Text = Title:find("DONTSHOW") and "" or Title
	Target.Parent = Parent
	Target.Enabled = true

	table.insert(Targets, Target)
end

function QuestTargetController:RemoveTarget(Title: string)
	for index, Target in Targets do
		if Target.Name == Title then
			Target:Destroy()
			table.remove(Targets, index)
		end
	end
end

function QuestTargetController:Update()
	local Character = Player.Character
	if not Character then
		return
	end
	for index, Target: Model in Targets do
		if Target.Parent == nil then
			Target:Destroy()
			table.remove(Targets, index)
		end

		local Distance = (Target.Parent:GetPivot().Position - Character:GetPivot().Position).Magnitude
		Target.Distance.Text = math.floor(Distance * 0.28) .. "M"
	end
end

function QuestTargetController.KnitStart()
	QuestService = Knit.GetService("QuestService")

	QuestService.CreateTargetBillboard:Connect(function(Title: string, Parent: Instance)
		QuestTargetController:CreateTarget(Title, Parent)
	end)
	QuestService.RemoveTargetBillboard:Connect(function(Title: string)
		QuestTargetController:RemoveTarget(Title)
	end)

	while true do
		QuestTargetController:Update()
		task.wait(0.1)
	end
end

return QuestTargetController
