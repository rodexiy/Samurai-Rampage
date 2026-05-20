local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DialogService = Knit.CreateService({
	Name = "DialogService",
	Client = {
		StartDialogEvent = Knit.CreateSignal(),
		CloseDialogEvent = Knit.CreateSignal(),
	},
})

local DialogData = {}

local Dialogs = {}

local DeepCopy = require(game.ReplicatedStorage.Shared.Utils.DeepCopy)

function DialogService:GetDialogTree(player, npc: string)
	local DialogTreeIndex
	local HighestPriority = 0
	for i, v in Dialogs[npc] do
		if HighestPriority <= (v.priority or 0) then
			if v.validation then
				if not v.validation(player) then
					continue
				end
				DialogTreeIndex = i
				HighestPriority = v.priority or 0
			else
				DialogTreeIndex = i
				HighestPriority = v.priority or 0
			end
		end
	end

	return DialogTreeIndex
end

function DialogService:ClearBranch(branch: {})
	for i, answer in branch.answers do
		if type(answer.nextDialog) == "function" then
			answer.nextDialog = "function"
		end
	end

	return branch
end

function DialogService:StartDialog(player, npc: string)
	if DialogData[player] and DialogData[player].npc ~= "" then
		return
	end

	local dialogTrees = Dialogs[npc]

	if not DialogData[player] then
		DialogData[player] = {}
	end

	if not dialogTrees then
		return
	end
	local dialogTreeIndex = DialogService:GetDialogTree(player, npc)
	local DialogTree = dialogTrees[dialogTreeIndex]

	DialogData[player].npc = npc
	DialogData[player].DialogTreeIndex = dialogTreeIndex
	DialogData[player].DialogBody = 1

	local newDialogTree = DeepCopy(DialogTree[1])

	if newDialogTree.customText then
		newDialogTree.npcText = newDialogTree.customText(player)
	end

	for i, answer in newDialogTree.answers do
		if answer.customText then
			answer.text = answer.customText(player)
		end

		if not answer.nextDialog and not answer.actionType then
			answer.actionType = "end"
		end

		if not answer.validateAnswer then
			continue
		end

		if not answer.validateAnswer(player) then
			newDialogTree.answers[i] = nil
		end
	end

	DialogData.answers = newDialogTree.answers

	local ClearDialogTree = DialogService:ClearBranch(newDialogTree)
	ClearDialogTree.NPC = npc

	DialogService.Client.StartDialogEvent:Fire(player, ClearDialogTree)
	return ClearDialogTree
end

function DialogService:LeaveDialog(Player)
	local PlayerDialogData = DialogData[Player]
	if not PlayerDialogData then
		return
	end

	PlayerDialogData.npc = ""
	PlayerDialogData.DialogTreeIndex = 0
	PlayerDialogData.DialogBody = 0
end
function DialogService.Client:LeaveDialog(Player: Player)
	self.Server:LeaveDialog(Player)
end
function DialogService:Answer(player, answerIndex)
	local PlayerDialogData
	local DialogTree
	local DialogBody
	local Character = player.Character

	-- rever
	local successful, erro = pcall(function()
		PlayerDialogData = DialogData[player]
		DialogTree = Dialogs[PlayerDialogData.npc][PlayerDialogData.DialogTreeIndex]
		DialogBody = DialogTree[PlayerDialogData.DialogBody]
	end)

	if erro then
		return
	end

	local AnswerSelected = DialogBody.answers[answerIndex]

	if not AnswerSelected then
		return
	end

	if AnswerSelected.callback then
		AnswerSelected.callback(player)
	end

	local NextDialogNumber = AnswerSelected.nextDialog

	if AnswerSelected.nextDialog and type(AnswerSelected.nextDialog) == "number" then
		PlayerDialogData.DialogBody = AnswerSelected.nextDialog
	elseif AnswerSelected.nextDialog and type(AnswerSelected.nextDialog) == "function" then
		NextDialogNumber = AnswerSelected.nextDialog(player)
		PlayerDialogData.DialogBody = NextDialogNumber
	else
		PlayerDialogData.npc = ""
		PlayerDialogData.DialogTreeIndex = 0
		PlayerDialogData.DialogBody = 0
		return "EndDialog"
	end

	local nextDialog = DialogTree[NextDialogNumber]

	if not nextDialog then
		PlayerDialogData.npc = ""
		PlayerDialogData.DialogTreeIndex = 0
		PlayerDialogData.DialogBody = 0
		return "EndDialog"
	end

	local newDialogTree = DeepCopy(nextDialog)

	if newDialogTree.customText then
		newDialogTree.npcText = newDialogTree.customText(player)
	end

	for i, answer in newDialogTree.answers do
		if answer.customText then
			answer.text = answer.customText(player)
		end

		if not answer.nextDialog and not answer.actionType then
			answer.actionType = "end"
		end

		if not answer.validateAnswer then
			continue
		end

		if not answer.validateAnswer(player) then
			table.remove(newDialogTree.answers, i)
		end
	end

	DialogData.answers = newDialogTree.answers

	local ClearDialogTree = DialogService:ClearBranch(newDialogTree)

	return ClearDialogTree
end

function DialogService.Client:Answer(player, answerSelected)
	return self.Server:Answer(player, answerSelected)
end

function DialogService.Client:StartDialog(player, npc)
	return self.Server:StartDialog(player, npc)
end

function DialogService.KnitInit() end

function DialogService.KnitStart()
	for _, v in script.Dialogs:GetDescendants() do
		if v:IsA("ModuleScript") then
			Dialogs[v.Name] = require(v)
		end
	end
end

return DialogService
