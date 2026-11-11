local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local HorseRigController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.HorseAnimationController.HorseRigController)

local HorseAnimationController = Knit.CreateController({ Name = "HorseAnimationController" })
local Settings = HorseConfig.Animation
local Tracked: { [Model]: boolean } = {}
local Rigs: { [Model]: HorseRigController.Rig } = {}
local TargetFolder: Folder
local LookEvent: UnreliableRemoteEvent
local LookModel: Model? = nil
local LastLook: Vector3? = nil
local LookElapsed = 0
local LastLookTime = -math.huge

local function GetRiderLook(Model: Model, Root: BasePart, Camera: Camera, DeltaTime: number, Now: number): Vector3?
	if Model:GetAttribute("RiderUserId") ~= Players.LocalPlayer.UserId then
		return nil
	end
	local Look = Settings.RiderLook
	if (Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > Look.MaximumSpeed then
		LastLook = nil
		LookElapsed = Look.Interval
		return nil
	end
	if LookModel ~= Model then
		LookModel, LastLook = Model, nil
		LookElapsed = Look.Interval
	end
	LookElapsed += DeltaTime
	local Direction = Camera.CFrame.LookVector
	local Changed = not LastLook or LastLook:Dot(Direction) < math.cos(Look.MinimumChange)
	if LookElapsed >= Look.Interval and (Changed or Now - LastLookTime >= Look.KeepAlive) then
		LookElapsed = 0
		LastLook, LastLookTime = Direction, Now
		LookEvent:FireServer(Direction)
	end

	return Direction
end

local function TrackHorse(Object: Instance)
	if Object:IsA("Model") then
		Tracked[Object] = true
	end
end

local function RemoveHorse(Object: Instance)
	if not Object:IsA("Model") then
		return
	end

	local Rig = Rigs[Object]
	if Rig then
		HorseRigController.Destroy(Rig)
		Rigs[Object] = nil
	end
	Tracked[Object] = nil
end

local function GetQuality(Root: BasePart, Camera: Camera): number
	local Offset = Root.Position - Camera.CFrame.Position
	local Distance = Offset.Magnitude
	if Distance > Settings.MaxDistance then
		return 0
	end
	if Distance > 30 and Offset.Unit:Dot(Camera.CFrame.LookVector) < -0.15 then
		return 0
	end

	return if Distance <= Settings.FullDistance then 2 else 1
end

local function Animate(DeltaTime: number, RenderPass: boolean)
	local Camera = workspace.CurrentCamera
	if not Camera then
		return
	end

	local Now = workspace:GetServerTimeNow()
	for Model in Tracked do
		if not Model:IsDescendantOf(workspace) then
			continue
		end
		local LocalRider = Settings.SmoothLocalRider and Model:GetAttribute("RiderUserId") == Players.LocalPlayer.UserId
		if LocalRider ~= RenderPass then
			continue
		end

		local Rig = Rigs[Model]
		if not Rig then
			Rig = HorseRigController.Create(Model, TargetFolder)
			Rigs[Model] = Rig
		end
		if not Rig or not Rig.Root.Parent then
			continue
		end

		local Quality = if LocalRider then 2 else GetQuality(Rig.Root, Camera)
		if Quality == 0 then
			HorseRigController.SetQuality(Rig, 0)
			continue
		end

		Rig.Elapsed += DeltaTime
		if Quality == 2 or Rig.Elapsed >= Settings.DistantInterval or Rig.Quality ~= Quality then
			local Elapsed = Rig.Elapsed
			Rig.Elapsed = 0
			local Look = GetRiderLook(Model, Rig.Root, Camera, Elapsed, Now)
			HorseRigController.Update(Rig, Elapsed, Now, Quality, LocalRider, Look)
		end
	end
end

function HorseAnimationController.KnitStart()
	LookEvent = ReplicatedStorage.Assets.Events:WaitForChild("HorseLook") :: UnreliableRemoteEvent
	TargetFolder = Instance.new("Folder")
	TargetFolder.Name = "ClientHorseAnimation"
	TargetFolder.Parent = workspace

	CollectionService:GetInstanceAddedSignal(HorseConfig.Tag):Connect(TrackHorse)
	CollectionService:GetInstanceRemovedSignal(HorseConfig.Tag):Connect(RemoveHorse)
	for _, Model in CollectionService:GetTagged(HorseConfig.Tag) do
		TrackHorse(Model)
	end

	RunService.PreSimulation:Connect(function(DeltaTime: number)
		Animate(DeltaTime, false)
	end)
	-- The rider's visible bones follow rendering, without advancing the rig twice.
	RunService.PreRender:Connect(function(DeltaTime: number)
		Animate(DeltaTime, true)
	end)
end

return HorseAnimationController
