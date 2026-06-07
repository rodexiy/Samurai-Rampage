local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local AlertController = Knit.CreateController({
	Name = "AlertController",
})

export type AlertOptions = {
	Color: Color3?,
	Duration: number?,
	ShowProgress: boolean?,
	Title: string?,
}

local Player = game.Players.LocalPlayer
local Alerts
local AlertTemplate
local AlertService

local MAX_VISIBLE_ALERTS = 5
local DEFAULT_DURATION = 4
local MESSAGE_WIDTH = 330

local ENTER_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local EXIT_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HIDDEN_POSITION = UDim2.fromScale(2, 0)
local VISIBLE_POSITION = UDim2.fromScale(0, 0)

local TypeStyles = {
	Default = {
		Color = Color3.fromRGB(191, 199, 214),
		Title = "NOTICE",
	},
	Info = {
		Color = Color3.fromRGB(102, 170, 255),
		Title = "INFO",
	},
	Success = {
		Color = Color3.fromRGB(92, 204, 137),
		Title = "SUCCESS",
	},
	Warn = {
		Color = Color3.fromRGB(241, 181, 73),
		Title = "WARNING",
	},
	Error = {
		Color = Color3.fromRGB(235, 91, 91),
		Title = "ERROR",
	},
}

local ActiveAlerts = {}
local NextLayoutOrder = 0

local function GetMessageHeight(MessageLabel: TextLabel, Message: string)
	local Params = Instance.new("GetTextBoundsParams")
	Params.Font = MessageLabel.FontFace
	Params.RichText = MessageLabel.RichText
	Params.Size = MessageLabel.TextSize
	Params.Text = Message
	Params.Width = MESSAGE_WIDTH

	local Success, Bounds = pcall(function()
		return TextService:GetTextBoundsAsync(Params)
	end)
	Params:Destroy()

	return if Success then math.max(MessageLabel.TextSize, Bounds.Y) else MessageLabel.TextSize
end

local function RemoveActiveAlert(AlertData)
	local Index = table.find(ActiveAlerts, AlertData)
	if Index then
		table.remove(ActiveAlerts, Index)
	end
end

local function Dismiss(AlertData)
	if AlertData.Dismissed then
		return
	end

	AlertData.Dismissed = true
	RemoveActiveAlert(AlertData)

	local Card = AlertData.Root.Card
	TweenService:Create(Card, EXIT_TWEEN, {
		Position = HIDDEN_POSITION,
	}):Play()
	task.delay(EXIT_TWEEN.Time, function()
		AlertData.Root:Destroy()
	end)
end

function AlertController:Alert(Message: string, MessageType: string?, Options: AlertOptions?)
	local Style = TypeStyles[MessageType or "Default"] or TypeStyles.Default
	local Color = Options and Options.Color or Style.Color
	local Duration = math.clamp(Options and Options.Duration or DEFAULT_DURATION, 1, 15)
	local Title = Options and Options.Title or Style.Title

	NextLayoutOrder += 1
	local Root = AlertTemplate:Clone()
	Root.Name = "Alert"
	Root.LayoutOrder = NextLayoutOrder

	local Card = Root.Card
	Card.Content.Title.Text = Title
	Card.Content.Title.TextColor3 = Color
	Card.Content.Message.Text = Message
	Card.Content.Message.AutomaticSize = Enum.AutomaticSize.None
	Card.Content.Message.Size = UDim2.new(1, 0, 0, GetMessageHeight(Card.Content.Message, Message))
	Card.Position = HIDDEN_POSITION

	Root.Visible = true
	Root.Parent = Alerts.content

	local AlertData = {
		Dismissed = false,
		Root = Root,
	}
	table.insert(ActiveAlerts, AlertData)

	if #ActiveAlerts > MAX_VISIBLE_ALERTS then
		Dismiss(ActiveAlerts[1])
	end

	TweenService:Create(Card, ENTER_TWEEN, {
		Position = VISIBLE_POSITION,
	}):Play()

	task.delay(Duration, function()
		Dismiss(AlertData)
	end)
end

function AlertController.KnitInit()
	AlertService = Knit.GetService("AlertService")
end

function AlertController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Hud = PlayerGui:WaitForChild("Hud")
	Alerts = Hud:WaitForChild("Alerts")
	AlertTemplate = Alerts:WaitForChild("Template")

	Alerts:WaitForChild("content")
	AlertTemplate:WaitForChild("Card")

	AlertService.Alerted:Connect(function(Message, MessageType, Options)
		AlertController:Alert(Message, MessageType, Options)
	end)
end

return AlertController
