local Character = script:FindFirstAncestorOfClass("Model")
if not Character then
	return
end

local normal = "rbxassetid://114554769890048"
local blink = "rbxassetid://130597981160124"
local Head = Character:FindFirstChild("Head")
if not Head then
	return
end
local face: Decal = Head:FindFirstChild("face")
if not face then
	return
end

local FaceHeadFolder = workspace:FindFirstChild("FaceHeadFolder")
if not FaceHeadFolder then
	FaceHeadFolder = Instance.new("Model")
	FaceHeadFolder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	FaceHeadFolder.Name = "FaceHeadFolder"
	FaceHeadFolder.Parent = workspace
end

face:Destroy()

local FaceHead: BasePart = Head:Clone()

local Weld = Instance.new("WeldConstraint")
Weld.Part0 = Head
Weld.Part1 = FaceHead
Weld.Name = "FaceHeadWeld"
Weld.Parent = FaceHead

Weld:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not Weld.Enabled then
		Weld.Enabled = true
	end
end)

FaceHead.Name = Character.Name .. "FaceHead"
FaceHead:PivotTo(Head:GetPivot())
FaceHead.Transparency = 1
FaceHead.CanCollide = false
FaceHead.CanQuery = false
FaceHead.CanTouch = false
FaceHead.Size = Head.Size * 1.001
FaceHead.Parent = FaceHeadFolder

Character.Destroying:Connect(function()
	FaceHead:Destroy()
end)

Head.ChildAdded:Connect(function(child)
	if child.Name == "face" then
		child:Destroy()
	end
end)

local eyes = "rbxassetid://111319744357882"
local mult = 2.75

local function toBrightRGB(x)
	return math.clamp(x * 255 * mult, 0, 255)
end

local eyesFace = Instance.new("Decal")
eyesFace.Name = "EyesFace"
eyesFace.ZIndex = 2

local function updateEyeColor()
	local EyesColor = Character:GetAttribute("EyesColor") or Color3.new(1, 1, 1)

	eyesFace.Color3 = Color3.fromRGB(toBrightRGB(EyesColor.R), toBrightRGB(EyesColor.G), toBrightRGB(EyesColor.B))
end

updateEyeColor()
eyesFace.Transparency = 0
eyesFace.Texture = eyes
eyesFace.Parent = FaceHead

Character:GetAttributeChangedSignal("EyesColor"):Connect(function()
	updateEyeColor()
end)

local blinkFace = Instance.new("Decal")
blinkFace.Name = "BlinkFace"
blinkFace.Texture = blink
blinkFace.Transparency = 1
blinkFace.Parent = FaceHead

local normalFace = Instance.new("Decal")
normalFace.Name = "NormalFace"
normalFace.Texture = normal
normalFace.Transparency = 0
normalFace.Parent = FaceHead

while Character.Parent and FaceHead.Parent do
	normalFace.Transparency = 0
	eyesFace.Transparency = 0
	blinkFace.Transparency = 1

	task.wait(math.random(6, 12))
	normalFace.Transparency = 1
	eyesFace.Transparency = 1
	blinkFace.Transparency = 0
	task.wait(.15)
end
