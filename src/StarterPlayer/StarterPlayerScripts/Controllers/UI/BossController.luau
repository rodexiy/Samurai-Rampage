local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local BossController = Knit.CreateController({
	Name = "BossController",
})

local Player = game.Players.LocalPlayer
local PlayerGui
local Hud
local BossUI

local HealthBar
local PostureBar

local Detail
local LifeTemplate
local LifesContent

local CurrentBoss: Model = nil
local Collector = require(game.ReplicatedStorage.Shared.Collector)

local Connections = Collector.new()

local function GetBossInRange()
	local Bosses = CollectionService:GetTagged("Boss")
	local Distance = math.huge
	local ClosestBoss = nil
	for _, Boss in Bosses do
		if Boss.Parent ~= workspace.Entity then
			continue
		end
		if Boss:FindFirstChild("HumanoidRootPart") then
			local DistanceToBoss = (Boss.HumanoidRootPart.Position - Player.Character:GetPivot().Position).Magnitude
			if DistanceToBoss > 100 then
				continue
			end

			if DistanceToBoss < Distance then
				Distance = DistanceToBoss
				ClosestBoss = Boss
			end
		end
	end

	return ClosestBoss, Distance
end

local oldHealth
function BossController:UpdateHealth()
	if not CurrentBoss then
		return
	end

	if not oldHealth then
		oldHealth = CurrentBoss:GetAttribute("Health")
	end

	local health = math.clamp(CurrentBoss:GetAttribute("Health") / CurrentBoss:GetAttribute("MaxHealth"), 0, 1)
	local redTime = 0.25
	local whiteTime = 0.6
	local info = TweenInfo.new(redTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local whiteInfo = TweenInfo.new(whiteTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	TweenService:Create(HealthBar.Bar, info, { Size = UDim2.fromScale(health, 1) }):Play()
	TweenService:Create(HealthBar.WhiteBar, whiteInfo, { Size = UDim2.fromScale(health, 1) }):Play()
end
function BossController:UpdatePosture()
	if not CurrentBoss then
		return
	end

	local posture = math.clamp(CurrentBoss:GetAttribute("Posture") / CurrentBoss:GetAttribute("MaxPosture"), 0, 1)
	local info = TweenInfo.new(
		(CurrentBoss:GetAttribute("Posture") / CurrentBoss:GetAttribute("MaxPosture")) / 2,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)
	TweenService:Create(PostureBar.Bar, info, { Size = UDim2.fromScale(posture, 1) }):Play()
end

function BossController:UpdateLifes()
	if not CurrentBoss then
		return
	end

	for _, Life in LifesContent:GetChildren() do
		if Life:IsA("ImageLabel") then
			Life:Destroy()
		end
	end

	for i = 1, CurrentBoss:GetAttribute("TotalLifes") or 1 do
		local Life: ImageLabel = LifeTemplate:Clone()
		Life.Parent = LifesContent
		Life.Visible = true

		if i > CurrentBoss:GetAttribute("Lifes") then
			Life.ImageColor3 = Color3.fromRGB(90, 90, 90)
		end
	end
end

function BossController:Bind(BossToBind)
	if BossToBind == CurrentBoss then
		return
	end

	Connections:DisconnectAll()

	CurrentBoss = BossToBind
	Connections:Add(CurrentBoss:GetAttributeChangedSignal("Health"):Connect(function()
		BossController:UpdateHealth()
	end))

	Connections:Add(CurrentBoss:GetAttributeChangedSignal("Posture"):Connect(function()
		BossController:UpdatePosture()
	end))

	Connections:Add(CurrentBoss:GetAttributeChangedSignal("Lifes"):Connect(function()
		BossController:UpdateLifes()
	end))

	Detail.BossName.Text = CurrentBoss:GetAttribute("DisplayName") or CurrentBoss.Name
	BossController:UpdateHealth()
	BossController:UpdatePosture()
	BossController:UpdateLifes()
	BossUI.Enabled = true
end

function BossController:CheckForBoss()
	while true do
		task.wait(1)

		if not Player.Character then
			continue
		end

		local BossToBind = GetBossInRange()

		if not BossToBind then
			oldHealth = nil
			Connections:DisconnectAll()
			BossUI.Enabled = false
			CurrentBoss = nil
			continue
		end

		if not BossToBind then
			continue
		end

		BossController:Bind(BossToBind)
	end
end

function BossController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Hud = PlayerGui:WaitForChild("Hud")
	BossUI = Hud:WaitForChild("Boss")

	HealthBar = BossUI:WaitForChild("HealthBar")
	PostureBar = BossUI:WaitForChild("PostureBar")

	Detail = HealthBar:WaitForChild("Detail")
	LifeTemplate = Detail:WaitForChild("LifeTemplate")
	LifesContent = Detail:WaitForChild("Lifes")

	BossController:CheckForBoss()
end

return BossController
