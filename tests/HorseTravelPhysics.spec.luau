-- Run on the Studio server. Exercise actual moving physics, not only static ramps.
return function(Service: any, Player: Player): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Character = assert(Player.Character, "A test character is required")
	local CharacterRoot = assert(Character.PrimaryPart, "A character root is required")
	local OriginalFrame = CharacterRoot.CFrame
	local OriginalAnchored = CharacterRoot.Anchored
	local Cooldown = Config.SpawnCooldown
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseTravelPhysicsTests"
	Fixture.Parent = workspace
	local BaseY = 3000
	local Pitch = math.rad(30)
	local Rise = 30 * math.tan(Pitch)
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Platform(Name: string, Center: Vector3, Length: number, Width: number, Angle: number): Part
		local Part = Instance.new("Part")
		Part.Name = Name
		Part.Anchored = true
		Part.Size = Vector3.new(Width, 1, Length / math.cos(Angle))
		Part.CFrame = CFrame.new(Center) * CFrame.Angles(Angle, 0, 0) * CFrame.new(0, -0.5, 0)
		Part.Parent = Fixture

		return Part
	end

	Platform("Start", Vector3.new(0, BaseY, 27.5), 55, 14, 0)
	Platform("Ramp", Vector3.new(0, BaseY + Rise * 0.5, -15), 30, 14, Pitch)
	Platform("Crest", Vector3.new(0, BaseY + Rise, -40), 20, 14, 0)
	Platform("Landing", Vector3.new(0, BaseY, -75), 20, 14, 0)
	Platform("NarrowBridge", Vector3.new(0, BaseY, -100), 30, 1.2, 0)
	Platform("Exit", Vector3.new(0, BaseY, -147.5), 65, 14, 0)
	Platform("Overhead", Vector3.new(0, BaseY + 6, 16), 12, 14, 0)

	local function SurfaceHeight(Z: number): number?
		if Z >= 0 then
			return BaseY
		elseif Z >= -30 then
			return BaseY - Z * math.tan(Pitch)
		elseif Z >= -50 then
			return BaseY + Rise
		elseif Z >= -65 then
			return nil
		end

		return BaseY
	end

	local function Advance(Duration: number, Sample: (() -> ())?)
		local Done = Instance.new("BindableEvent")
		local Elapsed = 0
		local Failure: string? = nil
		local Connection: RBXScriptConnection
		Connection = RunService.PostSimulation:Connect(function(DeltaTime: number)
			if Sample then
				local Success, Error = pcall(Sample)
				if not Success then
					Failure = tostring(Error)
				end
			end
			Elapsed += DeltaTime
			if Failure or Elapsed >= Duration then
				Connection:Disconnect()
				Done:Fire()
			end
		end)
		Done.Event:Wait()
		Done:Destroy()
		assert(not Failure, tostring(Failure))
	end

	local Success, Error = pcall(function()
		Service:Despawn(Player)
		Config.SpawnCooldown = 0
		CharacterRoot.CFrame = CFrame.new(0, BaseY + 5, 45)
		Service:Spawn(Player, 5)
		CharacterRoot.Anchored = true
		local Horse = workspace.Horses:FindFirstChild("Horse_" .. Player.UserId) :: Model?
		Check(Horse ~= nil, "Spawn the travel fixture")
		local Root = assert(Horse.PrimaryPart, "The horse needs a root")
		local Clearance = Horse:GetAttribute("GroundClearance")
		local Velocity = Root:FindFirstChild("MountVelocity") :: LinearVelocity
		local Vertical = Root:FindFirstChild("MountGroundVelocity") :: LinearVelocity
		Advance(0.4, nil)
		Velocity.PlaneVelocity = Vector2.new(0, -56)
		local LowestFeet = math.huge
		local PeakRise = 0
		local PeakGapRise = 0
		local RoofHeight = 0
		local NarrowSamples, GapSamples, RoofSamples = 0, 0, 0
		Advance(3.25, function()
			local Feet = Root.Position - Root.CFrame.UpVector * Clearance
			local Height = SurfaceHeight(Feet.Z)
			if Height then
				LowestFeet = math.min(LowestFeet, Feet.Y - Height)
			end
			PeakRise = math.max(PeakRise, Root.AssemblyLinearVelocity.Y)
			if Feet.Z < -52 and Feet.Z > -63 then
				PeakGapRise = math.max(PeakGapRise, Root.AssemblyLinearVelocity.Y)
				GapSamples += 1
			end
			if Feet.Z < -87 and Feet.Z > -113 then
				NarrowSamples += 1
			end
			if Feet.Z < 22 and Feet.Z > 10 then
				RoofHeight = math.max(RoofHeight, Root.Position.Y - BaseY)
				RoofSamples += 1
			end
		end)
		Check(Root.Position.Z < -125 and NarrowSamples > 5 and GapSamples > 2 and RoofSamples > 2,
			"Actually traverse the roof, hill, crest, gap and narrow bridge")
		Check(LowestFeet > -0.6, "Do not penetrate the floor while travelling: " .. LowestFeet)
		Check(RoofHeight < Clearance + 1, "Do not climb an overhead surface: " .. RoofHeight)
		Check(PeakRise < 55, "Do not generate excessive upward speed: " .. PeakRise)
		Check(PeakGapRise <= Config.Grounding.MaximumReleaseSpeed + 2, "Do not launch off the crest: " .. PeakGapRise)
		Check(Vertical.ForceLimitsEnabled and Vertical.MaxForce < math.huge, "Use bounded suspension force in live physics")

		Velocity.PlaneVelocity = Vector2.zero
		Advance(0.5, nil)
		Root.CFrame -= Vector3.yAxis * 10
		Root.AssemblyLinearVelocity = Vector3.new(0, -30, 0)
		Advance(0.15, nil)
		Check(Root.Position.Y >= BaseY + Clearance - 0.25, "Recover actual buried physics without getting stuck")
		Check(Root.AssemblyLinearVelocity.Y < 5, "Recovery does not fling the physical horse")
	end)

	Service:Despawn(Player)
	CharacterRoot.CFrame = OriginalFrame
	CharacterRoot.AssemblyLinearVelocity = Vector3.zero
	CharacterRoot.AssemblyAngularVelocity = Vector3.zero
	CharacterRoot.Anchored = OriginalAnchored
	Config.SpawnCooldown = Cooldown
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseTravelPhysics: %d checks passed", Checks)
end
