local FloorDrop = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local RenderController = Knit.GetController("RenderController")
local AnimationController = Knit.GetController("AnimationController")
local FloorDropService = Knit.GetService("FloorDropService")

local FloorDrops = Instance.new("Folder")
FloorDrops.Name = "FloorDrops"
FloorDrops.Parent = workspace

local ItemsData = require(ReplicatedStorage.Shared.Index.Items)
local Equipables = ReplicatedStorage.Assets.Equipables
local Weapons = ReplicatedStorage.Assets.Weapons
local Tools = ReplicatedStorage.Assets.Tools

local function SpinAndFloat(Model: Model, SpinSpeed: number, FloatSpeed: number, FloatOffset: number)
	local origin = Model:GetPivot().Position
	local angle = 0
	local t = 0

	local Connection = RunService.Heartbeat:Connect(function(DeltaTime: number)
		angle = (angle + SpinSpeed * DeltaTime * 60) % 360
		t += FloatSpeed * DeltaTime * 60
		local y = math.sin(t) * FloatOffset
		Model:PivotTo(CFrame.new(origin + Vector3.new(0, y, 0)) * CFrame.Angles(0, math.rad(angle), 0))
	end)
	Model.Destroying:Connect(function()
		Connection:Disconnect()
	end)
end
function FloorDrop.PickAnim(RenderData: { [string]: any })
	local Character = RenderData.Character
	AnimationController:PlayAnimation(Character, ReplicatedStorage.Assets.Animations.Misc.Pickup)
end

function FloorDrop.Drop(RenderData: { [string]: any })
	local DropId = RenderData.Id
	local DropName = RenderData.Name

	local DropModel

	if RenderData.UseDroppedItem then
		DropModel = ReplicatedStorage.Assets.Models.DroppedItem:Clone()
	elseif Equipables:FindFirstChild(DropName, true) then
		DropModel = Equipables:FindFirstChild(DropName, true):Clone()
	elseif Weapons:FindFirstChild(DropName, true) then
		DropModel = Weapons[DropName].Weapon:Clone()
	elseif Tools:FindFirstChild(DropName) then
		local Model = Instance.new("Model")
		local Tool = Tools:FindFirstChild(DropName):Clone()
		for _, Part in Tool:GetChildren() do
			Part.Parent = Model
		end
		Tool:Destroy()
		DropModel = Model
	end

	if not DropModel then
		return
	end

	for _, v in DropModel:QueryDescendants("Instance") do
		v:RemoveTag("SmartBone")
		if v:IsA("BasePart") then
			v.CanCollide = false
			v.Anchored = true
		end
	end

	local ItemData = ItemsData[DropName]
	if not ItemData then
		DropModel:Destroy()
		return
	end
	local Rarity = ItemData.Rarity or "Common"
	local RarityVFX = ReplicatedStorage.Assets.VFX.Rarity[Rarity]:Clone()
	for _, Part in RarityVFX:QueryDescendants("BasePart") do
		Part.CanCollide = false
		Part.Anchored = true
	end

	local Existing = FloorDrops:FindFirstChild(DropId)
	if Existing then
		Existing:Destroy()
	end
	local ModelHolder = Instance.new("Model")

	local Prompt = DropModel:FindFirstChildWhichIsA("ProximityPrompt", true) or Instance.new("ProximityPrompt")
	Prompt.ObjectText = tostring(RenderData.Amount or 1) .. "x - " .. (ItemData.DisplayName or DropName)
	Prompt.ActionText = "Loot"
	Prompt.HoldDuration = 0
	Prompt.KeyboardKeyCode = Enum.KeyCode.F
	Prompt.RequiresLineOfSight = false
	Prompt.MaxActivationDistance = 5

	Prompt.Triggered:Connect(function(Player: Player)
		local Character = Player.Character
		AnimationController:PlayAnimation(Character, ReplicatedStorage.Assets.Animations.Misc.Pickup)
		FloorDropService:ClaimItem(DropId)
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

	if not DropModel.PrimaryPart then
		DropModel:Destroy()
		RarityVFX:Destroy()
		Prompt:Destroy()
		ModelHolder:Destroy()
		return
	end
	Prompt.Parent = DropModel.PrimaryPart

	DropModel:PivotTo(CFrame.new(RenderData.Position) * CFrame.new(0, 1, 0))
	RarityVFX:PivotTo(CFrame.new(RenderData.Position) * CFrame.new(0, 0.5, 0))
	DropModel:PivotTo(DropModel:GetPivot() * CFrame.new(0, 1, 0))
	DropModel.Parent = ModelHolder
	ModelHolder.Name = DropId
	ModelHolder.Parent = FloorDrops
	if not RenderData.UseDroppedItem then
		DropModel:ScaleTo(DropModel:GetScale() * 0.5)
	end
	RarityVFX.Parent = ModelHolder
	SpinAndFloat(DropModel, 2, 0.05, 1)

	DropModel.Name = "Drop"
	RenderController:EmitParticles(DropModel)
end

function FloorDrop.Remove(RenderData: { [string]: any })
	local DropId = RenderData.Id
	local DropModel = FloorDrops:FindFirstChild(DropId)
	if DropModel then
		DropModel:Destroy()
	end
end

return FloorDrop
