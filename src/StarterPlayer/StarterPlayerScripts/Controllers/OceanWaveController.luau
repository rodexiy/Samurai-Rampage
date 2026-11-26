local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WaveFunction = require(ReplicatedStorage.Shared.WaveFunction)

local OceanWaveController = {}
local GRID_SIZE = 512
local CHUNK_SIZE = 128
local VISIBILITY_INTERVAL = 0.25
local FULL_RATE_DISTANCE = 256
local DISTANT_INTERVAL = 1 / 15
-- Spread occlusion raycasts over frames instead of producing a periodic spike.
local CHUNKS_PER_STEP = 16
-- Include adjacent vertices and the wave displacement in visibility bounds.
local VISIBILITY_MARGIN = 64
local WAVE_HEIGHT_MARGIN = 16

type BoneData = { Bone: Bone, RestPosition: Vector3 }
type Chunk = { Min: Vector3, Max: Vector3, Indices: { number } }
type Sampler = (number, { number }?, Vector3?) -> { Vector3 }

local function GetGridCenter(Position: Vector3): Vector3
	return Vector3.new(math.round(Position.X / GRID_SIZE) * GRID_SIZE, 0, math.round(Position.Z / GRID_SIZE) * GRID_SIZE)
end

local function IsInView(Camera: Camera, Center: Vector3, Radius: number): boolean
	local Local = Camera.CFrame:PointToObjectSpace(Center)
	local Depth = -Local.Z
	local Vertical = math.tan(math.rad(Camera.FieldOfView) / 2)
	local Horizontal = Vertical * Camera.ViewportSize.X / math.max(Camera.ViewportSize.Y, 1)

	return Depth + Radius > 0
		and math.abs(Local.X) <= Depth * Horizontal + Radius * math.sqrt(1 + Horizontal * Horizontal)
		and math.abs(Local.Y) <= Depth * Vertical + Radius * math.sqrt(1 + Vertical * Vertical)
end

local function IsUnobstructed(Origin: Vector3, Target: Vector3, Params: RaycastParams, Excluded: { Instance }): boolean
	local Direction = Target - Origin
	if Direction.Magnitude < 1 then
		return true
	end

	Params.FilterDescendantsInstances = Excluded
	local Skipped: { Instance }?
	for _ = 1, 4 do
		local Hit = workspace:Raycast(Origin, Direction, Params)
		if not Hit then
			return true
		end
		if not Hit.Instance:IsA("BasePart") or Hit.Instance.Transparency == 0 then
			return false
		end

		-- Glass and invisible trigger volumes must not hide the ocean animation.
		Skipped = Skipped or table.clone(Excluded)
		table.insert(Skipped, Hit.Instance)
		Params.FilterDescendantsInstances = Skipped
	end

	return true
end

local function IsChunkVisible(Chunk: Chunk, Surface: BasePart, Camera: Camera, Params: RaycastParams, Excluded: { Instance }): boolean
	local Center = (Chunk.Min + Chunk.Max) * 0.5
	local Radius = (Chunk.Max - Chunk.Min).Magnitude * 0.5 + VISIBILITY_MARGIN
	if not IsInView(Camera, Surface.CFrame:PointToWorldSpace(Center), Radius) then
		return false
	end

	local Origin = Camera.CFrame.Position
	local RaisedCenter = Center + Vector3.yAxis * WAVE_HEIGHT_MARGIN
	if IsUnobstructed(Origin, Surface.CFrame:PointToWorldSpace(RaisedCenter), Params, Excluded) then
		return true
	end

	for _, X in { Chunk.Min.X - VISIBILITY_MARGIN, Chunk.Max.X + VISIBILITY_MARGIN } do
		for _, Z in { Chunk.Min.Z - VISIBILITY_MARGIN, Chunk.Max.Z + VISIBILITY_MARGIN } do
			local Target = Surface.CFrame:PointToWorldSpace(Vector3.new(X, RaisedCenter.Y, Z))
			if IsUnobstructed(Origin, Target, Params, Excluded) then
				return true
			end
		end
	end

	return false
