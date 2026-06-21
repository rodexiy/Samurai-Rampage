local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer
local Mouse = player:GetMouse()
local AnswerDB = false

local MouseClickConnection = {}
local InDialog = false

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DialogController = Knit.CreateController({
	Name = "DialogController",
})

local DialogService
local HotbarController

local Player = game.Players.LocalPlayer
local PlayerGui
local Menu
local DialogueUI
local Content
local DialogContent
local DialogBox
local AnswersContent
local NPCNameTextArea
local NPC

local OldAnimationTrack
local TalkingAnimations = game.ReplicatedStorage.Assets.Animations.Misc.Talk:GetChildren()

local WaitTimes = {
	[","] = 0.1,
	["."] = 0.25,
	["-"] = 0.1,
}

local ActionTypes = {
	["default"] = Color3.fromRGB(255, 255, 255),
	["deny"] = Color3.fromRGB(255, 41, 41),
	["quest"] = Color3.fromRGB(255, 204, 1),
	["agree"] = Color3.fromRGB(148, 255, 66),
	["end"] = Color3.fromRGB(255, 41, 41),
}

local function IsMouseInBounds(uiElement)
	local mousePos = UserInputService:GetMouseLocation()
	-- Adjust for the top bar since IgnoreGuiInset is false
	mousePos = Vector2.new(mousePos.X, mousePos.Y - 36)

	local absPos = uiElement.AbsolutePosition
	local absSize = uiElement.AbsoluteSize

	return mousePos.X >= absPos.X
		and mousePos.X <= absPos.X + absSize.X
		and mousePos.Y >= absPos.Y
		and mousePos.Y <= absPos.Y + absSize.Y
end

local EasyVisuals = require(game.ReplicatedStorage.Assets.Libraries.EasyVisuals)
local Visuals = {}

local Collector = require(game.ReplicatedStorage.Shared.Collector)
local RunServiceConnetions = Collector.new()

local TypeWriterSounds = {
	"rbxassetid://9120299506",
	"rbxassetid://9120299407",
	"rbxassetid://9120300060",
	"rbxassetid://9120299839",
	"rbxassetid://9120299839",
}

local NPCPrompt

local function TypeWriterEffect(textToChange: TextLabel, text)
	for _, v in MouseClickConnection do
		v:Disconnect()
	end

	local cnn
	cnn = Mouse.Button1Down:Once(function()
		if cnn then
			cnn:Disconnect()
		end
		clicked = true
	end)

	if not text then
		return
	end

	local length = string.len(text)
	textToChange.MaxVisibleGraphemes = 0
	textToChange.Text = text
	for i = 0, length do
		if clicked then
			clicked = false
			textToChange.MaxVisibleGraphemes = length
			break
		end

		textToChange.MaxVisibleGraphemes = i
		task.wait(WaitTimes[text[i]] or 0.005)
	end

	if cnn then
		cnn:Disconnect()
		cnn = nil
	end
end

function UnloadAnswers()
	RunServiceConnetions:DisconnectAll()
	for _, v in AnswersContent:GetChildren() do
		if v:IsA("ImageButton") then
			v:Destroy()
		end
	end
end

function EndDialog(client)
	InDialog = false
	player:SetAttribute("InDialog", false)
	HotbarController:SetDialogHidden(false)

	local Character = player.Character
	local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart then
		HumanoidRootPart.Anchored = false
	end

	UnloadAnswers()
	DialogueUI.Enabled = false

	if NPCPrompt then
		NPCPrompt.Enabled = true
	end
	NPCPrompt = nil

	for _, Visual in Visuals do
		Visual:Destroy()
		Visuals[_] = nil
	end

	DialogBox.Text = ""
	NPCNameTextArea.Text = ""
	if client then
		DialogService:LeaveDialog()
	end

	if OldAnimationTrack then
		OldAnimationTrack:Stop()
		OldAnimationTrack = nil
	end
end

