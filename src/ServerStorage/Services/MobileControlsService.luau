local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local MobileControlLayout = require(ReplicatedStorage.Shared.MobileControlLayout)

type Layout = MobileControlLayout.Layout

local MobileControlsService = Knit.CreateService({
	Name = "MobileControlsService",
	Client = {
		SaveLayout = Knit.CreateSignal(),
		LayoutSaved = Knit.CreateSignal(),
	},
})

local DataService

function MobileControlsService:GetLayout(Player: Player): Layout?
	local Data = DataService:GetData(Player)
	if not Data then
		return nil
	end

	Data.MobileControlPositions = MobileControlLayout.Validate(Data.MobileControlPositions) or {}
	return MobileControlLayout.Validate(Data.MobileControlPositions)
end

function MobileControlsService:SaveLayout(Player: Player, RequestId: any, Value: any)
	if typeof(RequestId) ~= "number" or RequestId ~= RequestId or RequestId < 1
		or RequestId > 2147483647 or RequestId % 1 ~= 0 then
		return
	end

	local Layout = MobileControlLayout.Validate(Value)
	local Data = DataService:GetData(Player)
	if not Layout or not Data then
		self.Client.LayoutSaved:Fire(Player, RequestId, false)
		return
	end

	Data.MobileControlPositions = Layout
	self.Client.LayoutSaved:Fire(Player, RequestId, true, Layout)
end

function MobileControlsService.Client:GetLayout(Player: Player): Layout?
	return self.Server:GetLayout(Player)
end

function MobileControlsService.KnitInit()
	DataService = Knit.GetService("DataService")
end

function MobileControlsService.KnitStart()
	MobileControlsService.Client.SaveLayout:Connect(function(Player: Player, RequestId: any, Layout: any)
		MobileControlsService:SaveLayout(Player, RequestId, Layout)
	end)
end

return MobileControlsService
