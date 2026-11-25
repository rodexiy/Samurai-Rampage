-- Run from a server Script in a playtest with a loaded, unmounted player.
return function(Player: Player): { [string]: any }
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Knit = require(ReplicatedStorage.Packages.Knit)
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local HorseService = Knit.GetService("HorseService")
	local HitService = Knit.GetService("HitService")
	local KickService = Knit.GetService("KickService")
	local RagdollService = Knit.GetService("RagdollService")
	local Character = assert(Player.Character, "A loaded character is required")
	local Root = assert(Character.PrimaryPart, "The character needs a root")
	assert(not Character:GetAttribute("Mounted"), "Start unmounted")
	local OriginalPivot = Character:GetPivot()
	local OriginalHealth = Character:GetAttribute("Health")
	local OriginalForceField = Character:GetAttribute("ForceField")
	local OriginalCooldown = Config.SpawnCooldown
	local Checks = 0
	local Cases = {}
	local Platform = Instance.new("Part")
	Platform.Name = "HorseHitDismountPlatform"
	Platform.Size = Vector3.new(500, 2, 500)
	Platform.CFrame = CFrame.new(20000, 2000, 20000)
	Platform.Anchored = true
	Platform.Parent = workspace
	local Attacker = Instance.new("Model")
	Attacker.Name = "HorseHitAttacker"
	Attacker:SetAttribute("IsAI", true)
	local AttackerRoot = Instance.new("Part")
	AttackerRoot.Anchored = true
	AttackerRoot.CanCollide = false
	AttackerRoot.Parent = Attacker
	Attacker.PrimaryPart = AttackerRoot
	Attacker.Parent = workspace

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Mount(Speed: number): (Model, BasePart)
		HorseService:Despawn(Player)
		Character:PivotTo(Platform.CFrame * CFrame.new(0, 5, 40))
		Root.AssemblyLinearVelocity = Vector3.zero
		Character:SetAttribute("Blocking", false)
		HorseService:Spawn(Player, 1)
		local Horse = assert(workspace.Horses:FindFirstChild("Horse_" .. Player.UserId), "Horse must spawn") :: Model
		local HorseRoot = assert(Horse.PrimaryPart, "Horse needs a root")
		Root.CFrame = HorseRoot.CFrame * CFrame.new(0, 0, 7)
		HorseService:Mount(Player, Horse)
		Check(Character:GetAttribute("Mounted") == true, "Mount before applying a hit")
		HorseRoot.AssemblyLinearVelocity = Vector3.xAxis * Speed
		AttackerRoot.CFrame = CFrame.new(Root.Position + Vector3.zAxis * 10)

		return Horse, HorseRoot
	end

	local Success, Failure = pcall(function()
		Config.SpawnCooldown = 0
		Character:SetAttribute("ForceField", false)
		for _, Case in {
			{ Name = "Melee", Speed = 40, Direction = -Vector3.zAxis },
			{ Name = "Projectile", Speed = 0, Direction = Vector3.xAxis, Ranged = true },
			{ Name = "Kick", Speed = 30, Direction = -Vector3.zAxis, Kick = true },
		} do
			local Horse, HorseRoot = Mount(Case.Speed)
			local InitialPosition = Root.Position
			local HorsePosition = HorseRoot.Position
			if Case.Kick then
				KickService:HitTarget(Attacker, Character)
			else
				Check(HitService:NormalHit(Character, Attacker, 1, {
					By = "Kick", NoStun = true, FlingOnLast = true, Ranged = Case.Ranged,
					RayCFrame = CFrame.lookAt(InitialPosition, InitialPosition + Case.Direction),
				}) == "Hit", "Resolve an actual hit")
			end

			Check(not Character:GetAttribute("Mounted") and not Character:GetAttribute("InHorse"), "Release rider attributes")
			Check(Horse:GetAttribute("RiderUserId") == nil, "Release the horse's rider")
			Check(HorseRoot:FindFirstChild("RiderWeld") == nil, "Detach before ragdoll")
			Check(Character:GetAttribute("Ragdoll") == true, "Hits ragdoll the rider")
			Check(HorseRoot:GetNetworkOwner() == nil, "Server simulates the riderless horse")
			Check(Root:GetNetworkOwner() == nil, "Server simulates the thrown rider")
			Check(Root:FindFirstChildWhichIsA("BodyVelocity") == nil, "No legacy force competes with the launch")
			local Forces = Root:QueryDescendants("LinearVelocity") :: { LinearVelocity }
			Check(#Forces == 1, "Only one force launches the rider, including kicks and last combo hits")
			local Expected = Vector3.xAxis * Case.Speed + Case.Direction * Config.HitDismount.KnockbackSpeed
				+ Vector3.yAxis * Config.HitDismount.UpwardSpeed
			Check((Forces[1].VectorVelocity - Expected).Magnitude < 0.01, "Add attack impulse to inherited horse velocity")
			Check((Root.Position - InitialPosition).Magnitude < 4, "Fall from the saddle without the normal side teleport")
			local Motor = HorseRoot:FindFirstChild("MountVelocity") :: LinearVelocity
			Check(Motor.Enabled, "The horse motor stays active after ownership changes")
			task.wait(0.5)
			Check((Root.Position - InitialPosition):Dot(Case.Direction) > 5, "The ragdoll travels in the attack direction")
			if Case.Speed > 0 then
				Check((HorseRoot.Position - HorsePosition).X > 5, "The riderless horse keeps running")
				Check(Motor.PlaneVelocity.Magnitude > 0 and Motor.PlaneVelocity.Magnitude < Case.Speed, "Gradually slow the horse")
			end
			task.wait(Case.Speed / Config.HitDismount.CoastingDeceleration + 0.5)
			Check(Motor.PlaneVelocity == Vector2.zero, "Eventually stop the riderless horse")
			Check(not Character:GetAttribute("Ragdoll"), "Recover from timed ragdoll")
			table.insert(Cases, { Name = Case.Name, LaunchVelocity = tostring(Expected), HorseTravel = (HorseRoot.Position - HorsePosition).Magnitude })
		end
	end)

	HorseService:Despawn(Player)
	if Character:GetAttribute("Ragdoll") then
		RagdollService:Unragdoll(Character)
	end
	Config.SpawnCooldown = OriginalCooldown
	Character:PivotTo(OriginalPivot)
	Character:SetAttribute("Health", OriginalHealth)
	Character:SetAttribute("ForceField", OriginalForceField)
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
	Attacker:Destroy()
	Platform:Destroy()
	assert(Success, tostring(Failure))

	return { Checks = Checks, Cases = Cases }
end
