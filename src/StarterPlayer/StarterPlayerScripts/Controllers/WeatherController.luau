local Knit = require(game.ReplicatedStorage.Packages.Knit)

local WeatherController = Knit.CreateController({
	Name = "WeatherController",
})

local RenderController

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local currentHumidity
local currentWeather

local Camera = workspace.CurrentCamera

local Effect

local CharactersToAdd = game.Players:GetPlayers()
local BreathEffects = {}

function WeatherController:RemoveBreathEffect(character)
	if BreathEffects[character] then
		BreathEffects[character]:Destroy()
		BreathEffects[character] = nil
	end
end

function WeatherController:AddBreathEffect(Character)
	if BreathEffects[Character] or workspace:GetAttribute("Season") ~= "Winter" then
		return
	end
	local Effect = game.ReplicatedStorage.Assets.VFX.Weather.Breath:Clone()
	BreathEffects[Character] = Effect

	local Head = Character:WaitForChild("Head", 5)
	if not Head then
		return
	end
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = Head

	Weld.Part1 = Effect.PrimaryPart
	Weld.Parent = Effect
	Effect:PivotTo(Character:WaitForChild("Head"):GetPivot())
	Effect.Parent = Character

	task.spawn(function()
		while Effect do
			task.wait(math.random(250, 600) / 100)

			if Effect then
				RenderController:EmitParticles(Effect)
			end
		end
	end)
end

function BindPlayer(player)
	player.CharacterAdded:Connect(function(character)
		character:GetAttributeChangedSignal("Died"):Connect(function()
			if character:GetAttribute("Died") then
				WeatherController:RemoveBreathEffect(character)
			end
		end)

		table.insert(CharactersToAdd, player)
		WeatherController:AddBreathEffect(character)
	end)
end

game.Players.PlayerAdded:Connect(function(player)
	BindPlayer(player)
end)

for _, player in game.Players:GetPlayers() do
	BindPlayer(player)
end

game.Players.PlayerRemoving:Connect(function(player)
	WeatherController:RemoveBreathEffect(player.Character)
	CharactersToAdd[player] = nil
end)

function WeatherController:AddWinterEffect()
	for _, player in CharactersToAdd do
		local character = player.Character
		if character then
			WeatherController:AddBreathEffect(character)
		end
	end

	local NPCs = workspace:FindFirstChild("NPCs")
	if NPCs then
		for _, NPC in NPCs:GetChildren() do
			WeatherController:AddBreathEffect(NPC)
		end
	end
end

function WeatherController:RemoveWinterEffect()
	for Index, BreathEffect in BreathEffects do
		BreathEffect:Destroy()
		BreathEffects[Index] = nil
	end

	local NPCs = workspace:FindFirstChild("NPCs")
	if NPCs then
		for _, NPC in NPCs:GetChildren() do
			WeatherController:RemoveBreathEffect(NPC)
		end
	end
end

workspace:GetAttributeChangedSignal("Season"):Connect(function()
	if workspace:GetAttribute("Season") == "Winter" then
		WeatherController:AddWinterEffect()
	else
		WeatherController:RemoveWinterEffect()
	end
end)

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
		Effect = game.ReplicatedStorage.Assets.VFX.Weather.Snow:Clone()
	else
		Effect = game.ReplicatedStorage.Assets.VFX.Weather.Rain:Clone()
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
	task.spawn(function()
		local counter = Workspace.DistributedGameTime + workspace:GetAttribute("WeatherRandomFactor")
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