function BindAndLoadAnswers(DialogBody)
	NPCNameTextArea.Text = DialogBody.npcName or "forgot to add a name :/"
	UnloadAnswers()

	if NPCPrompt then
		local Character = player.Character
		if Character then
			local Animator = Character:FindFirstChild("Humanoid") and Character.Humanoid:FindFirstChild("Animator")
			if Animator then
				if OldAnimationTrack then
					OldAnimationTrack:Stop()
					OldAnimationTrack = nil
				end

				OldAnimationTrack = Animator:LoadAnimation(TalkingAnimations[math.random(1, #TalkingAnimations)])
				OldAnimationTrack:Play()
			end
		end
	end

	TypeWriterEffect(DialogBox, DialogBody.npcText)
	for answerIndex, AnswerTable in DialogBody.answers do
		local AnswerTemplate = DialogueUI.AnswerTemplate:Clone() :: TextButton

		if AnswerTable.visual then
			table.insert(Visuals, EasyVisuals.new(AnswerTemplate.TextLabel, AnswerTable.visual, 0.3, 0.3))
		end

		local IsSmallerText = string.len(AnswerTable.text) > 25
		local SmallerText = AnswerTable.text
		if IsSmallerText then
			SmallerText = string.sub(AnswerTable.text, 1, 23) .. "..."
		end

		AnswerTemplate.ActionType.ImageColor3 = ActionTypes[AnswerTable.actionType] or ActionTypes["default"]
		AnswerTemplate.TextLabel.Text = SmallerText
		AnswerTemplate.Visible = true
		AnswerTemplate.Parent = AnswersContent

		local DefaultSizeY = 0.3
		local DefaultSize = UDim2.fromScale(0.5, DefaultSizeY)

		if IsSmallerText then
			local TextLabel = AnswerTemplate.TextLabel
			RunServiceConnetions:Add(RunService.RenderStepped:Connect(function()
				if IsMouseInBounds(AnswerTemplate) then
					TextLabel.Text = AnswerTable.text
					TextLabel.TextXAlignment = Enum.TextXAlignment.Left
					TextLabel.TextYAlignment = Enum.TextYAlignment.Top
					AnswerTemplate.Size = UDim2.fromScale(
						1,
						DefaultSizeY + ((math.max(1, (string.len(AnswerTable.text) / 50)) * 0.25) - 0.25)
					)
				else
					AnswerTemplate.Size = DefaultSize
					TextLabel.Text = SmallerText
					TextLabel.TextXAlignment = Enum.TextXAlignment.Center
					TextLabel.TextYAlignment = Enum.TextYAlignment.Center
				end
			end))
		end

		AnswerTemplate.Activated:Once(function(inputObject, clickCount)
			if AnswerDB then
				return
			end
			AnswerDB = true
			task.delay(0.05, function()
				AnswerDB = false
			end)

			if AnswerTable.nextDialog then
				local newDialogBody = DialogService:Answer(answerIndex)

				if newDialogBody then
					BindAndLoadAnswers(newDialogBody)
				end
			else
				EndDialog()
				DialogService:Answer(answerIndex)
			end
		end)
	end
end

function DialogController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Menu = PlayerGui:WaitForChild("Menu")
	DialogueUI = Menu:WaitForChild("Dialog")
	Content = DialogueUI:WaitForChild("content")
	DialogContent = Content:WaitForChild("DialogContent")
	DialogBox = DialogContent:WaitForChild("DialogArea")
	AnswersContent = Content:WaitForChild("Answers")
	NPCNameTextArea = Content:WaitForChild("NPCHolder"):WaitForChild("TextLabel")

	DialogService = Knit.GetService("DialogService")
	HotbarController = Knit.GetController("HotbarController")

	DialogService.CloseDialogEvent:Connect(function()
		EndDialog()
	end)

	DialogueUI:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not DialogueUI.Enabled then
			EndDialog()
		end
	end)

	DialogService.StartDialogEvent:Connect(function(DialogBody)
		if InDialog then
			return
		end

		InDialog = true
		player:SetAttribute("InDialog", true)
		HotbarController:SetDialogHidden(true)
		DialogueUI.Enabled = true

		task.spawn(function()
			if not workspace:FindFirstChild("NPCs") then
				return
			end
			NPC = workspace.NPCs:FindFirstChild(DialogBody.NPC)

			if not NPC then
				for _, v in CollectionService:GetTagged("NPCs") do
					local ProximityPrompt = v:FindFirstChildWhichIsA("ProximityPrompt")
					if
						v.Name == DialogBody.NPC
						or (ProximityPrompt and ProximityPrompt:GetAttribute("NPC") == DialogBody.NPC)
					then
						NPC = v
						break
					end
				end
			end

			if NPC then
				NPCPrompt = NPC:FindFirstChildWhichIsA("ProximityPrompt")
				if NPCPrompt then
					NPCPrompt.Enabled = false
				end
				while InDialog do
					if not player.Character then
						EndDialog()
						break
					end
					local Distance = (NPC:GetPivot().Position - player.Character:GetPivot().Position).Magnitude

					if Distance > 12 then
						EndDialog(true)
						break
					end
					task.wait()
				end
			end
		end)

		BindAndLoadAnswers(DialogBody)
	end)
end

return DialogController
