local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RenderController = Knit.CreateController({
	Name = "RenderController",
})

local RenderService
local Player = game.Players.LocalPlayer

--[[
    Executa a parte do client referente as particulas e skills, da emit nas particulas, cria as parts, move as parts, etc
]]

local RenderingModules = {}

function RenderController:CheckCache(module, key)
	if not module.Cache then
		module.Cache = {}
	end

	if not module.Cache[key] then
		module.Cache[key] = {
			Instances = {},
			Connections = {},
			Tasks = {},
			NamedTasks = {},
		}
	end
end

function RenderController:CreateInstance(module, key, newInstance)
	RenderController:CheckCache(module, key)

	table.insert(module.Cache[key].Instances, newInstance)
	return newInstance
end

function RenderController:GetInstance(module, key, name)
	RenderController:CheckCache(module, key)
	for i, v in ipairs(module.Cache[key].Instances) do
		if v.Name == name then
			return v, i
		end
	end
end

function RenderController:RemoveInstance(module, key, index)
	RenderController:CheckCache(module, key)
	table.remove(module.Cache[key].Instances, index)
end

function RenderController:DestroyInstance(module, key, index)
	RenderController:CheckCache(module, key)

	local instance, index = self:GetInstance(module, key, index)
	if instance then
		instance:Destroy()
		self:RemoveInstance(module, key, index)
	end
end

function RenderController:CreateConnection(module, key, connection)
	RenderController:CheckCache(module, key)

	table.insert(module.Cache[key].Connections, connection)
end

function RenderController:CreateTask(module, key, callback)
	RenderController:CheckCache(module, key)
	local index = #module.Cache[key].Tasks
	table.insert(module.Cache[key].Tasks, index, task.spawn(callback))
	return module.Cache[key].Tasks[index]
end

function RenderController:CreateNamedTask(module, key, name, callback)
	RenderController:CheckCache(module, key)

	module.Cache[key].NamedTasks[name] = task.spawn(callback)
	return module.Cache[key].NamedTasks[name]
end

function RenderController:ClearConnections(module, key)
	task.spawn(function()
		if module.Cache and module.Cache[key] then
			for i, v in ipairs(module.Cache[key].Connections) do
				v:Disconnect()
				module.Cache[key].Connections[i] = nil
			end
		end
	end)
end

function RenderController:ClearTasks(module, key)
	task.spawn(function()
		if module.Cache and module.Cache[key] then
			for i, v: thread in ipairs(module.Cache[key].Tasks) do
				task.cancel(v)
				module.Cache[key].Tasks[i] = nil
			end
		end
	end)
end

function RenderController:CancelNamedTask(module, key, name)
	if module.Cache and module.Cache[key] then
		if module.Cache[key].NamedTasks[name] then
			task.cancel(module.Cache[key].NamedTasks[name])
		end
	end
end

function RenderController:ClearNamedTasks(module, key)
	task.spawn(function()
		if module.Cache and module.Cache[key] then
			for i, v: thread in pairs(module.Cache[key].NamedTasks) do
				task.cancel(v)
				module.Cache[key].NamedTasks[i] = nil
			end
		end
	end)
end

function RenderController:ClearInstances(module, key)
	task.spawn(function()
		if module.Cache and module.Cache[key] then
			for i, v in ipairs(module.Cache[key].Instances) do
				v:Destroy()
				module.Cache[key].Instances[i] = nil
			end
		end
	end)
end

function RenderController:ClearCacheOfCharacter(module: string, key: Model)
	RenderController:ClearTasks(module, key)
	RenderController:ClearConnections(module, key)
	RenderController:ClearInstances(module, key)
end

function RenderController:IsCacheEmpty(module: string, key: Model)
	if module.Cache and module.Cache[key] then
		return #module.Cache[key].Instances == 0
			and #module.Cache[key].Connections == 0
			and #module.Cache[key].Tasks == 0
			and #module.Cache[key].NamedTasks == 0
	end
end

function RenderController:Emit(particle)
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

function RenderController:StopParticles(parent)
	local LongestParticleLifeTime = 0
	for _, Particle: ParticleEmitter in parent:GetDescendants() do
		if Particle:IsA("ParticleEmitter") then
			if Particle.Lifetime.Max > LongestParticleLifeTime then
				LongestParticleLifeTime = Particle.Lifetime.Max
			end
			Particle.Enabled = false
		elseif Particle:IsA("Trail") or Particle:IsA("Beam") then
			Particle.Enabled = false
		end
	end
	return LongestParticleLifeTime
end

function RenderController:GetPartsWithParent(Model: Model)
	local Parts = {}
	for i, v in ipairs(Model:GetDescendants()) do
		if v:IsA("BasePart") then
			table.insert(Parts, v)
		end
	end

	if Model:IsA("BasePart") then
		table.insert(Parts, Model)
	end
	return Parts
