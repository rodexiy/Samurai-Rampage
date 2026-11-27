local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ScreenParticleController = Knit.CreateController({ Name = "ScreenParticleController" })
local RenderController
local WhisperTemplate: Sound
local Player = Players.LocalPlayer
local ScreenParticles = ReplicatedStorage.Assets.VFX.Screen
local RENDER_BINDING = "ScreenParticleController"
local RenderBound = false
local Character: Model?
local BurnConnection: RBXScriptConnection?

type Entry = {
	Id: string,
	Particle: BasePart | Model,
	Offset: CFrame,
	Stopping: boolean,
	DurationTask: thread?,
	CleanupTask: thread?,
	Whisper: Sound?,
}
local Particles: { [string]: Entry } = {}

local function StopWhisper(Entry: Entry)
	if Entry.Whisper then
		Entry.Whisper:Destroy()
		Entry.Whisper = nil
	end
end

local function DestroyParticle(Entry: Entry, DestroyInstance: boolean)
	if Particles[Entry.Id] ~= Entry then
		return
	end

	Particles[Entry.Id] = nil
	StopWhisper(Entry)
	if Entry.DurationTask then
		task.cancel(Entry.DurationTask)
		Entry.DurationTask = nil
	end
	if Entry.CleanupTask then
		task.cancel(Entry.CleanupTask)
		Entry.CleanupTask = nil
	end

	if not next(Particles) and RenderBound then
		RunService:UnbindFromRenderStep(RENDER_BINDING)
		RenderBound = false
	end
	if DestroyInstance then
		Entry.Particle:Destroy()
	end
end

local function StopParticle(Entry: Entry)
	if Particles[Entry.Id] ~= Entry or Entry.Stopping then
		return
	end

	Entry.Stopping = true
	StopWhisper(Entry)
	if Entry.DurationTask then
		task.cancel(Entry.DurationTask)
		Entry.DurationTask = nil
	end

	local Lifetime = math.clamp(RenderController:StopParticles(Entry.Particle), 0, 5)
	Entry.CleanupTask = task.delay(Lifetime, function()
		Entry.CleanupTask = nil
		DestroyParticle(Entry, true)
	end)
end

local function Render()
	local Camera = workspace.CurrentCamera
	if not Camera then
		return
	end

	for _, Entry in Particles do
		Entry.Particle:PivotTo(Camera.CFrame * Entry.Offset)
	end
end

local function ConfigureParticle(Particle: BasePart | Model, Camera: Camera): CFrame
	local AspectRatio = Camera.ViewportSize.X / math.max(Camera.ViewportSize.Y, 1)
	local VerticalSize = 2 * math.tan(math.rad(Camera.FieldOfView) / 2)
	local HorizontalSize = VerticalSize * AspectRatio
	local SizeType = Particle:GetAttribute("SizeType")

	if SizeType == "Border" then
		local Borders = {
			Top = { Position = Vector3.new(0, VerticalSize / 2, -1), Size = Vector3.new(HorizontalSize, 0, 0) },
			Bottom = { Position = Vector3.new(0, -VerticalSize / 2, -1), Size = Vector3.new(HorizontalSize, 0, 0) },
			Left = { Position = Vector3.new(-HorizontalSize / 2, 0, -1), Size = Vector3.new(0, VerticalSize, 0) },
			Right = { Position = Vector3.new(HorizontalSize / 2, 0, -1), Size = Vector3.new(0, VerticalSize, 0) },
		}
		Particle:PivotTo(Camera.CFrame)
		for Name, Border in Borders do
			local Part = Particle:FindFirstChild(Name) :: BasePart?
			if Part then
				Part.Size = Border.Size
				Part.Position = Camera.CFrame:PointToWorldSpace(Border.Position) + (Part:GetAttribute("Offset") or Vector3.zero)
			end
		end

		return CFrame.identity
	end

	assert(Particle:IsA("BasePart"), "Screen particle must be a BasePart or a border Model")
	if SizeType == "FillScreen" then
		Particle.Size = Vector3.new(HorizontalSize, VerticalSize, 0.01)
		return CFrame.new(0, 0, -1)
	end

	Particle.Size = Vector3.new(HorizontalSize, 1, 0)
	return CFrame.new(0, -VerticalSize / 2, -1)
end

