local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ScreenParticleController = Knit.CreateController({
	Name = "ScreenParticleController",
})
local RenderController

local Particles = {}

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local ScreenParticles = game.ReplicatedStorage.Assets.VFX.Screen
function ScreenParticleController:EmitParticle(ParticleName: string, Duration: number)
	if not Player:GetAttribute("ScreenParticles") then
		return
	end
	local Particle = ScreenParticles[ParticleName]:Clone()
	for _, Part in Particle:GetChildren() do
		if Part:IsA("BasePart") then
			Part.Anchored = true
		end
	end

	local Offset = CFrame.new(0, 0, 0)

	local ViewportSize = Camera.ViewportSize
	local AspectRatio = ViewportSize.X / ViewportSize.Y
	local FOV = math.rad(75)

	-- Distance from camera to projection plane
	local Distance = 1 -- Arbitrary distance for calculations

	-- Vertical and Horizontal size at the given distance
	local VerticalSize = 2 * Distance * math.tan(FOV / 2)
	local HorizontalSize = VerticalSize * AspectRatio

	-- Camera's CFrame
	local CameraCFrame = Camera.CFrame
	local CameraPosition = CameraCFrame.Position
	local CameraLookVector = CameraCFrame.LookVector

	-- Calculate edges based on camera direction
	local Center = CameraPosition + CameraLookVector * Distance

	local RightVector = CameraCFrame.RightVector
	local UpVector = CameraCFrame.UpVector

	local Top = Center + UpVector * (VerticalSize / 2)
	local Bottom = Center - UpVector * (VerticalSize / 2)
	local Left = Center - RightVector * (HorizontalSize / 2)
	local Right = Center + RightVector * (HorizontalSize / 2)

	local CenterOffset = CFrame.new(0, 0, -Distance)
	local TopOffset = CFrame.new(0, VerticalSize / 2, -Distance)
	local BottomOffset = CFrame.new(0, -VerticalSize / 2, -Distance)
	local LeftOffset = CFrame.new(-HorizontalSize / 2, 0, -Distance)
	local RightOffset = CFrame.new(HorizontalSize / 2, 0, -Distance)

	if Particle:GetAttribute("SizeType") == "FillScreen" then
		Particle.Size = Vector3.new(HorizontalSize, VerticalSize, 0)
	elseif Particle:GetAttribute("SizeType") == "Border" then
		local TopPart = Particle:FindFirstChild("Top")
		local BottomPart = Particle:FindFirstChild("Bottom")
		local LeftPart = Particle:FindFirstChild("Left")
		local RightPart = Particle:FindFirstChild("Right")
		TopPart.Size = Vector3.new(HorizontalSize, 0, 0)
		BottomPart.Size = Vector3.new(HorizontalSize, 0, 0)
		LeftPart.Size = Vector3.new(0, VerticalSize, 0)
		RightPart.Size = Vector3.new(0, VerticalSize, 0)

		Particle:PivotTo(Camera.CFrame)

		TopPart.Position = Top + (TopPart:GetAttribute("Offset") or Vector3.new(0, 0, 0))
		BottomPart.Position = Bottom + (BottomPart:GetAttribute("Offset") or Vector3.new(0, 0, 0))
		LeftPart.Position = Left + (LeftPart:GetAttribute("Offset") or Vector3.new(0, 0, 0))
		RightPart.Position = Right + (RightPart:GetAttribute("Offset") or Vector3.new(0, 0, 0))
	else
		Particle.Size = Vector3.new(HorizontalSize, 1, 0)
		Offset = BottomOffset
	end

	local guid = HttpService:GenerateGUID(false)
	Particle:SetAttribute("Id", guid)
	Particles[guid] = Particle
	RunService:BindToRenderStep(guid, Enum.RenderPriority.Camera.Value + 6, function(dt)
		Particle:PivotTo(Camera.CFrame * Offset)
	end)

	if Particle:GetAttribute("EmitType") == "Enabled" then
		for _, Child: ParticleEmitter in Particle:GetDescendants() do
			if Child:IsA("ParticleEmitter") then
				Child.Enabled = true
			end
		end
	else
		RenderController:EmitParticles(Particle)
	end

	Particle.Parent = game.Workspace.VFX

	if Duration then
		task.delay(Duration, function()
			RenderController:StopParticles(Particle)
			task.wait(0.5)
			RunService:UnbindFromRenderStep(guid)
			Particle:Destroy()
			Particles[guid] = nil
		end)
	end

	return Particle, guid
end

function ScreenParticleController:ClearAllParticles()
	for _, Particle in Particles do
		RenderController:StopParticles(Particle)
		task.wait(0.5)
		RunService:UnbindFromRenderStep(Particle:GetAttribute("Id"))
		Particle:Destroy()
	end

	table.clear(Particles)
end

function ScreenParticleController:ClearParticleWithName(Name: string)
	for _, Particle in Particles do
		if Particle.Name == Name then
			task.spawn(function()
				local LongestLifeTime = RenderController:StopParticles(Particle)
				LongestLifeTime = math.min(LongestLifeTime, 5)
				task.wait(LongestLifeTime)
				RunService:UnbindFromRenderStep(Particle:GetAttribute("Id"))
				Particle:Destroy()
				Particles[_] = nil
			end)
		end
	end
end

function ScreenParticleController:HasParticleWithName(Name: string)
	for _, Particle in Particles do
		if Particle.Name == Name then
			return true
		end
	end
end

function ScreenParticleController.KnitInit()
	RenderController = Knit.GetController("RenderController")
end

function ScreenParticleController.KnitStart()
	local function BindCharacter(character: Model)
		ScreenParticleController:ClearAllParticles()
		character:GetAttributeChangedSignal("BurnDamage"):Connect(function()
			if character:GetAttribute("BurnDamage") ~= 0 then
				if ScreenParticleController:HasParticleWithName("Burn") then
					return
				end
				ScreenParticleController:EmitParticle("Burn")
			else
				ScreenParticleController:ClearParticleWithName("Burn")
			end
		end)

		CollectionService:GetInstanceAddedSignal("Electrified"):Connect(function(Character)
			if Character == character then
				ScreenParticleController:EmitParticle("Electrified")
			end
		end)

		CollectionService:GetInstanceRemovedSignal("Electrified"):Connect(function(Character)
			if Character == character then
				ScreenParticleController:ClearParticleWithName("Electrified")
			end
		end)
	end
	Player.CharacterAdded:Connect(function(character)
		BindCharacter(character)
	end)
	if Player.Character then
		BindCharacter(Player.Character)
	end
end

return ScreenParticleController
