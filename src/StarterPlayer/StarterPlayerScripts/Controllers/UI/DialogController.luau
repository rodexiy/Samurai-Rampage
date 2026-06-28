local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local player = game.Players.LocalPlayer
local Mouse = player:GetMouse()
local AnswerDB = false
local clicked = false

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

local DEFAULT_ANSWER_TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local ANSWER_CHARS_PER_LINE = 42
local ANSWER_MIN_HEIGHT = 0.14
local ANSWER_LINE_HEIGHT = 0.055
local ANSWER_MAX_HEIGHT = 0.34

local function GetColor(Value, Fallback: Color3): Color3
	return if typeof(Value) == "Color3" then Value else Fallback
end

local function GetAnswerAccentColor(AnswerTable): Color3
	local ActionTypeColor = ActionTypes[AnswerTable.actionType] or ActionTypes.default
	return GetColor(AnswerTable.color or AnswerTable.accentColor, ActionTypeColor)
end

local function GetAnswerHeightScale(Text: string): number
	local LineCount = math.max(1, math.ceil(string.len(Text) / ANSWER_CHARS_PER_LINE))
	return math.clamp(ANSWER_MIN_HEIGHT + ((LineCount - 1) * ANSWER_LINE_HEIGHT), ANSWER_MIN_HEIGHT, ANSWER_MAX_HEIGHT)
end

local EasyVisuals = require(game.ReplicatedStorage.Assets.Libraries.EasyVisuals)
local Visuals = {}

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
	for _, v in AnswersContent:GetChildren() do
		if v:IsA("GuiButton") then
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
		local AnswerText = tostring(AnswerTable.text or "")
		local AccentColor = GetAnswerAccentColor(AnswerTable)
		local TextLabel = AnswerTemplate:FindFirstChild("TextLabel")
		local ActionType = AnswerTemplate:FindFirstChild("ActionType")

		AnswerTemplate.LayoutOrder = answerIndex
		AnswerTemplate.Size = UDim2.fromScale(1, GetAnswerHeightScale(AnswerText))

		if AnswerTable.buttonColor or AnswerTable.backgroundColor then
			local ButtonColor = GetColor(AnswerTable.buttonColor or AnswerTable.backgroundColor, AnswerTemplate.BackgroundColor3)
			AnswerTemplate.BackgroundColor3 = ButtonColor
			AnswerTemplate.BackgroundTransparency = math.min(AnswerTemplate.BackgroundTransparency, 0.15)

			if AnswerTemplate:IsA("ImageButton") then
				AnswerTemplate.ImageColor3 = ButtonColor
			end
		end

		local Stroke = AnswerTemplate:FindFirstChildWhichIsA("UIStroke")
		if Stroke then
			Stroke.Color = GetColor(AnswerTable.strokeColor, AccentColor)
		end

		if ActionType and (ActionType:IsA("ImageLabel") or ActionType:IsA("ImageButton")) then
			ActionType.ImageColor3 = AccentColor
		end

		if TextLabel and TextLabel:IsA("TextLabel") then
			TextLabel.Text = AnswerText
			TextLabel.TextColor3 = GetColor(AnswerTable.textColor, DEFAULT_ANSWER_TEXT_COLOR)
			TextLabel.TextScaled = false
			TextLabel.TextWrapped = true
			TextLabel.TextTruncate = Enum.TextTruncate.None
			TextLabel.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel.TextYAlignment = Enum.TextYAlignment.Center
			TextLabel.TextSize = math.max(TextLabel.TextSize, 16)
			TextLabel.LineHeight = 1.05

			if AnswerTable.visual then
				table.insert(Visuals, EasyVisuals.new(TextLabel, AnswerTable.visual, 0.3, 0.3))
			end
		end

		AnswerTemplate.Visible = true
		AnswerTemplate.Parent = AnswersContent

		local AnswerConnection
		AnswerConnection = AnswerTemplate.Activated:Connect(function(inputObject, clickCount)
			if AnswerDB then
				return
			end
			AnswerDB = true
			if AnswerConnection then
				AnswerConnection:Disconnect()
				AnswerConnection = nil
			end

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

	if AnswersContent:IsA("ScrollingFrame") then
		AnswersContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
		AnswersContent.CanvasSize = UDim2.fromScale(0, 0)
		AnswersContent.ScrollingDirection = Enum.ScrollingDirection.Y
		AnswersContent.ScrollBarThickness = 4
	end

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
