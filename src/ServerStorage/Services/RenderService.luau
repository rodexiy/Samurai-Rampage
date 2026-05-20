local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RenderService = Knit.CreateService({
	Name = "RenderService",
	Client = {
		Render = Knit.CreateSignal(),
	},
})

function RenderService:WeldConstraint(Part0: BasePart, Part1: BasePart)
	if Part0:IsA("Model") then
		Part0 = Part0.PrimaryPart or Part0:FindFirstChildWhichIsA("BasePart")
	end
	if Part1:IsA("Model") then
		Part1 = Part1.PrimaryPart or Part1:FindFirstChildWhichIsA("BasePart")
	end
	local Constraint = Instance.new("WeldConstraint")
	Constraint.Part0 = Part0
	Constraint.Part1 = Part1
	Constraint.Parent = Part1

	Part1.Anchored = false
	return Constraint
end

local function CreateRenderData(Module: string, Effect: string, Data: { any })
	local Data = Data or {}
	if typeof(Data) == "table" then
		if not Data.RootCFrame and Data.Attacker then
			Data.RootCFrame = Data.Attacker:GetPivot()
		end
		if not Data.RootCFrame and Data.Character then
			Data.RootCFrame = Data.Character:GetPivot()
		end
	end

	local RenderData = {
		Module = Module,
		Effect = Effect,
	}

	for key, value in Data do
		RenderData[key] = value
	end

	return RenderData
end

function RenderService:RenderForPlayer(Player: Player, Module: string, Effect: string, Data: { any })
	if Player:IsA("Model") then
		Player = Players:GetPlayerFromCharacter(Player)
	end

	if not Player then
		return
	end

	local Data = Data or {}
	if not Data.Character then
		Data.Character = Player.Character
	end
	RenderService.Client.Render:Fire(Player, CreateRenderData(Module, Effect, Data))
end

function RenderService:RenderForCharacter(Character: Model, Module: string, Effect: string, Data: { any })
	local Player = Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end
	RenderService.Client.Render:Fire(Player, CreateRenderData(Module, Effect, Data))
end

function RenderService:RenderForCharacters(Characters: { Model }, Module: string, Effect: string, Data: { any })
	for _, Character in Characters do
		RenderService:RenderForCharacter(Character, Module, Effect, Data)
	end
end

function RenderService:RenderForPlayers(Players: { Player }, Module: string, Effect: string, Data: { any })
	local Players = Players or game.Players:GetPlayers()
	for _, Player in Players do
		RenderService.Client.Render:Fire(Player, CreateRenderData(Module, Effect, Data))
	end
end

function RenderService:RenderForAllPlayers(Module: string, Effect: string, Data: { any })
	local RenderData = CreateRenderData(Module, Effect, Data)
	if not Data.Character then
		RenderData.Character = ReplicatedStorage.Assets.RenderHolder
	end
	RenderService.Client.Render:FireAll(RenderData)
end

function RenderService:Emit(particle)
	local function emitParticle()
		if particle:GetAttribute("EmitDuration") and particle:GetAttribute("EmitDuration") > 0 then
			particle.Enabled = true
			task.delay(particle:GetAttribute("EmitDuration"), function()
				particle.Enabled = false
			end)
		end

		particle:Emit(particle:GetAttribute("EmitCount"))
	end

	if particle:GetAttribute("EmitDelay") then
		task.delay(particle:GetAttribute("EmitDelay"), function()
			emitParticle()
		end)
	else
		emitParticle()
	end
end

function RenderService:StopParticles(parent)
	for _, Particle in parent:GetDescendants() do
		if Particle:IsA("ParticleEmitter") then
			Particle.Enabled = false
		end
	end
end

function RenderService:EmitParticles(parent)
	for i, v in ipairs(parent:GetDescendants()) do
		if not v:IsA("ParticleEmitter") then
			continue
		end

		RenderService:Emit(v)
	end
end

function RenderService.KnitInit()
	local VFXFolder = Instance.new("Folder")
	VFXFolder.Name = "VFX"
	VFXFolder.Parent = workspace
end

return RenderService
