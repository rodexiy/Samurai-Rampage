local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Actor: Actor = script.Parent
local RootObject
local ColliderDescriptions
local SmartboneModule
local SmartboneClass

local Setup = false
local SetupReady = Instance.new("BindableEvent")

local CONNECTIONS = {}

local function c(Conn: RBXScriptConnection)
	table.insert(CONNECTIONS, Conn)
end

local function cleanup()
	for _, Conn: RBXScriptConnection in CONNECTIONS do
		Conn:Disconnect()
	end
end

local Bind
Bind = Actor:BindToMessage("Setup", function(m_Object: BasePart, m_ColliderDescriptions: { { any } }, m_SmartBone: ModuleScript)
	RootObject = m_Object
	ColliderDescriptions = m_ColliderDescriptions
	SmartboneModule = m_SmartBone
	SmartboneClass = require(ReplicatedStorage.Assets.Libraries.SmartBone)

	Setup = true

	Bind:Disconnect()
	SetupReady:Fire()
end)

if not Setup then
	SetupReady.Event:Wait()
end
SetupReady:Destroy()

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local BonePhysics = SmartboneClass.new()
local DebugUi = require(ReplicatedStorage.Assets.Libraries.SmartBone.Dependencies:WaitForChild("Debug"):WaitForChild("DebugUi") :: ModuleScript)
local Iris
local Config = require(ReplicatedStorage.Assets.Libraries.SmartBone.Dependencies.Config)
local Utilities = require(ReplicatedStorage.Assets.Libraries.SmartBone.Dependencies.Utilities)
local ShouldDebug = RunService:IsStudio() or Config.ALLOW_LIVE_GAME_DEBUG
local OverlayEvent = SmartboneModule:WaitForChild("OverlayEvent")

local Destroyed = false
local Rest: { [Bone]: { CFrame: CFrame, Transform: CFrame } } = {}

local function DestroyRuntime()
	if Destroyed then
		return
	end

	Destroyed = true
	cleanup()
	BonePhysics:Destroy()
	task.synchronize()
	for Bone, Pose in Rest do
		if Bone.Parent then
			Bone.CFrame = Pose.CFrame
			Bone.Transform = Pose.Transform
		end
	end

	Actor:Destroy()
end

-- So much work for such a basic debug tool
local ImOverlay = {
	Begin = function(...)
		OverlayEvent:Fire("Begin", ...)
	end,
	End = function(...)
		OverlayEvent:Fire("End", ...)
	end,
	Text = function(...)
		OverlayEvent:Fire("Text", ...)
	end,
}

-- Frame counter for getting animatedworldcframe
shared.FrameCounter = 0
local FrameCounterOverflow = 2 ^ 17 -- Maximum number frame counter can go to before it resets to 0 =(131072)

if ShouldDebug then
	Iris = require(ReplicatedStorage.Assets.Libraries.SmartBone.Dependencies.Iris)
	if not Iris.HasInit() then
		Iris = Iris.Init()
	end
end

Actor.Name = `{RootObject.Name} - {BonePhysics.ID}`

if Actor:GetAttribute("SmartBoneStopping") or not RootObject:IsDescendantOf(workspace)
	or not CollectionService:HasTag(RootObject, "SmartBone") then
	DestroyRuntime()
	return
end

c(Actor:GetAttributeChangedSignal("SmartBoneStopping"):Connect(function()
	if Actor:GetAttribute("SmartBoneStopping") then
		DestroyRuntime()
	end
end))

c(RootObject.AncestryChanged:Connect(function()
	if not RootObject:IsDescendantOf(workspace) then
		DestroyRuntime()
	end
end))
c(RootObject.Destroying:Connect(DestroyRuntime))

for _, Bone in RootObject:QueryDescendants("Bone") :: { Bone } do
	Rest[Bone] = { CFrame = Bone.CFrame, Transform = Bone.Transform }
end

BonePhysics:LoadObject(RootObject)

for _, ColliderDescription in ColliderDescriptions do
	BonePhysics:LoadRawCollider(ColliderDescription[1], ColliderDescription[2])
end

local DebugState

if ShouldDebug then
	DebugState = {
		DRAW_BONE = Iris.State(false),
		DRAW_PHYSICAL_BONE = Iris.State(false),
		DRAW_ROOT_PART = Iris.State(false),
		DRAW_BOUNDING_BOX = Iris.State(false),
		DRAW_AXIS_LIMITS = Iris.State(false),
		DRAW_COLLIDERS = Iris.State(false),
		DRAW_COLLIDER_INFLUENCE = Iris.State(false),
		DRAW_COLLIDER_AWAKE = Iris.State(false),
		DRAW_COLLIDER_BROADPHASE = Iris.State(false),
		DRAW_FILL_COLLIDERS = Iris.State(false),
		DRAW_CONTACTS = Iris.State(false),
		DRAW_ROTATION_LIMITS = Iris.State(false),
		DRAW_ACCELERATION_INFO = Iris.State(false),
	}
end

-- ShouldDebug is just if we are in studio or not
if ShouldDebug then
	Iris:Connect(function()
		if not Destroyed and RootObject:IsDescendantOf(workspace) and RootObject:GetAttribute("Debug") ~= nil then
			DebugUi(Iris, BonePhysics, DebugState)
		end
	end)
end

c(CollectionService:GetInstanceAddedSignal("SmartCollider"):Connect(function(Object: BasePart)
	if not Object:IsA("BasePart") then
		return
	end

	local ColliderKey = Object:GetAttribute("ColliderKey")
	local RootColliderKey = RootObject:GetAttribute("ColliderKey")

	if tostring(ColliderKey) ~= tostring(RootColliderKey) then
		return
	end

	local ColliderObject = Utilities.GetCollider(Object)

	BonePhysics:LoadRawCollider(ColliderObject, Object)
end))

c(Actor:BindToMessage("Destroy", DestroyRuntime))

c(CollectionService:GetInstanceRemovedSignal("SmartBone"):Connect(function(Object: Instance)
	if Object == RootObject then
		DestroyRuntime()
	end
end))

c(RunService.Heartbeat:ConnectParallel(function(deltaTime: number)
	if Destroyed or not RootObject:IsDescendantOf(workspace) then
		return
	end

	shared.FrameCounter += 1

	if shared.FrameCounter > FrameCounterOverflow then
		shared.FrameCounter = 0
	end

	BonePhysics:StepBoneTrees(deltaTime)

	if BonePhysics.ShouldDestroy then
		task.synchronize()
		DestroyRuntime()
		return
	end

	-- ShouldDebug is just if we are in studio or not
	if ShouldDebug then
		if RootObject:GetAttribute("Debug") ~= nil then
			task.synchronize()
			BonePhysics:DrawDebug(
				DebugState.DRAW_COLLIDERS:get(),
				DebugState.DRAW_CONTACTS:get(),
				DebugState.DRAW_PHYSICAL_BONE:get(),
				DebugState.DRAW_BONE:get(),
				DebugState.DRAW_AXIS_LIMITS:get(),
				DebugState.DRAW_ROOT_PART:get(),
				DebugState.DRAW_FILL_COLLIDERS:get(),
				DebugState.DRAW_COLLIDER_INFLUENCE:get(),
				DebugState.DRAW_COLLIDER_AWAKE:get(),
				DebugState.DRAW_COLLIDER_BROADPHASE:get(),
				DebugState.DRAW_BOUNDING_BOX:get(),
				DebugState.DRAW_ROTATION_LIMITS:get(),
				DebugState.DRAW_ACCELERATION_INFO:get()
			)

			BonePhysics:DrawOverlay(ImOverlay)
		end
	end
end))

