local HeavensRecall = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local LightningBolt = require(game.ReplicatedStorage.Assets.Libraries.LightningBolt)
local LightningSparks = require(game.ReplicatedStorage.Assets.Libraries.LightningBolt.LightningSparks)

function HeavensRecall.Caller(Attacker: Model, Data: { any })
	if true then
		return false
	end
	local A1 = Instance.new("Attachment")
	A1.Parent = workspace.LightningHandler.PrimaryPart
	A1.WorldCFrame = Attacker.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0)

	local A2 = Instance.new("Attachment")
	A2.Parent = workspace.LightningHandler.PrimaryPart
	A2.WorldCFrame = Attacker.HumanoidRootPart.CFrame * CFrame.new(0, 100, 0)

	local NewBolt = LightningBolt.new(A1, A2, 50)
	NewBolt.PulseSpeed = 20
	NewBolt.PulseLength = 2
	NewBolt.Thickness = 1
	NewBolt.FadeLength = 0.2
	NewBolt.AnimationSpeed = 20
	NewBolt.Frequency = 5
	NewBolt.Color = Color3.fromRGB(255, 255, 0)

	LightningSparks.new(NewBolt)

	Attacker.PrimaryPart.Anchored = true
	Attacker:PivotTo(CFrame.new(workspace.Map.Raijin.Spawn:GetPivot().Position))
	task.delay(0.2, function()
		A1:Destroy()
		A2:Destroy()
	end)

	task.wait(0.1)
	local A1 = Instance.new("Attachment")
	A1.Parent = workspace.LightningHandler.PrimaryPart
	A1.WorldCFrame = Attacker.HumanoidRootPart.CFrame * CFrame.new(0, -2.5, 0)

	local A2 = Instance.new("Attachment")
	A2.Parent = workspace.LightningHandler.PrimaryPart
	A2.WorldCFrame = Attacker.HumanoidRootPart.CFrame * CFrame.new(0, 100, 0)

	local NewBolt = LightningBolt.new(A2, A1, 50)
	NewBolt.PulseSpeed = 20
	NewBolt.PulseLength = 2
	NewBolt.Thickness = 1
	NewBolt.FadeLength = 0.2
	NewBolt.AnimationSpeed = 20
	NewBolt.Frequency = 5
	NewBolt.Color = Color3.fromRGB(255, 255, 0)

	Attacker.PrimaryPart.Anchored = false

	LightningSparks.new(NewBolt)

	task.delay(0.2, function()
		A1:Destroy()
		A2:Destroy()
	end)
end

function HeavensRecall.Start() end

return HeavensRecall
