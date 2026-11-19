return function(CreateService: (any) -> any, CreateRaycast: (any) -> any): string
	local Checks = 0
	local Folder = Instance.new("Folder")
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Character(Name: string): (Model, BasePart)
		local Model = Instance.new("Model")
		Model.Name = Name
		Model:SetAttribute("Health", 100)
		local Body = Instance.new("Part")
		Body.Anchored = true
		Body.Parent = Model
		local Humanoid = Instance.new("Humanoid")
		Humanoid.Parent = Model
		Model.Parent = Folder

		return Model, Body
	end
	local Attacker, AttackerBody = Character("Shooter")
	local Defender, DefenderBody = Character("Defender")
	local Other, OtherBody = Character("Other")
	local DefenderPlayer = {}
	local Owners = { [Defender] = DefenderPlayer }
	local Players = { GetPlayerFromCharacter = function(_Self: any, Model: Model): any
		return Owners[Model]
	end }
	local Casts, Messages, Hits = {}, {}, {}
	local Caster = { Fire = function(_Self: any, Origin: Vector3, Direction: Vector3, Velocity: Vector3, Behavior: any): any
		local Cast = { Origin = Origin, Direction = Direction, Velocity = Velocity, Behavior = Behavior, UserData = {} }
		table.insert(Casts, Cast)
		return Cast
	end }
	local Raycast = CreateRaycast(Players)
	local Service = CreateService({
		Players = Players, Raycast = Raycast, Caster = Caster,
		Projectile = { FireAll = function(_Self: any, ...: any)
			table.insert(Messages, table.pack(...))
		end },
		HitService = { NormalHit = function(_Self: any, Target: Model, Source: Model): string
			table.insert(Hits, { Target = Target, Source = Source })
			return Target:GetAttribute("Response") or "Hit"
		end },
	})
	local function Shot(Firearm: boolean?): any
		return { UserData = {
			Id = 1000, Character = Attacker, Origin = Vector3.zAxis * 10, Charge = 1,
			ExpiresAt = workspace:GetServerTimeNow() + 5,
			Config = { IsFirearm = Firearm == true, WeaponName = if Firearm then "Tanegashima" else "Bow",
				MaxDistance = 2000, MaxFlightTime = 8, GetDamage = function(): number return 35 end },
		} }
	end
	local function Impact(Body: BasePart): any
		return { Instance = Body, Position = Vector3.zero, Normal = Vector3.zAxis, Material = Enum.Material.Plastic }
	end
	local Velocity = -Vector3.zAxis * 300
	local Success, Error = pcall(function()
		Defender:SetAttribute("Response", "Deflect")
		Service:HandleProjectileHit(Shot(), Impact(DefenderBody), Velocity)
		local Deflected = Casts[#Casts]
		Check(#Casts == 1 and Messages[#Messages][1] == "Deflect", "Parry redirects the arrow instead of sticking it into the defender")
		Check(Deflected.UserData.Character == Defender and not Deflected.UserData.Harmless, "Parry transfers the damaging projectile to the deflector")
		Check(math.abs(Deflected.Velocity.Magnitude - Velocity.Magnitude) < 0.001 and Deflected.Direction:Dot(Vector3.zAxis) >= 0,
			"Parry retains speed while sending the arrow away in a randomized direction")
		Check(table.find(Deflected.Behavior.RaycastParams.FilterDescendantsInstances, Defender) ~= nil,
			"Exclude the deflector from the authoritative raycast")
		Check(Raycast.CanPierce(Deflected, Impact(DefenderBody), Velocity), "A parried arrow passes through its deflector")
		local Before = #Hits
		Service:HandleProjectileHit(Deflected, Impact(DefenderBody), Velocity)
		Check(#Hits == Before, "Even a direct hit callback cannot damage its protected deflector")
		Service:HandleProjectileHit(Deflected, Impact(AttackerBody), Velocity)
		Check(#Hits == Before + 1 and Hits[#Hits].Target == Attacker, "A parried arrow can hit the original shooter")
		Service:HandleProjectileHit(Deflected, Impact(OtherBody), Velocity)
		Check(Hits[#Hits].Source == Defender, "Damage is attributed to the deflector")
		local Respawned, RespawnedBody = Character("RespawnedDefender")
		Owners[Respawned] = DefenderPlayer
		Check(Raycast.CanPierce(Deflected, Impact(RespawnedBody), Velocity), "Deflector immunity survives a character replacement")
		Other:SetAttribute("Response", "Deflect")
		Service:HandleProjectileHit(Deflected, Impact(OtherBody), Velocity)
		local Twice = Casts[#Casts]
		Check(Raycast.CanPierce(Twice, Impact(DefenderBody), Velocity) and Raycast.CanPierce(Twice, Impact(OtherBody), Velocity),
			"Successive parries preserve immunity for every deflector")
		Check(Twice.Behavior.MaxDistance < Deflected.Behavior.MaxDistance and Twice.UserData.ExpiresAt <= Deflected.UserData.ExpiresAt + 0.001,
			"Deflections do not reset the arrow's distance or lifetime budget")
		Defender:SetAttribute("Response", "Block")
		Service:HandleProjectileHit(Shot(), Impact(DefenderBody), Velocity)
		local Blocked = Casts[#Casts]
		Check(Blocked.UserData.Harmless and Blocked.Velocity.Y < 0 and Blocked.Velocity.X == 0 and Blocked.Velocity.Z == 0,
			"Blocking redirects the arrow straight toward the floor")
		for _, Body in { DefenderBody, AttackerBody, OtherBody } do
			Check(Raycast.CanPierce(Blocked, Impact(Body), Velocity), "A blocked arrow cannot collide with any character")
			Before = #Hits
			Service:HandleProjectileHit(Blocked, Impact(Body), Velocity)
			Check(#Hits == Before, "A blocked arrow cannot damage any character")
		end
		Check(not Service:DeflectProjectile(Blocked, Impact(OtherBody), Velocity, Other, "Deflect"), "A harmless arrow cannot become damaging again")
		local Floor = Instance.new("Part")
		Floor.Anchored = true
		Floor.CanCollide = true
		Floor.Parent = Folder
		Check(not Raycast.CanPierce(Blocked, Impact(Floor), Velocity), "Blocked arrows still collide with the environment")
		local Count = #Casts
		Service:HandleProjectileHit(Shot(true), Impact(DefenderBody), Velocity)
		Check(#Casts == Count and Messages[#Messages][1] == "Hit", "Firearm projectiles keep their existing impact behavior")
		local Expired = Shot()
		Expired.UserData.ExpiresAt = workspace:GetServerTimeNow() - 1
		Check(not Service:DeflectProjectile(Expired, Impact(DefenderBody), Velocity, Defender, "Deflect"), "An expired arrow cannot be restarted by a parry")
		local PreviousDirection = Deflected.Direction
		local Varied = false
		for _ = 1, 8 do
			Service:DeflectProjectile(Shot(), Impact(DefenderBody), Velocity, Defender, "Deflect")
			Varied = Varied or (Casts[#Casts].Direction - PreviousDirection).Magnitude > 0.01
		end
		Check(Varied, "Parries choose different random outgoing directions")
	end)
	Folder:Destroy()
	assert(Success, tostring(Error))

	return tostring(Checks) .. " arrow deflection checks passed"
end
