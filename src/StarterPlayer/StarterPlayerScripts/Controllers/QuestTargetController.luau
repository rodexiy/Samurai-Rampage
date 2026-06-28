local Knit = require(game.ReplicatedStorage.Packages.Knit)

local QuestTargetController = Knit.CreateController({
	Name = "QuestTargetController",
})

local TargetTemplate = game.ReplicatedStorage.Assets.Billboards.QuestTarget

local Targets = {}
local TargetAdded = Instance.new("BindableEvent")
local TargetRemoved = Instance.new("BindableEvent")

QuestTargetController.TargetAdded = TargetAdded.Event
QuestTargetController.TargetRemoved = TargetRemoved.Event

local QuestService

local Player = game.Players.LocalPlayer
local ClientTargetsFolder = workspace:FindFirstChild("ClientQuestTargets") or Instance.new("Folder")
ClientTargetsFolder.Name = "ClientQuestTargets"
ClientTargetsFolder.Parent = workspace

function QuestTargetController:CreateTarget(Title: string, Parent: Instance?, Options)
	if not Parent then
		return
	end

	local Target = TargetTemplate:Clone()
	Target.Name = Title
	Target.Info.Text = Title:find("DONTSHOW") and "" or Title

	if typeof(Options) == "table" then
		if typeof(Options.CompassMode) == "string" then
			Target:SetAttribute("CompassMode", Options.CompassMode)
		end
		if typeof(Options.CompassLabel) == "string" then
			Target:SetAttribute("CompassLabel", Options.CompassLabel)
		end
		if typeof(Options.CompassIconText) == "string" then
			Target:SetAttribute("CompassIconText", Options.CompassIconText)
		end
		if typeof(Options.CompassIconImage) == "string" then
			Target:SetAttribute("CompassIconImage", Options.CompassIconImage)
		end
		if typeof(Options.CompassMaxDistance) == "number" then
			Target:SetAttribute("CompassMaxDistance", Options.CompassMaxDistance)
		end
		if typeof(Options.WorldMaxDistance) == "number" then
			Target.MaxDistance = Options.WorldMaxDistance
		end
		if typeof(Options.WorldLabel) == "string" then
			Target.Info.Text = Options.WorldLabel
			Target.Info.Visible = true
		end
		if Options.WorldHideDistance == true then
			Target.Distance.Visible = false
		end
		if Options.WorldIconOnly == true then
			Target.Info.Visible = false
			Target.Distance.Visible = false
		end
	end

	Target.Parent = Parent
	Target.Enabled = not (typeof(Options) == "table" and Options.CompassOnly == true)

	table.insert(Targets, Target)
	TargetAdded:Fire(Target)
	return Target
end

function QuestTargetController:CreateTargetAtPosition(Title: string, Position: Vector3, Options)
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

	local Target = QuestTargetController:CreateTarget(Title, TargetPart, Options)

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
			TargetRemoved:Fire(Target)
			Target:Destroy()
			table.remove(Targets, index)

			if DestroyParent and Parent then
				Parent:Destroy()
			end
		end
	end
end

function QuestTargetController:GetTargets()
	return table.clone(Targets)
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
			TargetRemoved:Fire(Target)
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

	QuestService.CreateTargetBillboard:Connect(function(Title: string, Parent: Instance, Options)
		QuestTargetController:CreateTarget(Title, Parent, Options)
	end)
	QuestService.CreateTargetBillboardAtPosition:Connect(function(Title: string, Position: Vector3, Options)
		QuestTargetController:CreateTargetAtPosition(Title, Position, Options)
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
