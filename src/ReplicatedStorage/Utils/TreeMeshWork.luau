local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.TreeCuttingConfig)

local TreeMeshWork = {}
local Frame = 0
local BudgetFrame = -1
local Deadline = 0

RunService.PostSimulation:Connect(function()
	Frame += 1
end)

function TreeMeshWork.Checkpoint()
	if not RunService:IsRunning() then
		return
	end
	while true do
		local Now = os.clock()
		if BudgetFrame ~= Frame then
			BudgetFrame = Frame
			Deadline = Now + Config.MeshWorkBudget
		end
		if Now < Deadline then
			return
		end
		RunService.PostSimulation:Wait()
	end
end

return TreeMeshWork