function ScreenParticleController:EmitParticle(ParticleName: string, Duration: number?): ((BasePart | Model)?, string?)
	local Camera = workspace.CurrentCamera
	if not Player:GetAttribute("ScreenParticles") or not Camera then
		return nil, nil
	end

	local Particle = ScreenParticles[ParticleName]:Clone() :: BasePart | Model
	if Particle:IsA("BasePart") then
		Particle.Anchored = true
	end
	for _, Part in Particle:QueryDescendants("BasePart") :: { BasePart } do
		Part.Anchored = true
	end

	local Entry: Entry = {
		Id = HttpService:GenerateGUID(false),
		Particle = Particle,
		Offset = ConfigureParticle(Particle, Camera),
		Stopping = false,
	}
	Particle:SetAttribute("Id", Entry.Id)
	Particles[Entry.Id] = Entry
	Particle.Destroying:Once(function()
		DestroyParticle(Entry, false)
	end)
	Particle:PivotTo(Camera.CFrame * Entry.Offset)
	Particle.Parent = workspace.VFX

	if Particle:GetAttribute("EmitType") == "Enabled" then
		for _, Emitter in Particle:QueryDescendants("ParticleEmitter") :: { ParticleEmitter } do
			Emitter.Enabled = true
		end
	else
		RenderController:EmitParticles(Particle)
	end

	if ParticleName == "Fear" then
		local Whisper = WhisperTemplate:Clone()
		Entry.Whisper = Whisper
		Whisper.Parent = SoundService
		Whisper:Play()
	end

	if not RenderBound then
		RenderBound = true
		RunService:BindToRenderStep(RENDER_BINDING, Enum.RenderPriority.Camera.Value + 6, Render)
	end
	if Duration then
		Entry.DurationTask = task.delay(Duration, function()
			Entry.DurationTask = nil
			StopParticle(Entry)
		end)
	end

	return Particle, Entry.Id
end

function ScreenParticleController:ClearAllParticles()
	for _, Entry in Particles do
		DestroyParticle(Entry, true)
	end
end

function ScreenParticleController:ClearParticleWithName(Name: string)
	for _, Entry in Particles do
		if Entry.Particle.Name == Name then
			StopParticle(Entry)
		end
	end
end

function ScreenParticleController:HasParticleWithName(Name: string): boolean
	for _, Entry in Particles do
		if not Entry.Stopping and Entry.Particle.Name == Name then
			return true
		end
	end

	return false
end

local function RefreshStatus(Name: string, Active: boolean)
	if Active then
		if not ScreenParticleController:HasParticleWithName(Name) then
			ScreenParticleController:EmitParticle(Name)
		end
	else
		ScreenParticleController:ClearParticleWithName(Name)
	end
end

local function RefreshCharacter()
	if not Character or Character ~= Player.Character then
		return
	end

	local Damage = Character:GetAttribute("BurnDamage")
	RefreshStatus("Burn", typeof(Damage) == "number" and Damage > 0)
	RefreshStatus("Electrified", CollectionService:HasTag(Character, "Electrified"))

	local Fear = Player:GetAttribute("Fear") or 0
	RefreshStatus("Fear", Fear >= 75)

	local Intensity = math.clamp((Fear - 75) / 25, 0, 1)
	local Rate = 0.1 + 0.9 * Intensity
	local Volume = 0.5 + 0.5 * Intensity
	for _, Entry in Particles do
		if Entry.Stopping or Entry.Particle.Name ~= "Fear" then
			continue
		end

		if Entry.Whisper then
			Entry.Whisper.Volume = Volume
		end

		for _, Emitter in Entry.Particle:QueryDescendants("ParticleEmitter") :: { ParticleEmitter } do
			if Emitter.Name == "Eyes" then
				Emitter.Rate = Rate
			elseif Emitter.Name == "Spark" or Emitter.Name == "Sparks" then
				Emitter.Rate = 15
			end
		end
	end
end

local function UnbindCharacter()
	if BurnConnection then
		BurnConnection:Disconnect()
		BurnConnection = nil
	end
	Character = nil
	ScreenParticleController:ClearAllParticles()
end

local function BindCharacter(NewCharacter: Model)
	UnbindCharacter()
	Character = NewCharacter
	BurnConnection = NewCharacter:GetAttributeChangedSignal("BurnDamage"):Connect(RefreshCharacter)
	RefreshCharacter()
end

function ScreenParticleController.KnitInit()
	RenderController = Knit.GetController("RenderController")

	WhisperTemplate = Instance.new("Sound")
	WhisperTemplate.Name = "FearWhisper"
	WhisperTemplate.SoundId = "rbxassetid://103019858973166"
	WhisperTemplate.Volume = 0.5
	WhisperTemplate.Looped = true
	WhisperTemplate.Parent = SoundService
end

function ScreenParticleController.KnitStart()
	Player:GetAttributeChangedSignal("Fear"):Connect(RefreshCharacter)
	Player.CharacterAdded:Connect(BindCharacter)
	Player.CharacterRemoving:Connect(function(OldCharacter: Model)
		if OldCharacter == Character then
			UnbindCharacter()
		end
	end)
	Player:GetAttributeChangedSignal("ScreenParticles"):Connect(function()
		if Player:GetAttribute("ScreenParticles") then
			RefreshCharacter()
		else
			ScreenParticleController:ClearAllParticles()
		end
	end)

	local function RefreshElectrified(Object: Instance)
		if Object == Character then
			RefreshCharacter()
		end
	end
	CollectionService:GetInstanceAddedSignal("Electrified"):Connect(RefreshElectrified)
	CollectionService:GetInstanceRemovedSignal("Electrified"):Connect(RefreshElectrified)

	if Player.Character then
		BindCharacter(Player.Character)
	end
end

return ScreenParticleController
