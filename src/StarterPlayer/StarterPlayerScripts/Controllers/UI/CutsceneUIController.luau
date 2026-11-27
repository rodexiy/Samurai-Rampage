local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CutsceneUIController = Knit.CreateController({ Name = "CutsceneUIController" })

local Player = Players.LocalPlayer
local Gui: ScreenGui?
local Fade: Frame?
local Dialogue: TextLabel?
local Speaker: TextLabel?
local FadeTween: Tween?
local RevealTween: Tween?
local HiddenGuis: { [ScreenGui]: boolean } = {}
local VisibilityConnections: { RBXScriptConnection } = {}
local SavedBars: { [GuiObject]: boolean } = {}
local BarSizes: { [GuiObject]: UDim2 } = {}
local BarTweens: { [GuiObject]: Tween } = {}

local function GetGui(): ScreenGui
	if Gui and Gui.Parent then
		return Gui
	end

	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	Gui = PlayerGui:FindFirstChild("Cutscene") :: ScreenGui?
	if not Gui then
		Gui = (StarterGui:WaitForChild("Cutscene") :: ScreenGui):Clone()
		Gui.Parent = PlayerGui
	end
	Gui.ResetOnSpawn = false
	Gui.DisplayOrder = 200
	Gui.IgnoreGuiInset = true
	local Bottom = Gui:WaitForChild("Bottom") :: Frame
	Dialogue = Bottom:WaitForChild("TextLabel") :: TextLabel
	Speaker = Bottom:WaitForChild("TalkerName") :: TextLabel

	Fade = Instance.new("Frame")
	Fade.Name = "IntroFade"
	Fade.Size = UDim2.fromScale(1, 1)
	Fade.BackgroundColor3 = Color3.new(0, 0, 0)
	Fade.BorderSizePixel = 0
	Fade.ZIndex = 100
	Fade.BackgroundTransparency = 1
	Fade.Parent = Gui
	return Gui
end

function CutsceneUIController:SetGuiEnabled(Screen: ScreenGui, Enabled: boolean)
	if HiddenGuis[Screen] ~= nil then
		HiddenGuis[Screen] = Enabled
		Screen.Enabled = false
	else
		Screen.Enabled = Enabled
	end
end

function CutsceneUIController:Prepare(Blackout: boolean?)
	local CutsceneGui = GetGui()
	local PlayerGui = Player:FindFirstChildWhichIsA("PlayerGui")
	if PlayerGui then
		for _, Instance in PlayerGui:QueryDescendants("ScreenGui") do
			local Screen = Instance :: ScreenGui
			if Screen ~= CutsceneGui and HiddenGuis[Screen] == nil then
				HiddenGuis[Screen] = Screen.Enabled
				Screen.Enabled = false
				table.insert(
					VisibilityConnections,
					Screen:GetPropertyChangedSignal("Enabled"):Connect(function()
						if Screen.Enabled then
							HiddenGuis[Screen] = true
							Screen.Enabled = false
						end
					end)
				)
			end
		end
	end

	if FadeTween then
		FadeTween:Cancel()
	end
	CutsceneGui.Enabled = true
	for _, Name in { "Top", "Bottom" } do
		local Bar = CutsceneGui:FindFirstChild(Name) :: GuiObject?
		if Bar then
			if SavedBars[Bar] == nil then
				SavedBars[Bar] = Bar.Visible
			end
			Bar.Visible = true
		end
	end

	assert(Fade, "Cutscene fade overlay is missing").BackgroundTransparency = if Blackout == false then 1 else 0
	self:ClearDialogue()
end

function CutsceneUIController:FadeIn(Duration: number): boolean
	local Overlay = assert(Fade, "Cutscene fade overlay is missing")
	FadeTween = TweenService:Create(Overlay, TweenInfo.new(Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	FadeTween:Play()
	return FadeTween.Completed:Wait() == Enum.PlaybackState.Completed
end

function CutsceneUIController:FadeOut(Duration: number): boolean
	local Overlay = assert(Fade, "Cutscene fade overlay is missing")
	if FadeTween then
		FadeTween:Cancel()
	end

	if Duration <= 0 then
		Overlay.BackgroundTransparency = 0
		return true
	end

	FadeTween = TweenService:Create(Overlay, TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 0,
	})
	FadeTween:Play()
	return FadeTween.Completed:Wait() == Enum.PlaybackState.Completed
end

function CutsceneUIController:Say(Name: string, Text: string, Duration: number)
	if RevealTween then
		RevealTween:Cancel()
	end
	local Label = assert(Dialogue, "Cutscene dialogue label is missing")
	assert(Speaker, "Cutscene speaker label is missing").Text = Name
	Label.Text = Text
	Label.MaxVisibleGraphemes = 0
	RevealTween =
		TweenService:Create(Label, TweenInfo.new(math.min(#Text / 38, Duration * 0.65), Enum.EasingStyle.Linear), {
			MaxVisibleGraphemes = #Text,
		})
	RevealTween:Play()
end

function CutsceneUIController:ClearDialogue()
	if RevealTween then
		RevealTween:Cancel()
	end
	if Dialogue then
		Dialogue.Text = ""
	end
	if Speaker then
		Speaker.Text = ""
	end
end

function CutsceneUIController:ShowInstruction(Title: string, Message: string)
	self:Finish()
	local CutsceneGui = GetGui()
	CutsceneGui.Enabled = true
	assert(Fade, "Cutscene overlay is missing").BackgroundTransparency = 1

	for _, Name in { "Top", "Bottom" } do
		local Bar = CutsceneGui:FindFirstChild(Name) :: GuiObject?
		if Bar then
			SavedBars[Bar] = Bar.Visible
			Bar.Visible = true
		end
	end

	local Label = assert(Dialogue, "Cutscene dialogue is missing")
	Label.Text = Message
	Label.MaxVisibleGraphemes = -1
	assert(Speaker, "Cutscene speaker is missing").Text = Title
end

function CutsceneUIController:SetBarHeight(Height: number, Duration: number)
	local CutsceneGui = GetGui()
	for _, Name in { "Top", "Bottom" } do
		local Bar = CutsceneGui:FindFirstChild(Name) :: GuiObject?
		if not Bar then
			continue
		end

		BarSizes[Bar] = BarSizes[Bar] or Bar.Size
		if BarTweens[Bar] then
			BarTweens[Bar]:Cancel()
		end
		local Size = UDim2.new(Bar.Size.X.Scale, Bar.Size.X.Offset, math.clamp(Height, 0, 0.45), 0)
		if Duration <= 0 then
			Bar.Size = Size
		else
			local Tween = TweenService:Create(Bar, TweenInfo.new(Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = Size })
			BarTweens[Bar] = Tween
			Tween:Play()
		end
	end
end

function CutsceneUIController:Finish()
	for _, Tween in BarTweens do
		Tween:Cancel()
	end
	table.clear(BarTweens)
	for Bar, Size in BarSizes do
		if Bar.Parent then
			Bar.Size = Size
		end
	end
	table.clear(BarSizes)

	for Bar, Visible in SavedBars do
		if Bar.Parent then
			Bar.Visible = Visible
		end
	end
	table.clear(SavedBars)
	if FadeTween then
		FadeTween:Cancel()
	end
	self:ClearDialogue()
	if Gui then
		Gui.Enabled = false
	end

	for _, Connection in VisibilityConnections do
		Connection:Disconnect()
	end
	table.clear(VisibilityConnections)

	for Screen, Enabled in HiddenGuis do
		if Screen.Parent then
			Screen.Enabled = Enabled
		end
	end
	table.clear(HiddenGuis)
end

return CutsceneUIController