end

function OceanWaveController.Start(Character: Model): () -> ()
	local Player = Players.LocalPlayer
	local Root = Character.PrimaryPart
	assert(Root, "Character must have a PrimaryPart")
	local Ocean = (ReplicatedFirst:WaitForChild("Ocean") :: Model):Clone()
	local Surface = Ocean:WaitForChild("HighQuality") :: BasePart
	assert(Surface:IsA("BasePart"), "Ocean.HighQuality must be a BasePart")
	local Center = GetGridCenter(Root.Position)
	Ocean:PivotTo(CFrame.new(Center))
	Ocean.Parent = workspace

	local Bones: { BoneData } = {}
	local Positions: { Vector3 } = {}
	local Chunks: { [Vector3]: Chunk } = {}
	for _, Bone in Surface:QueryDescendants("Bone") :: { Bone } do
		local Position = Surface.CFrame:PointToObjectSpace(Bone.WorldPosition)
		table.insert(Bones, { Bone = Bone, RestPosition = Position })
		table.insert(Positions, Bone.WorldPosition)
		local Key = Vector3.new(math.floor(Position.X / CHUNK_SIZE), 0, math.floor(Position.Z / CHUNK_SIZE))
		local Chunk = Chunks[Key]
		if not Chunk then
			Chunk = { Min = Position, Max = Position, Indices = {} }
			Chunks[Key] = Chunk
		end
		Chunk.Min = Chunk.Min:Min(Position)
		Chunk.Max = Chunk.Max:Max(Position)
		table.insert(Chunk.Indices, #Bones)
	end

	local SampleOrigin = Center
	local Sample: Sampler?
	local Near: { number } = {}
	local Far: { number } = {}
	local PendingNear: { number } = {}
	local PendingFar: { number } = {}
	local ChunkList: { Chunk } = {}
	for _, Chunk in Chunks do
		table.insert(ChunkList, Chunk)
	end
	local ScanIndex = 0
	local Applied: { [number]: boolean } = {}
	local Params = RaycastParams.new()
	Params.IgnoreWater = true
	Params.FilterType = Enum.RaycastFilterType.Exclude
	local Excluded: { Instance } = { Ocean, Character }
	local VFX = workspace:FindFirstChild("VFX")
	if VFX then
		table.insert(Excluded, VFX)
	end

	local Enabled = Player:GetAttribute("Waves") ~= false
	local Elapsed = VISIBILITY_INTERVAL
	local FarElapsed = DISTANT_INTERVAL
	local LastView: CFrame?
	local RenderConnection: RBXScriptConnection?
	local HeartbeatConnection: RBXScriptConnection?
	local RemovingConnection: RBXScriptConnection?
	local SettingConnection: RBXScriptConnection?
	local CleanedUp = false

	local function StopRendering()
		if RenderConnection then
			RenderConnection:Disconnect()
			RenderConnection = nil
		end
	end

	local function Apply(Indices: { number }, Time: number)
		if #Indices == 0 then
			return
		end

		debug.profilebegin("OceanWaves.Sample")
		local Sampler = Sample
		if not Sampler then
			Sampler = WaveFunction:CreateDisplacementSampler(Positions)
			Sample = Sampler
		end
		local Displacements = Sampler(Time, Indices, Center - SampleOrigin)
		debug.profileend()

		debug.profilebegin("OceanWaves.Apply")
		local Frame = Surface.CFrame
		for _, Index in Indices do
			Bones[Index].Bone.Transform = CFrame.new(Frame:VectorToObjectSpace(Displacements[Index]))
			Applied[Index] = true
		end
		debug.profileend()
	end

	local function Render(DeltaTime: number)
		debug.profilebegin("OceanWaves.Update")
		local Time = workspace:GetServerTimeNow()
		Apply(Near, Time)
		FarElapsed += DeltaTime
		if FarElapsed >= DISTANT_INTERVAL then
			FarElapsed %= DISTANT_INTERVAL
			Apply(Far, Time)
		end
		debug.profileend()
	end

	local function StartVisibilityScan()
		table.clear(PendingNear)
		table.clear(PendingFar)
		local Camera = workspace.CurrentCamera
		LastView = if Camera then Camera.CFrame else nil
		ScanIndex = 1
	end

	local function StepVisibility()
		debug.profilebegin("OceanWaves.Visibility")
		local Camera = workspace.CurrentCamera
		if Enabled and Camera and Surface.Transparency < 1 and Surface:IsDescendantOf(workspace) then
			local LastIndex = math.min(ScanIndex + CHUNKS_PER_STEP - 1, #ChunkList)
			for ChunkIndex = ScanIndex, LastIndex do
				local Chunk = ChunkList[ChunkIndex]
				if IsChunkVisible(Chunk, Surface, Camera, Params, Excluded) then
					for _, Index in Chunk.Indices do
						local Position = Surface.CFrame:PointToWorldSpace(Bones[Index].RestPosition)
						local Target = if (Position - Camera.CFrame.Position).Magnitude <= FULL_RATE_DISTANCE then PendingNear else PendingFar
						table.insert(Target, Index)
					end
				end
			end
			ScanIndex = LastIndex + 1
		else
			table.clear(PendingNear)
			table.clear(PendingFar)
			ScanIndex = #ChunkList + 1
		end

		if ScanIndex <= #ChunkList then
			debug.profileend()
			return
		end

		Near, PendingNear = PendingNear, Near
		Far, PendingFar = PendingFar, Far
		ScanIndex = 0
		FarElapsed = DISTANT_INTERVAL
		if #Near + #Far > 0 then
			if not RenderConnection then
				RenderConnection = RunService.RenderStepped:Connect(Render)
			end
		else
			StopRendering()
		end
		debug.profileend()
	end

	local function UpdateSetting()
		Enabled = Player:GetAttribute("Waves") ~= false
		if not Enabled then
			StopRendering()
			ScanIndex = 0
			table.clear(Near)
			table.clear(Far)
			for Index in Applied do
				Bones[Index].Bone.Transform = CFrame.identity
			end
			table.clear(Applied)
		end
		Elapsed = VISIBILITY_INTERVAL
	end

	local function Cleanup()
		if CleanedUp then
			return
		end

		CleanedUp = true
		StopRendering()
		if HeartbeatConnection then
			HeartbeatConnection:Disconnect()
		end
		if RemovingConnection then
			RemovingConnection:Disconnect()
		end
		if SettingConnection then
			SettingConnection:Disconnect()
		end
		Ocean:Destroy()
	end

	HeartbeatConnection = RunService.Heartbeat:Connect(function(DeltaTime: number)
		if not Root.Parent or not Ocean.Parent then
			Cleanup()
			return
		end

		Elapsed += DeltaTime
		local Camera = workspace.CurrentCamera
		local Turned = Enabled and Camera and LastView and Camera.CFrame.LookVector:Dot(LastView.LookVector) < math.cos(math.rad(12))
		if Elapsed >= VISIBILITY_INTERVAL or Turned then
			Elapsed = 0
			local NextCenter = GetGridCenter(Root.Position)
			local Recentered = NextCenter ~= Center
			if Recentered then
				Center = NextCenter
				Ocean:PivotTo(CFrame.new(Center))
			end

			-- Finish an in-flight scan during camera turns so continuous rotation
			-- cannot keep restarting the scan before any new selection is applied.
			if ScanIndex == 0 or Recentered then
				StartVisibilityScan()
			end
		end
		if ScanIndex > 0 then
			StepVisibility()
		end
	end)
	SettingConnection = Player:GetAttributeChangedSignal("Waves"):Connect(UpdateSetting)
	RemovingConnection = Player.CharacterRemoving:Connect(function(Removing: Model)
		if Removing == Character then
			Cleanup()
		end
	end)
	UpdateSetting()

	return Cleanup
end

return OceanWaveController
