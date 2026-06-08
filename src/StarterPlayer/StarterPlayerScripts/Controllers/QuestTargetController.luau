local Knit = require(game.ReplicatedStorage.Packages.Knit)

local QuestTargetController = Knit.CreateController({
	Name = "QuestTargetController",
})

local TargetTemplate = game.ReplicatedStorage.Assets.Billboards.QuestTarget

local Targets = {}

local QuestService

local Player = game.Players.LocalPlayer
local ClientTargetsFolder = workspace:FindFirstChild("ClientQuestTargets") or Instance.new("Folder")
ClientTargetsFolder.Name = "ClientQuestTargets"
ClientTargetsFolder.Parent = workspace

function QuestTargetController:CreateTarget(Title: string, Parent: Instance?)
	if not Parent then
		return
	end

	local Target = TargetTemplate:Clone()
	Target.Name = Title
	Target.Info.Text = Title:find("DONTSHOW") and "" or Title
	Target.Parent = Parent
	Target.Enabled = true

	table.insert(Targets, Target)
end

function QuestTargetController:CreateTargetAtPosition(Title: string, Position: Vector3)
	local TargetPart = Instance.new("Part")
	TargetPart.Name = Title .. "Target"
	TargetPart.Anchored = true
	TargetPart.CanCollide = false
	TargetPart.CanQuery = false
	TargetPart.CanTouch = false
	TargetPart.Transparency = 1
	TargetPart.Size = Vector3.new(1, 1, 1)
	TargetPart.Position = Position
	TargetPart.Parent = ClientTargetsFolder

	QuestTargetController:CreateTarget(Title, TargetPart)

	local Target = Targets[#Targets]
	if Target then
		Target:SetAttribute("DestroyParentOnRemove", true)
	end
end

function QuestTargetController:RemoveTarget(Title: string)
	for index = #Targets, 1, -1 do
		local Target = Targets[index]
		if Target.Name == Title then
			local Parent = Target.Parent
			local DestroyParent = Target:GetAttribute("DestroyParentOnRemove")
			Target:Destroy()
			table.remove(Targets, index)

			if DestroyParent and Parent then
				Parent:Destroy()
			end
		end
	end
end

function QuestTargetController:Update()
	local Character = Player.Character
	if not Character then
		return
	end

	for index = #Targets, 1, -1 do
		local Target = Targets[index]
		local Parent = Target.Parent
		if not Parent then
			Target:Destroy()
			table.remove(Targets, index)
			continue
		end

		local Distance = (Parent:GetPivot().Position - Character:GetPivot().Position).Magnitude
		Target.Distance.Text = math.floor(Distance * 0.28) .. "M"
	end
end

function QuestTargetController.KnitStart()
	QuestService = Knit.GetService("QuestService")

	QuestService.CreateTargetBillboard:Connect(function(Title: string, Parent: Instance)
		QuestTargetController:CreateTarget(Title, Parent)
	end)
	QuestService.CreateTargetBillboardAtPosition:Connect(function(Title: string, Position: Vector3)
		QuestTargetController:CreateTargetAtPosition(Title, Position)
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
