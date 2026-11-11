-- Run on the Studio server with HorseService and an unmounted, loaded test player.
return function(Service: any, Player: Player): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local PhysicsService = game:GetService("PhysicsService")
	local Character = assert(Player.Character, "A test character is required")
	local Root = assert(Character.PrimaryPart, "The character needs a root")
	local Humanoid = assert(Character:FindFirstChildWhichIsA("Humanoid"), "The character needs a humanoid")
	assert(not Character:GetAttribute("Mounted"), "Start this suite unmounted")

	local OriginalCFrame = Root.CFrame
	local OriginalCooldown = Config.SpawnCooldown
	local OriginalAutoRotate = Humanoid.AutoRotate
	local OriginalParts: { [BasePart]: { boolean } } = {}
	for _, Part in Character:QueryDescendants("BasePart") :: { BasePart } do
		OriginalParts[Part] = { Part.CanCollide, Part.Massless }
	end

	local Platform = Instance.new("Part")
	Platform.Name = "HorseTestPlatform"
	Platform.Anchored = true
	Platform.Size = Vector3.new(220, 2, 220)
	Platform.Position = Vector3.new(0, 2000, 0)
	Platform.Parent = workspace

	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		Service:Despawn(Player)
		Root.CFrame = CFrame.new(0, 2005, 40)
		Config.SpawnCooldown = 0

		local Previous: Model? = nil
		for Tier = 1, 5 do
			Service:Spawn(Player, Tier)
			local Horse = workspace.Horses:FindFirstChild("Horse_" .. Player.UserId) :: Model?
			Check(Horse ~= nil, "Spawn tier " .. Tier)
			Check(Horse:GetAttribute("HorseTier") == Tier, "The server chooses the tier")
			Check(Horse:GetAttribute("OwnerUserId") == Player.UserId, "The server assigns the owner")
			Check(Horse.PrimaryPart:GetNetworkOwner() == nil, "Unmounted horses stay server-owned")
			Check(Horse.PrimaryPart.CFrame.UpVector:Dot(Vector3.yAxis) > 0.99, "Imported rigs remain upright")
			Check(Horse.PrimaryPart.CollisionGroup == Config.Grounding.CollisionGroup, "Use selective horse collision")
			Check(not PhysicsService:CollisionGroupsAreCollidable(Horse.PrimaryPart.CollisionGroup, "Default"), "The horse does not physically collide with the floor")
			Check(PhysicsService:CollisionGroupsAreCollidable(Horse.PrimaryPart.CollisionGroup, "Entity"), "The horse still collides with characters")
			Check(Horse:FindFirstChild("GroundCollider", true) == nil, "Ground collider spheres are removed")
			if Previous then
				Check(Previous.Parent == nil, "Recalling replaces the previous horse")
			end
			Previous = Horse
		end

		local Horse = assert(Previous, "The horse must have spawned")
		local HorseRoot = assert(Horse.PrimaryPart, "The horse needs a root")
		Config.SpawnCooldown = OriginalCooldown
		Service:Spawn(Player)
		Check(Horse.Parent ~= nil, "Spawn requests are rate limited")

		local OtherPlayer: any = { UserId = Player.UserId + 1, Character = Character }
		Service:Mount(OtherPlayer, Horse)
		Check(Horse:GetAttribute("RiderUserId") == nil, "A non-owner cannot mount")

		Root.CFrame = HorseRoot.CFrame * CFrame.new(0, 0, 50)
		Service:Mount(Player, Horse)
		Check(Horse:GetAttribute("RiderUserId") == nil, "The owner cannot mount from outside prompt range")

		Root.CFrame = HorseRoot.CFrame * CFrame.new(0, 0, 7)
		Service:Mount(Player, Horse)
		Check(Character:GetAttribute("Mounted") == true and Humanoid.PlatformStand, "Mounting suspends character movement")
		Check(Horse:GetAttribute("RiderUserId") == Player.UserId, "The owner becomes the rider")
		Check(HorseRoot:GetNetworkOwner() == Player, "The rider simulates the horse physics")
		Check(HorseRoot:FindFirstChild("RiderWeld") ~= nil, "The rider is physically attached")
		local RiderJoint = HorseRoot:FindFirstChild("RiderWeld") :: Weld
		Check(RiderJoint:IsA("Weld") and RiderJoint.C0 == Config.RiderOffset, "The rider attachment supports local saddle animation")
		Check(HorseRoot.AssemblyRootPart == HorseRoot, "The mount remains the physical assembly root while carrying the rider")
		for _, Direction in { "invalid", Vector3.zero, Vector3.new(math.huge, 0, 0), Vector3.new(0 / 0, 0, -1) } do
			Service:UpdateRiderLook(Player, Direction)
			Check(Horse:GetAttribute("RiderLookDirection") == nil, "Reject malformed rider gaze")
		end
		Service:UpdateRiderLook(OtherPlayer, -Vector3.zAxis)
		Check(Horse:GetAttribute("RiderLookDirection") == nil, "A different player cannot control this horse's gaze")
		local Direction = Vector3.new(0.5, 0.2, -1).Unit
		Service:UpdateRiderLook(Player, Direction)
		Check(Horse:GetAttribute("RiderLookDirection"):Dot(Direction) > 0.999, "Replicate the mounted owner's valid gaze")
		Service:UpdateRiderLook(Player, Vector3.xAxis)
		Check(Horse:GetAttribute("RiderLookDirection"):Dot(Direction) > 0.999, "Rate-limit gaze packets")

		Service:Dismount(Player)
		Check(Horse:GetAttribute("RiderLookDirection") == nil and Horse:GetAttribute("RiderLookTime") == nil, "Dismount releases the rider's gaze")
		Check(not Character:GetAttribute("Mounted") and not Humanoid.PlatformStand, "Dismount restores character movement")
		Check(Humanoid.AutoRotate == OriginalAutoRotate, "Dismount restores rotation")
		Check(HorseRoot:GetNetworkOwner() == nil, "Dismount returns physics ownership to the server")
		Check(HorseRoot:FindFirstChild("RiderWeld") == nil, "Dismount removes the rider weld")
		for Part, Values in OriginalParts do
			Check(Part.CanCollide == Values[1] and Part.Massless == Values[2], "Restore physics for " .. Part.Name)
		end

		Root.CFrame = HorseRoot.CFrame * CFrame.new(0, 0, 7)
		Service:Mount(Player, Horse)
		Service:Despawn(Player)
		Check(Horse.Parent == nil and not Character:GetAttribute("Mounted"), "Despawning a mounted horse releases the rider")
	end)

	Service:Despawn(Player)
	Config.SpawnCooldown = OriginalCooldown
	Root.CFrame = OriginalCFrame
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
	Platform:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseService: %d checks passed", Checks)
end
