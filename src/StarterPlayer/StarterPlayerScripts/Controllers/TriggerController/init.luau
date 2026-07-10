local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TriggerController = Knit.CreateController({
	Name = "TriggerController",
})

local ZonePlus = require(game.ReplicatedStorage.Assets.Libraries.Zone)
local CompletedTriggers = {}
local TriggerZones = {}
local RunningTriggers = {}
local TriggerFolder
local TriggerService

local CompletedTriggersFetched = false
local FETCH_RETRY_TIME = 1

local function DestroyTriggerZone(TriggerName: string)
	if TriggerZones[TriggerName] then
		TriggerZones[TriggerName]:Destroy()
		TriggerZones[TriggerName] = nil
	end
end

local function MarkTriggerCompleted(TriggerName: string)
	CompletedTriggers[TriggerName] = true
	RunningTriggers[TriggerName] = nil
	DestroyTriggerZone(TriggerName)
end

local function GetModuleTriggerName(Trigger: Instance, Module): string
	if typeof(Module) == "table" and typeof(Module.TriggerName) == "string" and Module.TriggerName ~= "" then
		return Module.TriggerName
	end

	return Trigger.Name
end

local function PrepareTriggerPart(InstanceToPrepare: Instance)
	if not InstanceToPrepare:IsA("BasePart") then
		return
	end

	InstanceToPrepare.Transparency = 1
	InstanceToPrepare.CanCollide = false
	InstanceToPrepare.Anchored = true
end

function TriggerController:IsCompleted(TriggerName: string): boolean
	return CompletedTriggers[TriggerName] == true
end

function TriggerController:TriggerCompleted(TriggerName: string, ShouldSave: boolean?)
	if CompletedTriggers[TriggerName] then
		return true
	end

	if ShouldSave == false then
		MarkTriggerCompleted(TriggerName)
		return true
	end

	local Success, Result = pcall(function()
		return TriggerService:CompleteTrigger(TriggerName)
	end)

	if not Success then
		warn(Result)
		return false
	end

	if Result == true then
		MarkTriggerCompleted(TriggerName)
	end

	return Result == true
end

function TriggerController:SetCompletedTriggers(Triggers)
	table.clear(CompletedTriggers)
	CompletedTriggersFetched = true

	if typeof(Triggers) == "table" then
		for _, TriggerName in Triggers do
			if typeof(TriggerName) == "string" then
				MarkTriggerCompleted(TriggerName)
			end
		end
	end

	if TriggerFolder then
		self:LoadTriggers()
	end
end

function TriggerController:FetchCompletedTriggers(): boolean
	local Success, Result = pcall(function()
		return TriggerService:GetCompletedTriggers()
	end)

	if not Success then
		warn(`[TriggerController] Failed to fetch completed triggers: {Result}`)
		return false
	end

	self:SetCompletedTriggers(Result)
	return true
end

function TriggerController:LoadTrigger(Trigger: Instance)
	local ModuleScript = script:FindFirstChild(Trigger.Name)
	if not ModuleScript or not ModuleScript:IsA("ModuleScript") then
		warn(`[TriggerController] Missing trigger module for {Trigger.Name}.`)
		return
	end

	local Module = require(ModuleScript)
	local TriggerName = GetModuleTriggerName(Trigger, Module)
	if CompletedTriggers[TriggerName] or TriggerZones[TriggerName] then
		return
	end

	PrepareTriggerPart(Trigger)
	for _, Descendant in Trigger:GetDescendants() do
		PrepareTriggerPart(Descendant)
	end

	local Zone = ZonePlus.new(Trigger)
	TriggerZones[TriggerName] = Zone

	Zone.localPlayerEntered:Connect(function()
		if CompletedTriggers[TriggerName] or RunningTriggers[TriggerName] then
			return
		end

		RunningTriggers[TriggerName] = true
		task.spawn(function()
			local Success, Result = pcall(function()
				if Module.Enter then
					Module.Enter(self, Trigger, TriggerName)
				end
			end)

			if not Success then
				RunningTriggers[TriggerName] = nil
				warn(Result)
			elseif not CompletedTriggers[TriggerName] then
				RunningTriggers[TriggerName] = nil
			end
		end)
	end)
end

function TriggerController:LoadTriggers()
	if not TriggerFolder then
		return
	end

	for _, Trigger in TriggerFolder:GetChildren() do
		self:LoadTrigger(Trigger)
	end
end

function TriggerController:KnitInit()
	TriggerService = Knit.GetService("TriggerService")
end

function TriggerController:KnitStart()
	TriggerService.CompletedTriggers:Connect(function(Triggers)
		self:SetCompletedTriggers(Triggers)
	end)

	while not CompletedTriggersFetched do
		if self:FetchCompletedTriggers() then
			break
		end

		task.wait(FETCH_RETRY_TIME)
	end

	TriggerFolder = ReplicatedStorage:FindFirstChild("Triggers") or workspace:FindFirstChild("Triggers")
	if not TriggerFolder then
		TriggerFolder = ReplicatedStorage:WaitForChild("Triggers", 10)
	end

	if not TriggerFolder then
		warn("[TriggerController] Missing ReplicatedStorage.Triggers.")
		return
	end

	TriggerFolder.Parent = workspace
	self:LoadTriggers()
end

return TriggerController
