local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RegionController = Knit.CreateController({
	Name = "RegionController",
})

local Player = game.Players.LocalPlayer
local PlayerGui
local Temporary
local Region
local Canvas

local Tween: Tween = nil
local Thread = nil

function RegionController:ChangedRegion()
	local RegionName = Player:GetAttribute("NamedRegion")
	if not RegionName then
		return
	end

	if Tween then
		Tween:Cancel()
		Tween = nil
	end

	if Thread then
		task.cancel(Thread)
		Thread = nil
	end

	Thread = task.spawn(function()
		Canvas.GroupTransparency = 1

		Canvas.background.RegionName.Text = RegionName

		TweenService:Create(Canvas, TweenInfo.new(0.5), { GroupTransparency = 0 }):Play()

		task.wait(2.5)
		TweenService:Create(Canvas, TweenInfo.new(0.5), { GroupTransparency = 1 }):Play()
	end)
end

function RegionController.KnitInit() end

function RegionController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Temporary = PlayerGui:WaitForChild("Temporary", math.huge)
	Region = Temporary:WaitForChild("Region")
	Canvas = Region:WaitForChild("RegionCanvas")

	Player:GetAttributeChangedSignal("NamedRegion"):Connect(function()
		RegionController:ChangedRegion()
	end)
end

return RegionController
