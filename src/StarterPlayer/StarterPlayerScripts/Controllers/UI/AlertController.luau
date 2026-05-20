local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local AlertController = Knit.CreateController({
	Name = "AlertController",
})

local Player = game.Players.LocalPlayer
local PlayerGui
local Hud
local Alerts
local AlertPlaceholder

local AlertService

local TypeColors = {
	Default = Color3.fromRGB(243, 243, 243),
	Success = Color3.fromRGB(126, 255, 126),
	Warn = Color3.fromRGB(240, 204, 0),
	Error = Color3.fromRGB(240, 0, 0),
}

local EasyVisuals = require(game.ReplicatedStorage.Assets.Libraries.EasyVisuals)

local Info = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local InfoOut = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
function AlertController:Alert(Message: string, MessageType: string)
	task.spawn(function()
		local MessageType = MessageType or "Default"
		local Alert: TextLabel = AlertPlaceholder:Clone()
		Alert.Title.Text = Message
		Alert.Title.MaxVisibleGraphemes = 0

		Alert.Title.TextColor3 = TypeColors[MessageType]
		Alert.Parent = Alerts
		Alert.Visible = true
		Alert.Parent = Alerts.content
		local Visual

		TweenService:Create(Alert.Title, Info, { Position = UDim2.fromScale(0, 0) }):Play()

		Alert.Title.UIStroke.Color = Color3.fromRGB(25, 25, 25):Lerp(TypeColors[MessageType], 0.45)

		Visual = EasyVisuals.new(
			Alert.Title,
			"Shine",
			2,
			1,
			false,
			Color3.fromRGB(50, 50, 50):Lerp(TypeColors[MessageType], 0.75)
		)

		for i = 0, string.len(Message) do
			Alert.Title.MaxVisibleGraphemes = i
			task.wait()
		end
		local lenght = string.len(Message)
		task.wait(math.max(2, lenght * 0.075))

		TweenService:Create(Alert.Title, InfoOut, { Position = UDim2.fromScale(0, 100) }):Play()

		task.wait(0.55)
		Visual:Destroy()
		Alert:Destroy()
	end)
end

function AlertController.KnitInit()
	AlertService = Knit.GetService("AlertService")
end

function AlertController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Hud = PlayerGui:WaitForChild("Hud")
	Alerts = Hud:WaitForChild("Alerts")
	AlertPlaceholder = Alerts:WaitForChild("Template")

	AlertService.Alerted:Connect(function(Message, MessageType)
		AlertController:Alert(Message, MessageType)
	end)
end

return AlertController
