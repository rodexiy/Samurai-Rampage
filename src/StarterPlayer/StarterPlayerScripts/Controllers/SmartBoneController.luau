local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local SmartBone = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Libraries"):WaitForChild("SmartBone"))

local SmartBoneController = Knit.CreateController({ Name = "SmartBoneController" })
local Player = Players.LocalPlayer

type Record = {
	Rate: number?, Rest: { [Bone]: CFrame }, Paused: boolean,
	Connection: RBXScriptConnection?, AncestryConnection: RBXScriptConnection?,
}
local Objects: { [BasePart]: Record } = {}

local function IsEnabled(): boolean
	return Player:GetAttribute("SmartBone") ~= false
end

local function Apply(Object: BasePart, Record: Record)
	if IsEnabled() or not Object:IsDescendantOf(workspace) then
		if Record.Paused then
			Record.Paused = false
			Object:SetAttribute("UpdateRate", Record.Rate)
		end
		return
	end

	Record.Paused = true
	Object:SetAttribute("UpdateRate", 0)
	for Bone, Rest in Record.Rest do
		if Bone.Parent then
			Bone.CFrame = Rest
		end
	end
end

local function Track(Object: Instance)
	if not Object:IsA("BasePart") or Objects[Object] then
		return
	end

	local Rest: { [Bone]: CFrame } = {}
	for _, Bone in Object:QueryDescendants("Bone") :: { Bone } do
		Rest[Bone] = Bone.CFrame
	end
	local Record: Record = { Rate = Object:GetAttribute("UpdateRate"), Rest = Rest, Paused = false }
	Objects[Object] = Record
	Record.Connection = Object:GetAttributeChangedSignal("UpdateRate"):Connect(function()
		local Rate = Object:GetAttribute("UpdateRate")
		if not Record.Paused then
			Record.Rate = Rate
		elseif Rate ~= 0 then
			Record.Rate = Rate
			Object:SetAttribute("UpdateRate", 0)
		end
	end)
	Record.AncestryConnection = Object.AncestryChanged:Connect(function()
		Apply(Object, Record)
	end)
	Apply(Object, Record)
end

function SmartBoneController.KnitStart()
	CollectionService:GetInstanceAddedSignal("SmartBone"):Connect(Track)
	CollectionService:GetInstanceRemovedSignal("SmartBone"):Connect(function(Object: Instance)
		if not Object:IsA("BasePart") then
			return
		end
		local Record = Objects[Object]
		if Record then
			if Record.Connection then
				Record.Connection:Disconnect()
			end
			if Record.AncestryConnection then
				Record.AncestryConnection:Disconnect()
			end
			if Record.Paused then
				Object:SetAttribute("UpdateRate", Record.Rate)
			end
			Objects[Object] = nil
		end
	end)
	Player:GetAttributeChangedSignal("SmartBone"):Connect(function()
		for Object, Record in Objects do
			Apply(Object, Record)
		end
	end)

	for _, Object in CollectionService:GetTagged("SmartBone") do
		Track(Object)
	end
	SmartBone.Start()
end

return SmartBoneController
