local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StatusDisplay = {}

local Collector = require(game.ReplicatedStorage.Shared.Collector)

function StatusDisplay:AddTopDisplay(Character: Model)
	local Connections = Collector.new()

	local TopDisplay: BillboardGui = game.ReplicatedStorage.Assets.Billboards.TopStatusDisplay:Clone()

	local Player = Players:GetPlayerFromCharacter(Character)

	TopDisplay.PlayerToHideFrom = Player
	TopDisplay.Parent = Character.PrimaryPart

	local Name = if Player then Player.DisplayName else Character.Name
	TopDisplay.EntityName.Text = Character:GetAttribute("DisplayName") or Name

	local Humanoid: Humanoid = Character:FindFirstChild("Humanoid")

	if Humanoid then
		Humanoid.NameOcclusion = Enum.NameOcclusion.OccludeAll
		Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	local function UpdateVisibility()
		local PostureValue = Character:GetAttribute("Posture")
		local HealthValue = Character:GetAttribute("Health")

		TopDisplay.PostureBackground.Visible = Character:GetAttribute("IsAI") and PostureValue > 0
		TopDisplay.HealthBackground.Visible = HealthValue < Character:GetAttribute("MaxHealth")
	end

	if not Character:HasTag("Boss") then
		local oldHealth = Character:GetAttribute("Health")
		Connections:Add(Character:GetAttributeChangedSignal("Health"):Connect(function()
			local HealthGui = TopDisplay.HealthBackground

			local health = math.clamp(Character:GetAttribute("Health") / Character:GetAttribute("MaxHealth"), 0, 1)

			local redTime = 0.25
			local whiteTime = 0.6
			local info = TweenInfo.new(redTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
			local whiteInfo = TweenInfo.new(whiteTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

			TweenService:Create(HealthGui.HealthBar, info, { Size = UDim2.fromScale(health, 1) }):Play()
			TweenService:Create(HealthGui.WhiteBar, whiteInfo, { Size = UDim2.fromScale(health, 1) }):Play()

			oldHealth = if Character:GetAttribute("Health") == 0 then 1 else Character:GetAttribute("Health")
			UpdateVisibility()
		end))

		local function UpdateNameVisibility()
			TopDisplay.EntityName.Visible = not Character:GetAttribute("HideName")
		end
		Connections:Add(Character:GetAttributeChangedSignal("HideName"):Connect(function()
			UpdateNameVisibility()
		end))

		UpdateNameVisibility()

		if Character:GetAttribute("IsAI") then
			Connections:Add(Character:GetAttributeChangedSignal("Posture"):Connect(function()
				local PostureGui = TopDisplay.PostureBackground

				local posture =
					math.clamp(Character:GetAttribute("Posture") / Character:GetAttribute("MaxPosture"), 0, 1)
				local info = TweenInfo.new(
					(Character:GetAttribute("Posture") / Character:GetAttribute("MaxPosture")) / 2,
					Enum.EasingStyle.Linear,
					Enum.EasingDirection.Out
				)
				TweenService:Create(PostureGui.PostureBar, info, { Size = UDim2.fromScale(posture, 1) }):Play()
				UpdateVisibility()
			end))
		end

		UpdateVisibility()
	else
		TopDisplay.HealthBackground.Visible = false
		TopDisplay.PostureBackground.Visible = false
		TopDisplay.EntityName.TextColor3 = Color3.fromRGB(250, 0, 0)
	end

	Connections:Add(Character.Destroying:Connect(function()
		Connections:Destroy()
	end))
	Connections:Add(TopDisplay.Destroying:Connect(function()
		Connections:Destroy()
	end))
end

function StatusDisplay:RemoveTopDisplay(Character: Model)
	if not Character or not Character.PrimaryPart then
		return
	end

	local TopDisplay = Character.PrimaryPart:FindFirstChild("TopStatusDisplay")
	if TopDisplay then
		TopDisplay:Destroy()
	end
end

function StatusDisplay:AddSideDisplay(Character: Model)
	local SideDisplay: BillboardGui = game.ReplicatedStorage.Assets.Billboards.SideStatusDisplay:Clone()
	local BottomDisplay: BillboardGui = game.ReplicatedStorage.Assets.Billboards.BottomStatusDisplay:Clone()
	BottomDisplay.Parent = Character.PrimaryPart
	SideDisplay.Parent = Character.PrimaryPart

	local function UpdateVisibility()
		if not RunService:IsClient() then
			return
		end

		local PostureValue = Character:GetAttribute("Posture")
		local HealthValue = Character:GetAttribute("Health")
		local StaminaValue = Character:GetAttribute("Stamina")

		BottomDisplay.PostureBackground.Visible = PostureValue > 0 and not Character:GetAttribute("Died")
		BottomDisplay.HealthBackground.Visible = HealthValue < Character:GetAttribute("MaxHealth")
			and not Character:GetAttribute("Died")
		SideDisplay.StaminaBackground.Visible = StaminaValue < Character:GetAttribute("MaxStamina")
			and not Character:GetAttribute("Died")
	end

	Character:GetAttributeChangedSignal("Health"):Connect(function()
		local HealthGui = BottomDisplay:WaitForChild("HealthBackground")

		local health = math.clamp(Character:GetAttribute("Health") / Character:GetAttribute("MaxHealth"), 0, 1)
		local info = TweenInfo.new(
			(Character:GetAttribute("Health") / Character:GetAttribute("MaxHealth")) / 2,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out
		)
		TweenService:Create(HealthGui.HealthBar, info, { Size = UDim2.fromScale(health, 1) }):Play()
		UpdateVisibility()
	end)
	Character:GetAttributeChangedSignal("Died"):Connect(function()
		UpdateVisibility()
	end)

	Character:GetAttributeChangedSignal("Stamina"):Connect(function()
		local HealthGui = SideDisplay:WaitForChild("StaminaBackground")

		local stamina = math.clamp(Character:GetAttribute("Stamina") / Character:GetAttribute("MaxStamina"), 0, 1)
		local info = TweenInfo.new(
			(Character:GetAttribute("Stamina") / Character:GetAttribute("MaxStamina")) / 2,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out
		)
		TweenService:Create(HealthGui.StaminaBar, info, { Size = UDim2.fromScale(stamina, 1) }):Play()
		UpdateVisibility()
	end)

	Character:GetAttributeChangedSignal("Posture"):Connect(function()
		local HealthGui = BottomDisplay:WaitForChild("PostureBackground")

		local posture = math.clamp(Character:GetAttribute("Posture") / Character:GetAttribute("MaxPosture"), 0, 1)
		local info = TweenInfo.new(
			(Character:GetAttribute("Posture") / Character:GetAttribute("MaxPosture")) / 2,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out
		)
		TweenService:Create(HealthGui.PostureBar, info, { Size = UDim2.fromScale(posture, 1) }):Play()
		UpdateVisibility()
	end)

	UpdateVisibility()
end

return StatusDisplay
