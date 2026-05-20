local TweenService = game:GetService("TweenService")
local NumberIndicator = {}

local IndicationTemplates = game.ReplicatedStorage.Assets.Indications

function NumberIndicator:Indicate(Text: string, Parent: Instance, Type: string, Duration: number?)
	if not Type or not Text or not Parent then
		return
	end

	Duration = Duration or 1

	local Indicator: BillboardGui = IndicationTemplates[Type]:Clone()
	Indicator.Amount.Text = Text
	Indicator.Parent = Parent:IsA("Model") and Parent.PrimaryPart or Parent

	Indicator.Size = UDim2.fromScale(Text:len(), 1)
	Indicator.StudsOffset = Vector3.new(math.random(-10, 10) / 10, -5 / 10, 1.5)

	TweenService:Create(
		Indicator,
		TweenInfo.new(Duration / 2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ StudsOffset = Indicator.StudsOffset + Vector3.new(0, (math.random(-10, 10) / 10), 0) }
	):Play()

	task.delay(Duration, function()
		TweenService:Create(
			Indicator,
			TweenInfo.new(Duration / 4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ StudsOffsetWorldSpace = Vector3.new(0, -4, 0) }
		):Play()

		TweenService:Create(
			Indicator.Amount,
			TweenInfo.new(Duration / 4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ TextTransparency = 1 }
		):Play()

		TweenService:Create(
			Indicator.Amount.UIStroke,
			TweenInfo.new(Duration / 4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ Transparency = 1 }
		):Play()

		task.delay(Duration / 4, function()
			Indicator:Destroy()
		end)
	end)
end

function NumberIndicator:Countdown(InitialValue: number, Parent: Instance, Type: string)
	if not Type or not InitialValue or not Parent then
		return
	end

	local Amount = InitialValue

	local Indicator: BillboardGui = IndicationTemplates[Type]:Clone()
	Indicator.Amount.Text = InitialValue
	Indicator.Parent = Parent:IsA("Model") and Parent.PrimaryPart or Parent

	while Amount > 0 do
		task.wait(1)
		Amount -= 1
		Indicator.Amount.Text = Amount
	end

	Indicator:Destroy()
end

return NumberIndicator
