local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RealmResourceController = Knit.CreateController({ Name = "RealmResourceController" })
local Changed = Instance.new("BindableEvent")
RealmResourceController.Changed = Changed.Event

local Service
local Required = true

function RealmResourceController:AreResourcesRequired(): boolean
	return Required
end

function RealmResourceController.KnitInit()
	Service = Knit.GetService("RealmResourceService")
end

function RealmResourceController.KnitStart()
	Service.RequirementsChanged:Connect(function(ResourcesRequired: boolean)
		if Required == ResourcesRequired then
			return
		end

		Required = ResourcesRequired
		Changed:Fire(Required)
	end)
	Service.RequirementsRequested:Fire()
end

return RealmResourceController
