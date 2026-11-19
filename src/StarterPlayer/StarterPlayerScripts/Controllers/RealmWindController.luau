local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RealmWindController = Knit.CreateController({ Name = "RealmWindController" })
local Service

function RealmWindController.Rebase(Wind: any, Object: BasePart | Bone, Frame: CFrame)
	if Object:IsA("BasePart") then
		Object.CFrame = Frame
	else
		-- The bone's authored local CFrame must keep following its replicated parent.
		Object.Transform = CFrame.identity
	end

	local Metadata = Wind.ObjectMetadata[Object]
	if not Metadata then
		Wind:AddObjectShake(Object)
		Metadata = Wind.ObjectMetadata[Object]
	end
	if not Metadata then
		return
	end

	Wind.VectorMap:RemoveObject(Metadata.ChunkKey, Object)
	Metadata.Origin = Frame
	Metadata.ChunkKey = Wind.VectorMap:AddObject(Frame.Position, Object)
	Metadata.LastUpdate = 0
end

function RealmWindController.KnitInit()
	Service = Knit.GetService("RealmBuildingService")
end

function RealmWindController.KnitStart()
	local Wind = require(Players.LocalPlayer.PlayerScripts:WaitForChild("WindController"):WaitForChild("WindShake") :: ModuleScript)
	Service.WindMoved:Connect(function(Frames: { { Object: Instance, Frame: CFrame } })
		for _, Entry in Frames do
			local Object = Entry.Object
			if typeof(Object) == "Instance" and Object:IsDescendantOf(workspace) and Object:HasTag("WindShake")
				and (Object:IsA("BasePart") or Object:IsA("Bone")) then
				RealmWindController.Rebase(Wind, Object, Entry.Frame)
			end
		end
	end)
end

return RealmWindController
