local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local WeatherController = Knit.CreateController({
	Name = "WeatherController",
})

local RenderController

local currentHumidity
local currentWeather

local Camera = workspace.CurrentCamera

local Effect

local BREATH_CHECK_INTERVAL = 0.25
local BREATH_RENDER_DISTANCE = 150

type BreathData = {
	Effect: Model,
	NextEmission: number,
}

local BreathEffects: { [Model]: BreathData } = {}
local BreathConnection: RBXScriptConnection? = nil

local function stopBreathSchedulerIfEmpty()
	if next(BreathEffects) == nil and BreathConnection then
		BreathConnection:Disconnect()
		BreathConnection = nil
	end
end

function WeatherController:RemoveBreathEffect(Character: Model?)
	if not Character then
		return
	end

	local Data = BreathEffects[Character]
	if Data then
		BreathEffects[Character] = nil
		Data.Effect:Destroy()
	end

	stopBreathSchedulerIfEmpty()
end

local function updateBreathEffects()
	local Now = os.clock()
	local CurrentCamera = workspace.CurrentCamera

	for Character, Data in BreathEffects do
		if not Data.Effect:IsDescendantOf(workspace) or Character:GetAttribute("Died") then
			WeatherController:RemoveBreathEffect(Character)
			continue
		end

		if Now < Data.NextEmission then
			continue
		end

		Data.NextEmission = Now + math.random(250, 600) / 100
		local Head = Data.Effect.PrimaryPart
		if CurrentCamera and Head then
			local Offset = Head.Position - CurrentCamera.CFrame.Position
			if Offset:Dot(Offset) <= BREATH_RENDER_DISTANCE * BREATH_RENDER_DISTANCE then
				RenderController:EmitParticles(Data.Effect)
			end
		end
	end
end

local function startBreathScheduler()
	if BreathConnection then
		return
	end

	local Elapsed = 0
	BreathConnection = RunService.Heartbeat:Connect(function(DeltaTime: number)
		Elapsed += DeltaTime
		if Elapsed < BREATH_CHECK_INTERVAL then
			return
		end

		Elapsed %= BREATH_CHECK_INTERVAL
		updateBreathEffects()
	end)
end

function WeatherController:AddBreathEffect(Character: Model)
	local Existing = BreathEffects[Character]
	if Existing then
		if Existing.Effect:IsDescendantOf(Character) then
			return
		end

		WeatherController:RemoveBreathEffect(Character)
	end

	if workspace:GetAttribute("Season") ~= "Winter" then
		return
	end

	local Head = Character:WaitForChild("Head", 5) :: BasePart?
	if not Head or not Head:IsA("BasePart") or not Character:IsDescendantOf(workspace) then
		return
	end

	-- Waiting for the head can overlap another request, a death, or a season change.
	if BreathEffects[Character] or Character:GetAttribute("Died") or workspace:GetAttribute("Season") ~= "Winter" then
		return
	end

	local BreathEffect = ReplicatedStorage.Assets.VFX.Weather.Breath:Clone() :: Model
	if not BreathEffect.PrimaryPart then
		BreathEffect:Destroy()
		return
	end

	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = Head
	Weld.Part1 = BreathEffect.PrimaryPart
	Weld.Parent = BreathEffect

	BreathEffect:PivotTo(Head.CFrame)
	BreathEffect.Parent = Character
	BreathEffects[Character] = {
		Effect = BreathEffect,
		NextEmission = os.clock() + math.random(250, 600) / 100,
	}

	BreathEffect.Destroying:Connect(function()
		local Data = BreathEffects[Character]
		if Data and Data.Effect == BreathEffect then
			BreathEffects[Character] = nil
			stopBreathSchedulerIfEmpty()
		end
	end)

	startBreathScheduler()
end

local function bindCharacter(Character: Model)
	Character:GetAttributeChangedSignal("Died"):Connect(function()
		if Character:GetAttribute("Died") then
			WeatherController:RemoveBreathEffect(Character)
		end
	end)

	WeatherController:AddBreathEffect(Character)
end

local function bindPlayer(Player: Player)
	Player.CharacterAdded:Connect(bindCharacter)
	Player.CharacterRemoving:Connect(function(Character: Model)
		WeatherController:RemoveBreathEffect(Character)
	end)

	if Player.Character then
		task.spawn(bindCharacter, Player.Character)
	end