end

function RenderController:EmitParticles(parent)
	for i, v in ipairs(parent:GetDescendants()) do
		if not v:IsA("ParticleEmitter") then
			continue
		end

		RenderController:Emit(v)
	end
end

function RenderController:ExecuteForCharacter(CharacterToRender, callback)
	local Character = Player.Character

	if not Character then
		return
	end

	if CharacterToRender == Character then
		callback()
	end
end

function RenderController.Render(RenderData)
	local ModuleToRender = RenderData.Module
	local Character = RenderData.Character

	if not Character then
		if not RenderController:IsCacheEmpty(ModuleToRender, Character) then
			RenderController:ClearCacheOfCharacter(ModuleToRender, Character)
		end
		return
	end

	local RenderingModule = RenderingModules[ModuleToRender]
	if RenderingModule then
		if RenderingModule.Caller then
			task.spawn(function()
				RenderingModule.Caller(RenderData)
			end)
		else
			if RenderingModule[RenderData.Effect] then
				task.spawn(function()
					RenderingModule[RenderData.Effect](RenderData)
				end)
			else
				print("Effect not found!")
			end
		end
	else
		print("Module not found!")
	end
end

function RenderController:RenderParticles(Module: string, Effect: string, Data: { any })
	local RenderData = {
		Module = Module,
		Effect = Effect,
	}

	for i, v in Data do
		RenderData[i] = v
	end

	RenderController.Render(RenderData)
end

function RenderController:WeldConstraint(Part0: BasePart, Part1: BasePart)
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

function RenderController:TweenModelScale(model: Model, targetScale: number, info: TweenInfo)
	local scaleController = Instance.new("NumberValue")
	scaleController.Value = model:GetScale()
	scaleController.Parent = model

	scaleController.Changed:Connect(function(newScale)
		model:ScaleTo(newScale)
	end)

	TweenService:Create(scaleController, info, { Value = targetScale }):Play()

	task.delay(info.Time + 0.1, function()
		if scaleController and scaleController.Parent then
			scaleController:Destroy()
		end
	end)
end
function RenderController:RenderSteppedWeldConstraint(Part0: BasePart | Model, Part1: BasePart | Model)
	if Part0:IsA("Model") then
		Part0 = Part0.PrimaryPart or Part0:FindFirstChildWhichIsA("BasePart")
	end
	if Part1:IsA("Model") then
		Part1 = Part1.PrimaryPart or Part1:FindFirstChildWhichIsA("BasePart")
	end

	if not Part0 or not Part1 then
		return
	end

	Part1.Anchored = true

	local Offset = Part0.CFrame:ToObjectSpace(Part1.CFrame)
	local Connections = {}

	local function Cleanup()
		for _, Conn in ipairs(Connections) do
			if Conn.Connected then
				Conn:Disconnect()
			end
		end
		table.clear(Connections)
	end

	table.insert(
		Connections,
		RunService.RenderStepped:Connect(function()
			if not Part0.Parent or not Part1.Parent then
				Cleanup()
				return
			end
			Part1.CFrame = Part0.CFrame * Offset
		end)
	)

	table.insert(Connections, Part0.Destroying:Connect(Cleanup))
	table.insert(Connections, Part1.Destroying:Connect(Cleanup))

	return Cleanup
end

local function CreateRenderData(Module: string, Effect: string, Data: { any })
	local Data = Data or {}
	if typeof(Data) == "table" then
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

function RenderController:BindRenderingTags()
	local tags = {
		"Burn",
		"Confetti",
		"Electrified",
	}

	for _, tag in tags do
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(Character)
			local RenderData = CreateRenderData("Tags", "Remove_" .. tag, { Character = Character })
			RenderController.Render(RenderData)
		end)
	end

	for _, tag in tags do
		for _, Character in CollectionService:GetTagged(tag) do
			local RenderData = CreateRenderData("Tags", tag, { Character = Character })
			RenderController.Render(RenderData)
		end
	end

	for _, tag in tags do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(Character)
			local RenderData = CreateRenderData("Tags", tag, { Character = Character })
			RenderController.Render(RenderData)
		end)
	end
end

function RenderController.KnitInit()
	RenderService = Knit.GetService("RenderService")
end

function RenderController.KnitStart()
	for _, v in ipairs(script:GetDescendants()) do
		if v:IsA("ModuleScript") then
			RenderingModules[v.Name] = require(v)
		end
	end

	for i, v in pairs(RenderingModules) do
		if v.Start then
			v.Start()
		end
	end

	RenderService.Render:Connect(RenderController.Render)

	RenderController:BindRenderingTags()
end

return RenderController
