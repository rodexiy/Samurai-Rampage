local FloorDrop = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local RenderController = Knit.GetController("RenderController")
local AnimationController = Knit.GetController("AnimationController")
local FloorDropService = Knit.GetService("FloorDropService")

local FloorDrops = Instance.new("Folder")
FloorDrops.Name = "FloorDrops"
FloorDrops.Parent = workspace

local ItemsData = require(game.ReplicatedStorage.Shared.Index.Items)
local Equipables = game.ReplicatedStorage.Assets.Equipables
local Weapons = game.ReplicatedStorage.Assets.Weapons
local Tools = game.ReplicatedStorage.Assets.Tools

local RunService = game:GetService("RunService")
local function SpinAndFloat(Model: Model, SpinSpeed: number, FloatSpeed: number, FloatOffset: number)
	local origin = Model:GetPivot().Position
	local running = true
	local angle = 0
	local t = 0

	Model.Destroying:Connect(function()
		running = false
	end)

	task.spawn(function()
		while running and Model.Parent do
			RunService.Heartbeat:Wait()

			angle += SpinSpeed
			if angle >= 360 then
				angle -= 360
			end

			t += FloatSpeed
			local y = math.sin(t) * FloatOffset

			local spin = CFrame.Angles(0, math.rad(angle), 0)
			local float = CFrame.new(0, y, 0)

			Model:PivotTo(CFrame.new(origin) * spin * float)
		end
	end)
end
function FloorDrop.Drop(RenderData)
	local DropId = RenderData.Id
	local DropName = RenderData.Name

	local DropModel

	if Equipables:FindFirstChild(DropName, true) then
		DropModel = Equipables:FindFirstChild(DropName, true):Clone()
	elseif Weapons:FindFirstChild(DropName, true) then
		DropModel = Weapons[DropName].Weapon:Clone()
	elseif Tools:FindFirstChild(DropName) then
		local Model = Instance.new("Model")
		local Tool = Tools:FindFirstChild(DropName):Clone()
		for _, Part in Tool:GetDescendants() do
			Part.Parent = Model
		end
		Tool:Destroy()
		DropModel = Model
	end

	if not DropModel then
		return
	end

	for _, v in DropModel:GetDescendants() do
		v:RemoveTag("SmartBone")
		if v:IsA("BasePart") then
			v.CanCollide = false
			v.Anchored = true
		end
	end

	local ItemData = ItemsData[DropName]
	local Rarity = ItemData.Rarity or "Common"
	local RarityVFX = game.ReplicatedStorage.Assets.VFX.Rarity[Rarity]:Clone()
	for _, Part in RarityVFX:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.CanCollide = false
			Part.Anchored = true
		end
	end

	local ModelHolder = Instance.new("Model")

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.ObjectText = (RenderData.Amount or "1") .. "x - " .. ItemData.DisplayName
	Prompt.ActionText = "Loot"
	Prompt.HoldDuration = 0
	Prompt.KeyboardKeyCode = Enum.KeyCode.F
	Prompt.RequiresLineOfSight = false
	Prompt.MaxActivationDistance = 5
	Prompt.Parent = DropModel

	Prompt.Triggered:Connect(function(Player)
		local Character = Player.Character
		AnimationController:PlayAnimation(Character, game.ReplicatedStorage.Assets.Animations.Misc.Pickup)
		FloorDropService:ClaimItem(DropId)

		task.delay(0.25, function()
			ModelHolder:Destroy()
		end)
	end)

	if not DropModel.PrimaryPart then
		if DropModel:FindFirstChild("Torso") then
			DropModel.PrimaryPart = DropModel.Torso.PrimaryPart
				or DropModel.Torso:FindFirstChildWhichIsA("BasePart", true)
		elseif DropModel:FindFirstChild("Head") then
			DropModel.PrimaryPart = DropModel.Head.PrimaryPart
				or DropModel.Head:FindFirstChildWhichIsA("BasePart", true)
		else
			DropModel.PrimaryPart = DropModel:FindFirstChildWhichIsA("BasePart", true)
		end
	end

	DropModel:PivotTo(CFrame.new(RenderData.Position) * CFrame.new(0, 1, 0))
	RarityVFX:PivotTo(CFrame.new(RenderData.Position) * CFrame.new(0, 0.5, 0))
	DropModel:PivotTo(DropModel:GetPivot() * CFrame.new(0, 1, 0))
	DropModel.Parent = ModelHolder
	ModelHolder.Name = DropId
	ModelHolder.Parent = FloorDrops
	DropModel:ScaleTo(DropModel:GetScale() * 0.5)
	RarityVFX.Parent = ModelHolder
	SpinAndFloat(DropModel, 2, 0.05, 1)

	DropModel.Name = "Drop"
	RenderController:EmitParticles(DropModel)
end

function FloorDrop.Remove(RenderData)
	local DropId = RenderData.Id
	local DropModel = FloorDrops:FindFirstChild(DropId)
	if DropModel then
		DropModel:Destroy()
	end
end

return FloorDrop
