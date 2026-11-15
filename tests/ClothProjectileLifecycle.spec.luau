-- Run in Studio's Edit context, passing the production BowProjectileController source.
return function(ProductionSource: string): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Checks = 0
	local Player = { Character = nil }
	local Containers: { [Instance]: boolean } = {}
	local function Signal(): any
		local Callbacks = {}
		local Event = {}
		function Event:Connect(Callback: any): any
			table.insert(Callbacks, Callback)
			return { Disconnect = function() end }
		end
		function Event:Fire(...: any)
			for _, Callback in Callbacks do
				Callback(...)
			end
		end
		return Event
	end

	local TraceCalls = {}
	local Caster = { LengthChanged = Signal(), CastTerminating = Signal() }
	local Casts: { [number]: any } = {}
	local NextCast = 0
	function Caster:Fire(_Origin: Vector3, _Direction: Vector3, _Velocity: Vector3, Behavior: any): any
		local Bullet = Behavior.CosmeticBulletTemplate:Clone()
		Bullet.Parent = Behavior.CosmeticBulletContainer
		local Cast = { UserData = {}, RayInfo = { CosmeticBulletObject = Bullet } }
		function Cast.Terminate(ActiveCast: any)
			Caster.CastTerminating:Fire(ActiveCast)
		end
		NextCast += 1
		Casts[NextCast] = Cast
		return Cast
	end

	local Projectile = Signal()
	local Dependencies = {
		Players = { LocalPlayer = Player },
		FastCast = {
			new = function(): any
				return Caster
			end,
			newBehavior = function(): any
				return {}
			end,
		},
		Knit = {
			CreateController = function(Controller: any): any return Controller end,
			GetService = function(_Name: string): any return { Projectile = Projectile } end,
			GetController = function(Name: string): any
				return {
					HitByProjectile = function(_Self: any, Origin: Vector3, Displacement: Vector3, IsFirearm: any, _Hits: any): boolean
						if Name == "ClothController" then
							table.insert(TraceCalls, { Origin = Origin, Displacement = Displacement, IsFirearm = IsFirearm })
						end
						return false
					end,
				}
			end,
		},
	}
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Source = string.gsub(ProductionSource, "local Knit = require%(ReplicatedStorage%.Packages%.Knit%)", "local Knit = Dependencies.Knit")
	Source = string.gsub(Source, "local FastCast = require%(ReplicatedStorage%.Assets%.Libraries%.FastCast%)", "local FastCast = Dependencies.FastCast")
	Source = string.gsub(Source, 'local Players = game:GetService%("Players"%)', "local Players = Dependencies.Players")
	local Module = Instance.new("ModuleScript")
	Module.Name = "ClothProjectileLifecycleValidation"
	Module.Source = "return function(Dependencies)\n" .. Source .. "\nend"
	Module.Parent = ReplicatedStorage
	local Controller = require(ReplicatedStorage.ClothProjectileLifecycleValidation)(Dependencies)
	Controller.KnitInit()
	Controller.KnitStart()

	local Origin = Vector3.new(0, 2000, 0)
	local Velocity = Vector3.xAxis * 2400
	local Success, Error = pcall(function()
		for Index, ItemName in { "Bow", "Tanegashima" } do
			table.clear(TraceCalls)
			Projectile:Fire("Launch", Index, Player, Origin, Velocity, Vector3.zero, 0, ItemName)
			Projectile:Fire("Hit", Index, Origin + Vector3.xAxis * 6, Velocity, nil)
			Check(#TraceCalls == 1, "An impact before the first local frame must still check cloth")
			Check(TraceCalls[1].Origin == Origin and TraceCalls[1].Displacement == Vector3.xAxis * 6,
				"The final check must cover the entire unsimulated path up to the impact")
			Check(TraceCalls[1].IsFirearm == (Index == 2), "Final checks must retain the weapon's hole size")
			Projectile:Fire("Hit", Index, Origin + Vector3.xAxis * 6, Velocity, nil)
			Caster.LengthChanged:Fire(Casts[Index], Origin, Vector3.xAxis, 10, Velocity, nil)
			Check(#TraceCalls == 1, "Duplicate impacts and late simulation callbacks must not make additional holes")
		end

		table.clear(TraceCalls)
		Projectile:Fire("Launch", 3, Player, Origin, Velocity, Vector3.zero, 0, "Bow")
		Caster.LengthChanged:Fire(Casts[3], Origin, Vector3.xAxis, 2, Velocity, nil)
		Caster.LengthChanged:Fire(Casts[3], Origin + Vector3.xAxis * 4, Vector3.xAxis, 2, Velocity, nil)
		Projectile:Fire("Hit", 3, Origin + Vector3.xAxis * 10, Velocity, nil)
		Check(#TraceCalls == 3, "Partial simulation must be followed by a final impact check")
		Check(TraceCalls[2].Origin == Origin + Vector3.xAxis * 2 and TraceCalls[2].Displacement == Vector3.xAxis * 4,
			"Consecutive checks must cover gaps left by pierced non-solid objects")
		Check(TraceCalls[3].Origin == Origin + Vector3.xAxis * 6 and TraceCalls[3].Displacement == Vector3.xAxis * 4,
			"The final check must begin at the last tested position")

		table.clear(TraceCalls)
		Projectile:Fire("Launch", 4, Player, Origin, Velocity, Vector3.zero, 0, "Tanegashima")
		Caster.LengthChanged:Fire(Casts[4], Origin, Vector3.xAxis, 10, Velocity, nil)
		Projectile:Fire("Hit", 4, Origin + Vector3.xAxis * 5, Velocity, nil)
		Check(#TraceCalls == 1, "A server correction behind the local projectile must not sweep backward through cloth")

		local OtherPlayer = { Character = nil }
		for Index, ItemName in { "Bow", "Tanegashima" } do
			table.clear(TraceCalls)
			local Id = Index + 4
			Projectile:Fire("Launch", Id, OtherPlayer, Origin, Velocity, Vector3.zero, 0, ItemName)
			Caster.LengthChanged:Fire(Casts[Id], Origin, Vector3.xAxis, 3, Velocity, nil)
			Projectile:Fire("Hit", Id, Origin + Vector3.xAxis * 6, Velocity, nil)
			Check(#TraceCalls == 0, "Other players' projectiles must never cut this client's cloth")
		end
	end)

	for _, Cast in Casts do
		local Bullet = Cast.RayInfo.CosmeticBulletObject
		if Bullet.Parent then
			Containers[Bullet.Parent] = true
		end
		Bullet:Destroy()
	end
	for Container in Containers do
		Container:Destroy()
	end
	Module:Destroy()
	assert(Success, tostring(Error))

	return string.format("Cloth projectile lifecycle: %d checks passed", Checks)
end
