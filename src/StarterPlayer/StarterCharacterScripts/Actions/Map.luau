-- Map.lua (Client)
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- exported table (match your old DropArtifact shape)
local Map = {}

-- keys & callback (keeps compat)
Map.keys = { Enum.KeyCode.N }
Map.callback = function(inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end
	Map.ToggleMap()
end

-- CONFIG (ajuste conforme seu mundo)
local MinZoom = 80
local MaxZoom = 5000
local DefaultZoom = 200

local MoveSpeed = 2.5 -- base screen-to-world multiplier
local SmoothSpeed = 0.15 -- 0..1, maior = menos suave

local MapGroundCenter = Vector3.new(0, 0, 0) -- X,Z center on ground (Y should be 0)
local MapBoundsMin = Vector3.new(-5000, 0, -5000) -- opcional: limites X,Z
local MapBoundsMax = Vector3.new(5000, 0, 5000)

-- STATE
local IsOpen = false
local DefaultCameraCFrame = nil

local CurrentZoom = DefaultZoom
local TargetZoom = DefaultZoom

local CurrentCenter = MapGroundCenter
local TargetCenter = MapGroundCenter

local Dragging = false
local LastMousePos = nil

-- safety: make sure Camera exists
if not Camera then
	warn("[Map] No Camera found in workspace.CurrentCamera")
	Camera = workspace:WaitForChild("Camera") -- try fallback (rare)
end

-- Helpers
local function ClampMapPosition(pos)
	local x = math.clamp(pos.X, MapBoundsMin.X, MapBoundsMax.X)
	local z = math.clamp(pos.Z, MapBoundsMin.Z, MapBoundsMax.Z)
	return Vector3.new(x, 0, z)
end

local function SetOpenState(open)
	-- ensure targets are initialized the first time
	if open and DefaultCameraCFrame == nil then
		DefaultCameraCFrame = Camera.CFrame
	end

	IsOpen = open

	if IsOpen then
		-- initialize targets to current camera/player if not set
		TargetZoom = TargetZoom or DefaultZoom
		CurrentZoom = CurrentZoom or TargetZoom

		-- center on player (prefer) or preconfigured center
		local root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			TargetCenter = ClampMapPosition(Vector3.new(root.Position.X, 0, root.Position.Z))
		else
			TargetCenter = ClampMapPosition(MapGroundCenter)
		end

		CurrentCenter = CurrentCenter or TargetCenter

		-- take control of the camera
		Camera.CameraType = Enum.CameraType.Scriptable
	else
		-- restore camera type and leave camera where it was (smooth will lerp back if you want)
		if DefaultCameraCFrame then
			-- instant restore to previous camera (you can lerp if desired)
			Camera.CameraType = Enum.CameraType.Custom
			-- restore camera transform to the saved one (do a smooth lerp)
			-- We will perform a short lerp to the original camera; set CurrentZoom/Center so UpdateCamera doesn't fight it
			-- To keep it simple, just set CFrame to DefaultCameraCFrame immediately:
			Camera.CFrame = DefaultCameraCFrame
		else
			Camera.CameraType = Enum.CameraType.Custom
		end
	end
end

-- Public: toggle (idempotent & safe to call anytime)
function Map.ToggleMap()
	SetOpenState(not IsOpen)
end

-- Drag / zoom processing
local function StartDrag()
	if not IsOpen then
		return
	end
	Dragging = true
	LastMousePos = UserInputService:GetMouseLocation()
end

local function StopDrag()
	Dragging = false
	LastMousePos = nil
end

local function ProcessDrag()
	if not Dragging or not IsOpen or not LastMousePos then
		return
	end

	local mousePos = UserInputService:GetMouseLocation()
	local delta = mousePos - LastMousePos

	-- scale movement so it feels consistent across zooms
	local zoomFactor = math.clamp(CurrentZoom / DefaultZoom, 0.2, 10) -- avoid extremes
	local worldDeltaX = -delta.X * MoveSpeed * (zoomFactor / 10) -- divide further so movement is reasonable
	local worldDeltaZ = -delta.Y * MoveSpeed * (zoomFactor / 10)

	TargetCenter = TargetCenter + Vector3.new(worldDeltaX, 0, worldDeltaZ)
	TargetCenter = ClampMapPosition(TargetCenter)

	LastMousePos = mousePos
end

local function ProcessZoom(input)
	if not IsOpen then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return
	end

	-- positive Z means scroll up on most mice -> zoom in (decrease distance)
	local delta = input.Position.Z
	TargetZoom = math.clamp(TargetZoom - (delta * 150), MinZoom, MaxZoom)
end

-- main camera update; lerp values for smoothness
local function UpdateCamera(dt)
	if not IsOpen then
		return
	end

	-- smooth zoom / center
	CurrentZoom = CurrentZoom + (TargetZoom - CurrentZoom) * SmoothSpeed
	CurrentCenter = CurrentCenter:Lerp(TargetCenter, SmoothSpeed)

	-- build top-down camera
	local camCFrame = CFrame.new(CurrentCenter.X, CurrentZoom, CurrentCenter.Z) * CFrame.Angles(-math.rad(90), 0, 0)

	-- apply camera
	Camera.CFrame = Camera.CFrame:Lerp(camCFrame, math.clamp(10 * dt, 0, 1))
end

-- Connections (established on Start)
local inputChangedConn = nil
local inputBeganConn = nil
local inputEndedConn = nil
local renderConn = nil

function Map.Start()
	-- ensure initial targets match defaults
	CurrentZoom = DefaultZoom
	TargetZoom = DefaultZoom
	CurrentCenter = MapGroundCenter
	TargetCenter = MapGroundCenter

	-- Input changed (zoom)
	inputChangedConn = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			ProcessZoom(input)
		end
	end)

	-- Input began (drag start)
	inputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			StartDrag()
		end
	end)

	-- Input ended (drag stop)
	inputEndedConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			StopDrag()
		end
	end)

	-- Render stepped to update camera smoothly
	renderConn = RunService.RenderStepped:Connect(function(dt)
		if IsOpen then
			ProcessDrag()
			UpdateCamera(dt)
		end
	end)
end

-- cleanup helper (optional)
function Map.Destroy()
	if inputChangedConn then
		inputChangedConn:Disconnect()
		inputChangedConn = nil
	end
	if inputBeganConn then
		inputBeganConn:Disconnect()
		inputBeganConn = nil
	end
	if inputEndedConn then
		inputEndedConn:Disconnect()
		inputEndedConn = nil
	end
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

return Map
