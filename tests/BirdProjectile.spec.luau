-- Run production controllers with isolated Knit/FastCast signals and temporary bird fixtures.
return function(CreateBirdHarness: () -> any, CreateProjectileHarness: (any) -> any): string
	local Harness = CreateBirdHarness()
	local Projectiles = CreateProjectileHarness(Harness.Controller)
	local Checks = 0
	local Folder = Instance.new("Folder")
	Folder.Name = "BirdProjectileValidation"
	Folder.Parent = workspace
	Harness.SetFolder(Folder)
	local Origin = Vector3.new(0, 2000, 0)

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function CreateBird(Position: Vector3, Flying: boolean?): any
		local Idle = Instance.new("Model")
		local Body = Instance.new("Part")
		Body.Size = Vector3.new(2, 1, 2)
		Body.Parent = Idle
		local Flight = Idle:Clone()
		Harness.Configure(Idle)
		Harness.Configure(Flight)
		local Model = if Flying then Flight else Idle
		Model:PivotTo(CFrame.new(Position))
		Model.Parent = Folder
		local Bird = {
			idleModel = Idle, flyingModel = Flight, model = Model,
			position = Position, velocity = Vector3.zero, direction = Vector3.zAxis,
			state = if Flying then "Flying" else "Perched", variant = if Flying then "Flying" else "Idle",
			stateEndsAt = math.huge, fleeUntil = math.huge, canLandAt = math.huge,
			target = Position + Vector3.zAxis * 100, targetExpiresAt = math.huge, speed = 30, bobPhase = 0,
		}
		table.insert(Harness.Birds, Bird)

		return Bird
	end

	local Success, Error = pcall(function()
		Check(not Harness.Controller:HitByProjectile(Origin, Vector3.xAxis, Vector3.xAxis), "Empty bird simulations must ignore projectiles")
		local Expanded = CreateBird(Origin)
		local ExpandedBody = Expanded.model:FindFirstChildWhichIsA("BasePart") :: BasePart
		Check(ExpandedBody.Size == Vector3.new(2, 1, 2), "Increasing the hitbox must preserve the visual size")
		Check(not Harness.Controller:HitByProjectile(Origin + Vector3.new(-10, 1.1, 0), Vector3.xAxis * 20, Vector3.xAxis * 2400), "Shots outside the doubled hitbox must still miss")
		Check(Harness.Controller:HitByProjectile(Origin + Vector3.new(-10, 0.75, 0), Vector3.xAxis * 20, Vector3.xAxis * 2400), "The doubled hitbox must accept shots outside the visual body")
		Harness.Clear()

		local Bird = CreateBird(Origin)
		local Start = Origin - Vector3.xAxis * 10
		local Displacement = Vector3.xAxis * 20
		local Velocity = Vector3.xAxis * 2400
		local Body = Bird.model:FindFirstChildWhichIsA("BasePart")
		Check(Body.CanQuery and not Body.CanCollide and Body.Anchored, "Birds must receive queries without affecting physics")
		Check(not Harness.Controller:HitByProjectile(Start, Vector3.zero, Velocity), "Zero-length projectile segments must be ignored")
		Check(not Harness.Controller:HitByProjectile(Start + Vector3.yAxis * 5, Displacement, Velocity), "Near misses must not knock birds down")
		Check(not Harness.Controller:HitByProjectile(Start, Vector3.xAxis * 7, Velocity), "A projectile clipped by an earlier obstacle must not hit a bird beyond it")

		Projectiles.Segment(false, Start, Displacement, Velocity)
		Check(Bird.state == "Shot", "Bow arrows must knock down perched birds")
		Harness.Clear()
		Bird = CreateBird(Origin)
		Body = Bird.model:FindFirstChildWhichIsA("BasePart")
		Projectiles.Segment(true, Start, Displacement, Velocity)
		Check(Bird.state == "Shot", "A confirmed firearm projectile must knock down a perched bird")
		Check(not Body.CanQuery and Bird.velocity.X > 0, "The fallen bird must receive an impulse and stop accepting duplicate hits")
		local Deadline = Bird.stateEndsAt
		Check(not Harness.Controller:HitByProjectile(Start, Displacement, Velocity) and Bird.stateEndsAt == Deadline, "Repeated shots must not reset the same corpse")
		Harness.Scare(Origin, workspace.DistributedGameTime)
		Check(Bird.state == "Shot", "Nearby players must not make a shot bird fly again")
		Harness.Simulate(Origin, workspace.DistributedGameTime + 0.1, 0.1)
		Check(Bird.position.Y < Origin.Y and Bird.velocity.Y < 0, "Shot birds must fall under gravity")
		Check((Bird.model:GetPivot().Position - Bird.position).Magnitude < 0.001, "Falling must update the visible model")

		local Ground = Instance.new("Part")
		Ground.Anchored = true
		Ground.Size = Vector3.new(200, 2, 200)
		Ground.Position = Origin - Vector3.yAxis * 20
		Ground.Parent = Folder.Parent
		local Landed, LandingError = pcall(function()
			for Step = 1, 30 do
				Harness.Simulate(Origin, workspace.DistributedGameTime + 0.1 + Step / 30, 1 / 30)
			end
			Check(Bird.resting and Bird.velocity == Vector3.zero, "Falling birds must stop on the ground")
			Check(Bird.position.Y > Ground.Position.Y + Ground.Size.Y / 2, "Corpses must not fall through the ground")
		end)
		Ground:Destroy()
		assert(Landed, tostring(LandingError))
		Harness.Simulate(Origin, Deadline + 0.1, 0)
		Check(#Harness.Birds == 0 and Bird.idleModel.Parent == nil and Bird.flyingModel.Parent == nil, "Expired corpses must release both variants and free a spawn slot")

		local Flying = CreateBird(Origin, true)
		local Behind = CreateBird(Origin + Vector3.xAxis * 5)
		Projectiles.Segment(false, Start, Displacement, Velocity)
		Check(Flying.state == "Shot" and Behind.state == "Perched", "Bow arrows must hit the closest bird first, including flying birds")
		Check(Harness.Controller:HitByProjectile(Start, Displacement, Vector3.zero), "A valid segment must still work without a velocity direction")
		Check(Behind.state == "Shot", "A previous corpse must not block another bird")
	end)

	Harness.Clear()
	Folder:Destroy()
	Projectiles.Destroy()
	assert(Success, tostring(Error))

	return tostring(Checks) .. " bird projectile checks passed"
end