end

function WeatherController:AddWinterEffect()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			task.spawn(function()
				WeatherController:AddBreathEffect(character)
			end)
		end
	end

	local NPCs = workspace:FindFirstChild("NPCs")
	if NPCs then
		for _, NPC in NPCs:GetChildren() do
			if NPC:IsA("Model") then
				task.spawn(function()
					WeatherController:AddBreathEffect(NPC)
				end)
			end
		end
	end
end

function WeatherController:RemoveWinterEffect()
	for Character in BreathEffects do
		WeatherController:RemoveBreathEffect(Character)
	end
end

local function bindClear()
	if currentWeather == "Clear" then
		return
	end

	currentWeather = "Clear"

	if Effect then
		Effect:Destroy()
	end
	RunService:UnbindFromRenderStep("RainEffect")
end

local function bindEffect()
	if currentWeather == "Rain" then
		return
	end

	if Effect then
		Effect:Destroy()
	end

	if workspace:GetAttribute("Season") == "Winter" then
		Effect = ReplicatedStorage.Assets.VFX.Weather.Snow:Clone()
	else
		Effect = ReplicatedStorage.Assets.VFX.Weather.Rain:Clone()
	end

	for _, v in Effect:GetDescendants() do
		if v:IsA("BasePart") then
			v.Anchored = true
		end
	end

	Effect.Parent = workspace
	RunService:UnbindFromRenderStep("RainEffect")
	RunService:BindToRenderStep("RainEffect", Enum.RenderPriority.Camera.Value + 1, function()
		if
			(Effect.Name == "Rain" and workspace:GetAttribute("Season") == "Winter")
			or (Effect.Name == "Snow" and workspace:GetAttribute("Season") ~= "Winter")
		then
			bindClear()
			WeatherController:UpdateWeather()
			return
		end

		Effect:PivotTo(CFrame.new(Camera.CFrame.Position))
		if Effect.Name == "Rain" then
			local ray = workspace:Raycast(Camera.CFrame.Position, Vector3.new(0, -100, 0))
			if ray then
				Effect.Bottom:PivotTo(CFrame.new(ray.Position))
			end
		end
	end)
end

local Cloud: Clouds = workspace.Terrain.Clouds
local CoverTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function WeatherController:UpdateWeather()
	if workspace:GetAttribute("InMainMenu") then
		return
	end

	currentHumidity = workspace:GetAttribute("ClientHumidity") or workspace:GetAttribute("Humidity")

	if currentHumidity > 0.8 then
		bindEffect()
		workspace:SetAttribute("Weather", "Rain")
	else
		bindClear()
		workspace:SetAttribute("Weather", "Clear")
	end

	TweenService:Create(Cloud, CoverTweenInfo, { Cover = currentHumidity }):Play()

	currentWeather = workspace:GetAttribute("Weather")
end

function WeatherController.KnitInit()
	RenderController = Knit.GetController("RenderController")
end

function WeatherController.KnitStart()
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(Player: Player)
		WeatherController:RemoveBreathEffect(Player.Character)
	end)

	for _, Player in Players:GetPlayers() do
		bindPlayer(Player)
	end

	workspace:GetAttributeChangedSignal("Season"):Connect(function()
		if workspace:GetAttribute("Season") == "Winter" then
			WeatherController:AddWinterEffect()
		else
			WeatherController:RemoveWinterEffect()
		end
	end)

	task.spawn(function()
		local counter = workspace.DistributedGameTime + workspace:GetAttribute("WeatherRandomFactor")
		while true do
			counter += 0.01
			local noise = math.noise(counter, 0, 0) * 1.5
			workspace:SetAttribute("Humidity", math.abs(noise))

			task.wait(5)
		end
	end)

	workspace:GetAttributeChangedSignal("Humidity"):Connect(function()
		WeatherController:UpdateWeather()
	end)
	workspace:GetAttributeChangedSignal("ClientHumidity"):Connect(function()
		WeatherController:UpdateWeather()
	end)

	if workspace:GetAttribute("Season") == "Winter" then
		WeatherController:AddWinterEffect()
	end
end

return WeatherController
