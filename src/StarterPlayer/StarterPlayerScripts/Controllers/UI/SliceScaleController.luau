local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SliceScaleController = Knit.CreateController({
	Name = "SliceScaleController",
})

local TAG = "SliceType"
local BASE_SCALE_ATTRIBUTE = "BaseSliceScale"
local REFERENCE_SIZE = Vector2.new(1920, 1080)

type ImageState = {
	BaseScale: number,
	ScaleTypeConnection: RBXScriptConnection,
}

local PlayerGui: PlayerGui
local Images: { [ImageLabel]: ImageState } = {}
local ViewportScale = 1
local ViewportConnection: RBXScriptConnection? = nil

local function UpdateImage(Image: ImageLabel)
	local State = Images[Image]
	if not State then
		return
	end

	Image.SliceScale = State.BaseScale * (if Image.ScaleType == Enum.ScaleType.Slice then ViewportScale else 1)
end

local function TrackImage(Instance: Instance)
	if not Instance:IsA("ImageLabel") or not Instance:IsDescendantOf(PlayerGui) then
		return
	end

	if Images[Instance] or not CollectionService:HasTag(Instance, TAG) then
		return
	end

	local BaseScale = Instance:GetAttribute(BASE_SCALE_ATTRIBUTE)
	if typeof(BaseScale) ~= "number" then
		BaseScale = Instance.SliceScale
		-- Runtime clones must inherit the original value, rather than an already scaled value.
		Instance:SetAttribute(BASE_SCALE_ATTRIBUTE, BaseScale)
	end

	Images[Instance] = {
		BaseScale = BaseScale,
		ScaleTypeConnection = Instance:GetPropertyChangedSignal("ScaleType"):Connect(function()
			UpdateImage(Instance)
		end),
	}

	UpdateImage(Instance)
end

local function UntrackImage(Instance: Instance)
	if not Instance:IsA("ImageLabel") then
		return
	end

	local State = Images[Instance]
	if not State then
		return
	end

	Images[Instance] = nil
	State.ScaleTypeConnection:Disconnect()
	Instance.SliceScale = State.BaseScale
end

local function UpdateViewport()
	local Camera = workspace.CurrentCamera
	if not Camera then
		return
	end

	local ViewportSize = Camera.ViewportSize
	if ViewportSize.X <= 0 or ViewportSize.Y <= 0 then
		return
	end

	ViewportScale = math.min(ViewportSize.X / REFERENCE_SIZE.X, ViewportSize.Y / REFERENCE_SIZE.Y)

	for Image in Images do
		UpdateImage(Image)
	end
end

local function BindCamera()
	if ViewportConnection then
		ViewportConnection:Disconnect()
		ViewportConnection = nil
	end

	local Camera = workspace.CurrentCamera
	if Camera then
		ViewportConnection = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateViewport)
	end

	UpdateViewport()
end

function SliceScaleController.KnitStart()
	PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(BindCamera)
	BindCamera()

	CollectionService:GetInstanceAddedSignal(TAG):Connect(TrackImage)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(UntrackImage)
	PlayerGui.DescendantAdded:Connect(TrackImage)
	PlayerGui.DescendantRemoving:Connect(UntrackImage)

	for _, Instance in CollectionService:GetTagged(TAG) do
		TrackImage(Instance)
	end
end

return SliceScaleController
