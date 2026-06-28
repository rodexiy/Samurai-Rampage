local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local worldWalls = ReplicatedStorage:WaitForChild("WorldWalls")
local invisibleFolder = worldWalls:FindFirstChild("Invisible")

local function makeTransparent(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Transparency = 1
	end
end

if invisibleFolder then
	for _, descendant in invisibleFolder:GetDescendants() do
		makeTransparent(descendant)
	end

	invisibleFolder.DescendantAdded:Connect(makeTransparent)
end

worldWalls.Parent = Workspace
