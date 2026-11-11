-- Integration suite: run on a Studio server with a loaded test player.
return function(Service: any, Player: Player): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Grounding = require(ReplicatedStorage.Shared.HorseGrounding)
	local Character = assert(Player.Character, "A test character is required")
	local CharacterRoot = assert(Character.PrimaryPart, "A character root is required")
	local OriginalFrame = CharacterRoot.CFrame
	local OriginalAnchored = CharacterRoot.Anchored
	local Cooldown = Config.SpawnCooldown
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Advance(Duration: number)
		local Done = Instance.new("BindableEvent")
		local Elapsed = 0
		local Connection: RBXScriptConnection
		Connection = RunService.PostSimulation:Connect(function(DeltaTime: number)
			Elapsed += DeltaTime
			if Elapsed >= Duration then
				Connection:Disconnect()
				Done:Fire()
			end
		end)
		Done.Event:Wait()
		Done:Destroy()
	end

	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorsePhysicsTests"
	Fixture.Parent = workspace
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(200, 2, 200)
	Floor.CFrame = CFrame.new(0, 2499, 0)
	Floor.Parent = Fixture

	local Success, Error = pcall(function()
		Service:Despawn(Player)
		CharacterRoot.CFrame = CFrame.new(0, 2505, 40)
		Config.SpawnCooldown = 0
		Service:Spawn(Player)
		CharacterRoot.Anchored = true
		local Horse = workspace.Horses:FindFirstChild("Horse_" .. Player.UserId) :: Model?
		Check(Horse ~= nil, "Spawn a physical test mount")
		local Root = assert(Horse.PrimaryPart, "The horse needs a root")
		local Clearance = Horse:GetAttribute("GroundClearance")
		Advance(0.8)
		Check(math.abs(Root.Position.Y - 2500 - Clearance) < 0.2, "Raycast suspension settles without floor collision")
		Check(Root.AssemblyLinearVelocity.Magnitude < 1, "An idle mount remains stable")

		Floor.CFrame = CFrame.new(Root.Position.X, 2499, Root.Position.Z) * CFrame.Angles(math.rad(35), 0, 0)
		Advance(1.2)
		local Normal = Floor.CFrame.UpVector
		local Point = Floor.CFrame:PointToWorldSpace(Vector3.yAxis)
		local Height = Grounding.GetHeight(Root.Position, Point, Normal, Clearance)
		Check(Root.CFrame.UpVector:Dot(Normal) > 0.99, "The physical mount leans with a 35-degree hill")
		Check(math.abs(Root.Position.Y - Height) < 0.25, "Maintain clearance on a steep slope")

		CharacterRoot.CFrame = Root.CFrame * CFrame.new(0, 0, 7)
		CharacterRoot.Anchored = false
		Service:Mount(Player, Horse)
		Check(Character:GetAttribute("Mounted") == true, "Mount the inclined horse")
		Advance(1.2)
		Check(Root:GetNetworkOwner() == Player, "The rider owns the inclined mount simulation")
		Check(CharacterRoot.CFrame.UpVector:Dot(Root.CFrame.UpVector) > 0.999, "The actual rider follows the horse tilt")
		Check((Root.CFrame:ToObjectSpace(CharacterRoot.CFrame).Position - Config.RiderOffset.Position).Magnitude < 0.1,
			"The rider remains attached to the saddle while tilted")

		Service:Dismount(Player)
		CharacterRoot.Anchored = true
		Check(CharacterRoot.CFrame.UpVector:Dot(Vector3.yAxis) > 0.999, "Dismount leaves the character upright")
		Check(Root:GetNetworkOwner() == nil, "Return suspension simulation to the server")

		local Proxy = Instance.new("Part")
		Proxy.Name = "CharacterCollisionProbe"
		Proxy.Size = Vector3.new(2, 4, 2)
		Proxy.CollisionGroup = "Entity"
		Proxy.CFrame = CFrame.new(Root.Position + Vector3.xAxis * (Root.Size.X * 0.5 + 3))
		Proxy.Parent = Fixture
		Proxy:SetNetworkOwner(nil)
		Proxy.AssemblyLinearVelocity = -Vector3.xAxis * 12
		Advance(0.3)
		Check(Proxy.Position.X - Root.Position.X > Root.Size.X * 0.5, "Character collision still blocks passage through the horse")
		Proxy:Destroy()

		local Before = Root.Position.Y
		Floor:Destroy()
		Advance(0.25)
		local Vertical = Root:FindFirstChild("MountGroundVelocity") :: LinearVelocity
		Check(not Vertical.Enabled, "Release suspension when the ground disappears")
		Check(Root.AssemblyLinearVelocity.Y < -20 and Root.Position.Y < Before - 1,
			"The physical horse falls under gravity without a floor")
	end)

	Service:Despawn(Player)
	CharacterRoot.CFrame = OriginalFrame
	CharacterRoot.AssemblyLinearVelocity = Vector3.zero
	CharacterRoot.AssemblyAngularVelocity = Vector3.zero
	CharacterRoot.Anchored = OriginalAnchored
	Config.SpawnCooldown = Cooldown
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorsePhysics: %d checks passed", Checks)
end
