local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BossController = Knit.CreateController({
	Name = "BossController",
})

local Player = Players.LocalPlayer
local BossUI: ScreenGui
local CutsceneUIController

local HealthBar: ImageLabel
local PostureBar: ImageLabel

local Detail: ImageLabel
local LifeTemplate: ImageLabel
local LifesContent: Frame

local CurrentBoss: Model?
local Collector = require(ReplicatedStorage.Shared.Collector)

local Connections = Collector.new()

local function GetBossInRange(): (Model?, number)
	local Bosses = CollectionService:GetTagged("Boss")
	local Distance = math.huge
	local ClosestBoss = nil
	for _, Instance in Bosses do
		if not Instance:IsA("Model") then
			continue
		end
		local Boss = Instance :: Model
		if Boss.Parent ~= workspace.Entity then
			continue
		end
		if Boss.PrimaryPart and Player.Character then
			local DistanceToBoss = (Boss.PrimaryPart.Position - Player.Character:GetPivot().Position).Magnitude
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

function BossController:UpdateHealth()
	if not CurrentBoss then
		return
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

function BossController:Hide()
	Connections:DisconnectAll()
	CurrentBoss = nil
	CutsceneUIController:SetGuiEnabled(BossUI, false)
end

function BossController:Bind(BossToBind: Model)
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
	CutsceneUIController:SetGuiEnabled(BossUI, true)
end

function BossController:CheckForBoss()
	local Character = Player.Character
	if not Character or Character:GetAttribute("IntroWakeUp") then
		self:Hide()
		return
	end

	local BossToBind = GetBossInRange()
	if BossToBind then
		self:Bind(BossToBind)
	else
		self:Hide()
	end
end

local function WatchCharacter(Character: Model)
	Character:GetAttributeChangedSignal("IntroWakeUp"):Connect(function()
		BossController:CheckForBoss()
	end)
	BossController:CheckForBoss()
end

function BossController.KnitInit()
	CutsceneUIController = Knit.GetController("CutsceneUIController")
end

function BossController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	local Hud = PlayerGui:WaitForChild("Hud")
	BossUI = Hud:WaitForChild("Boss") :: ScreenGui

	HealthBar = BossUI:WaitForChild("HealthBar") :: ImageLabel
	PostureBar = BossUI:WaitForChild("PostureBar") :: ImageLabel

	Detail = HealthBar:WaitForChild("Detail") :: ImageLabel
	LifeTemplate = Detail:WaitForChild("LifeTemplate") :: ImageLabel
	LifesContent = Detail:WaitForChild("Lifes") :: Frame

	Player.CharacterAdded:Connect(WatchCharacter)
	Player.CharacterRemoving:Connect(function()
		BossController:Hide()
	end)
	CollectionService:GetInstanceRemovedSignal("Boss"):Connect(function(Boss: Instance)
		if Boss == CurrentBoss then
			BossController:Hide()
		end
	end)
	if Player.Character then
		WatchCharacter(Player.Character)
	end

	local Elapsed = 0
	RunService.Heartbeat:Connect(function(DeltaTime: number)
		Elapsed += DeltaTime
		if Elapsed >= 1 then
			Elapsed = 0
			BossController:CheckForBoss()
		end
	end)
end

return BossController
