-- Run in Studio with this function and the current BowService ModuleScript.
-- Dependencies are isolated so no player inventory or persistent data is changed.
return function(ServiceModule: ModuleScript): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.TanegashimaConfig)
	local RangedConfig = require(ReplicatedStorage.Shared.RangedWeaponConfig)
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end

	local function Signal(): any
		local Event = { Calls = {} }
		function Event:Connect(_Callback: (...any) -> ()) end
		function Event:Fire(...: any)
			table.insert(self.Calls, table.pack(...))
		end
		Event.FireAll = Event.Fire
		return Event
	end

	local Counts = { Tanegashima = 1, Bow = 1, Gunpowder = 3, IronBullet = 2, Arrow = 4 }
	local Data = { Equipped = { Bow = "Tanegashima" } }
	local Removed = {}
	local Casts = {}
	local Delays = {}
	local Services = {
		DataService = { GetData = function(_Self: any, _Player: any): any return Data end },
		InventoryService = {
			GetRawPlayerItemByName = function(_Self: any, _Player: any, Name: string): any
				return if Counts[Name] then { Stack = Counts[Name] } else nil
			end,
			RemoveItemFromPlayer = function(_Self: any, _Player: any, Name: string, Amount: number)
				Counts[Name] -= Amount
				Removed[Name] = (Removed[Name] or 0) + Amount
			end,
		},
		ItemService = { GetItemData = function(_Self: any, _Name: string): any return { Type = "Bow" } end },
		WeaponService = { Equip = function(_Self: any, Target: Model, Equipped: boolean, _Delay: number)
			Target:SetAttribute("WeaponEquipped", Equipped)
		end },
		AlertService = { AlertPlayer = function(_Self: any, _Player: any, _Message: string, _Kind: string) end },
	}
	local Knit = {
		CreateSignal = Signal,
		CreateService = function(Value: any): any return Value end,
		GetService = function(Name: string): any return Services[Name] end,
	}
	local FastCast = {
		newBehavior = function(): any return {} end,
		new = function(): any
			return {
				Fire = function(_Self: any, Origin: Vector3, _Direction: Vector3, Velocity: Vector3, Behavior: any): any
					local Cast = { Origin = Origin, Velocity = Velocity, Behavior = Behavior }
					table.insert(Casts, Cast)
					return Cast
				end,
			}
		end,
	}
	local OriginalRequire = require
	local Environment = setmetatable({
		require = function(Module: ModuleScript): any
			if Module == ReplicatedStorage.Packages.Knit then
				return Knit
			elseif Module == ReplicatedStorage.Assets.Libraries.FastCast then
				return FastCast
			elseif Module == ReplicatedStorage.Shared.CharacterShared then
				return { UpdateBoth = function(_Self: any, _Character: Model) end }
			end

			return OriginalRequire(Module)
		end,
		task = { delay = function(Duration: number, _Callback: () -> ())
			table.insert(Delays, Duration)
		end },
	}, { __index = getfenv() })
	local Source = ServiceModule.Source:gsub("return BowService%s*$", "return {Service = BowService, Bind = BindCharacter, States = States}")
	local Run = assert(loadstring(Source))
	setfenv(Run, Environment)
	local Harness = Run()
	local Service = Harness.Service
	Service.KnitInit()

	local Container = Instance.new("Folder")
	local Character = Instance.new("Model")
	Character.Parent = Container
	for _, Name in { "HumanoidRootPart", "Torso", "Right Arm", "Left Arm" } do
		local Part = Instance.new("Part")
		Part.Name = Name
		Part.Parent = Character
		if Name == "HumanoidRootPart" then
			Character.PrimaryPart = Part
		end
	end
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Parent = Character
	Character:SetAttribute("Loaded", true)
	local Player = {
		Character = Character,
		GetAttribute = function(_Self: any, _Name: string): any
			return nil
		end,
	}
	Harness.Bind(Player, Character)
	local State = Harness.States[Player]
	local Aim = Vector3.new(0, 0, -100)
	local function Begin()
		State.LastBegin = -math.huge
		State.LastShot = -math.huge
		Service:BeginDraw(Player, Aim)
	end

	local Success, Failure = pcall(function()
		Check(Config.ShotCooldown == 7, "The Tanegashima reload must last seven seconds")
		Check(Config.GetSpreadDegrees(true) < Config.GetSpreadDegrees(false), "Shift focus reduces the spread cone")
		Check(Config.GetDamage(1, 0) == Config.MinDamage and Config.MinDamage <= Config.MaxDamage * 0.1,
			"Point-blank damage must stay very low")
		Check(Config.GetDamage(1, Config.CloseRangeDistance) == Config.MinDamage, "Short-range hits retain minimum damage")
		Check(Config.GetDamage(0, Config.FullDamageDistance) == Config.MaxDamage, "Long-range hits reach full damage")
		Check(Config.GetDamage(1, Config.MaxDistance) == Config.MaxDamage, "Distance cannot exceed maximum damage")
		Check(Config.GetDamage(1, -10) == Config.MinDamage, "Negative distance cannot produce invalid damage")
		local PreviousDamage = Config.MinDamage
		for Distance = 0, Config.FullDamageDistance + 20, 10 do
			local Damage = Config.GetDamage(1, Distance)
			Check(Damage >= PreviousDamage and Damage <= Config.MaxDamage, "Damage rises with range without exceeding its limit")
			PreviousDamage = Damage
		end
		Check(Config.GetSway(0, 123).Magnitude > 0, "Sway starts as soon as aiming begins")
		Check(Config.GetSway(8, 123) ~= Config.GetSway(12, 123), "Sway keeps moving during long aim sessions")
		for _, Direction in { -Vector3.zAxis, Vector3.yAxis, -Vector3.yAxis } do
			for Seed = 1, 8 do
				local Velocity = Config.GetVelocity(Vector3.zero, Direction * 100, 4, Seed)
				local AimDirection = Config.GetAimTarget(Vector3.zero, Direction * 100, 4, Seed).Unit
				Check(Velocity.Unit:Dot(AimDirection) >= math.cos(math.rad(Config.SpreadDegrees)) - 0.00001,
					"Keep even vertical shots inside the displayed spread cone")
				Check(Config.GetSway(4, Seed).Magnitude <= math.rad(Config.SwayMaximumDegrees) * math.sqrt(2) + 0.00001
					and Config.GetDrawCameraSway(4, Seed) == CFrame.identity, "Keep aim sway within its configured bounds and the camera steady")
				local FocusedVelocity = Config.GetVelocity(Vector3.zero, Direction * 100, 4, Seed, true)
				Check(FocusedVelocity.Unit:Dot(AimDirection) >= math.cos(math.rad(Config.GetSpreadDegrees(true))) - 0.00001,
					"Focused bullets stay inside the smaller cursor cone")
				local SharedAim = Config.GetAimTarget(Vector3.zero, Direction * 100, 12, 123).Unit
				local RandomShot = Config.GetVelocity(Vector3.zero, Direction * 100, 12, Seed, true, 123)
				Check(RandomShot.Unit:Dot(SharedAim) >= math.cos(math.rad(Config.GetSpreadDegrees(true))) - 0.00001,
					"Random spread must use the same sway center displayed to the shooter")
			end
		end

		Check(Character:GetAttribute("Bow") == "Tanegashima", "Load the firearm in the bow slot")
		Check(State.Grip.Part0 == Character:FindFirstChild("Torso"), "Stow on the torso")
		Check(State.Grip.C0.Position.X > 0, "Stow on the right side")
		for _, Motor: Motor6D in Character:QueryDescendants("Motor6D") do
			Check(Motor:GetAttribute("NotRagdoll") == true and Motor.Enabled, "Protect all firearm motors from ragdoll")
		end

		Service:SetInHand(Player, true)
		Check(State.Grip.Part0 == Character:FindFirstChild("Right Arm"), "Equip in the right arm")
		Check(State.Grip.C0 == CFrame.identity and State.Grip.C1 == CFrame.identity, "Equip motor at zero offset")
		Check(Config.GetOrigin(Character) ~= nil, "Use the muzzle in the existing model")

		for _, Missing in { "Gunpowder", "IronBullet" } do
			local Previous = Counts[Missing]
			Counts[Missing] = 0
			Begin()
			Check(State.Started ~= nil, "Allow aiming even without " .. Missing)
			Service:Release(Player, Aim)
			Check(#Casts == 0, "Require " .. Missing .. " before firing")
			Check(next(Removed) == nil, "Missing ammo must consume nothing")
			Service:CancelDraw(Player)
			Counts[Missing] = Previous
		end

		Begin()
		Check(State.Started ~= nil, "Begin with both ammunition resources")
		Service:CancelDraw(Player)
		Check(State.Started == nil and next(Removed) == nil, "Cancellation consumes nothing")
		Check(#Delays == 0, "Holding firearm aim must never schedule an automatic shot")

		Begin()
		Counts.IronBullet = 0
		State.Started = workspace:GetServerTimeNow() - Config.FullChargeTime
		Service:Release(Player, Aim)
		Check(#Casts == 0 and Counts.Gunpowder == 3, "Recheck ammunition at release without losing gunpowder")
		Counts.IronBullet = 2

		Begin()
		State.Started = workspace:GetServerTimeNow()
		Service:Release(Player, Aim)
		Check(#Casts == 1 and Counts.Gunpowder == 2 and Counts.IronBullet == 1, "Consume one of each resource per shot")
		Check(State.Started ~= nil and Character:GetAttribute("BowDrawing") == true, "An immediate shot preserves right-button aim")
		Check(Counts.Arrow == 4, "The firearm never consumes arrows")
		Check(Casts[1].Behavior.MaxDistance == Config.MaxDistance, "Use the firearm range")
		Check(math.abs(Casts[1].Velocity.Magnitude - Config.MaxSpeed) < 0.01, "Use the firearm speed")
		Check(Casts[1].UserData.Config.GetDamage(0, 0) == Config.MinDamage, "Keep distance-based firearm damage with the projectile")
		Service:Release(Player, Aim)
		Check(#Casts == 1 and Counts.IronBullet == 1, "Duplicate releases cannot consume or fire twice")
		State.LastShot = workspace:GetServerTimeNow() - (Config.ShotCooldown - 1)
		Service:Release(Player, Aim)
		Check(#Casts == 1 and Counts.IronBullet == 1, "The server blocks shooting before the reload finishes")
		State.LastBegin = -math.huge
		Service:CancelDraw(Player)
		Service:BeginDraw(Player, Aim)
		Check(State.Started ~= nil and #Casts == 1, "Allow aiming during firearm cooldown")
		Service:CancelDraw(Player)
		State.LastShot = -math.huge
		Service:Release(Player, Aim)
		Check(#Casts == 1 and Counts.IronBullet == 1, "Reject shots after right-button aim is released")
		Character:SetAttribute("BowDrawing", true)
		Service:Release(Player, Aim)
		Check(#Casts == 1 and Counts.IronBullet == 1, "Require a server aim session rather than only the aiming attribute")
		Character:SetAttribute("BowDrawing", false)
		Begin()
		State.Started = workspace:GetServerTimeNow()
		State.LastShot = workspace:GetServerTimeNow() - (Config.ShotCooldown + 0.01)
		Service:Release(Player, Aim)
		Check(#Casts == 2 and Counts.IronBullet == 0, "Fire immediately once aiming resumes")

		local OldGrip = State.Grip
		Service:EquipItem(Player, "Bow")
		Check(OldGrip.Parent == nil and Data.Equipped.Bow == "Bow", "Replace the firearm with the bow in the same slot")
		Service:SetInHand(Player, true)
		Check(State.Grip.Part0 == Character:FindFirstChild("Left Arm"), "The bow still equips in the left arm")
		Begin()
		State.Started = workspace:GetServerTimeNow()
		Service:Release(Player, Aim)
		Check(Counts.Arrow == 4, "The bow still requires its draw time")
		Begin()
		State.Started = workspace:GetServerTimeNow() - 1.5
		Service:Release(Player, Aim)
		Check(Counts.Arrow == 3 and Counts.Gunpowder == 1 and Counts.IronBullet == 0, "The bow still consumes only arrows")
		Check(RangedConfig.GetAmmoCount(Config, Counts) == 0, "Display the limiting ammunition count")

		for _, ItemName in { "Bow", "Tanegashima" } do
			Data.Equipped.Bow = ItemName
			Service:LoadBow(Player)
			Service:SetInHand(Player, true)
			Character:SetAttribute("Weapon", "BasicKatana")
			Begin()
			Character:SetAttribute("EquipDebounce", true)
			Service:EquipSword(Player)
			Check(Character:GetAttribute("BowEquipped") == true, "Respect equip restrictions before stowing " .. ItemName)
			Character:SetAttribute("EquipDebounce", false)
			Service:EquipSword(Player)
			Check(Character:GetAttribute("BowEquipped") == false and Character:GetAttribute("WeaponEquipped") == true,
				"Stow " .. ItemName .. " and equip the sword in one request")
			Check(State.Started == nil and Character:GetAttribute("BowDrawing") == false, "Switching to the sword cancels ranged aim")
			Check(Data.Equipped.Bow == ItemName, "Keep the ranged item available in its inventory slot")
		end

		for _, ItemName in { "Bow", "Tanegashima" } do
			Data.Equipped.Bow = ItemName
			Service:LoadBow(Player)
			Service:SetInHand(Player, true)
			Begin()
			local Grip = State.Grip
			local Model = Character:FindFirstChild("BowModel")
			local ShotCount = #Casts
			Service:EquipItem(Player, ItemName)
			Check(Data.Equipped.Bow == nil and Character:GetAttribute("Bow") == nil, "Inventory unequip clears the " .. ItemName .. " slot")
			Check(Character:GetAttribute("BowEquipped") == false, "Inventory unequip also removes " .. ItemName .. " from the hand")
			Check(Grip.Parent == nil and State.Grip == nil and Model.Parent == nil, "Inventory unequip removes the grip and weapon model")
			Check(State.Started == nil and State.Aim == nil and Character:GetAttribute("BowDrawing") == false
				and Character:GetAttribute("BowDrawStarted") == nil, "Inventory unequip clears every active aim state")
			local Feedback = Service.Client.Feedback.Calls
			Check(Feedback[#Feedback][2] == "Unequipped", "Notify the client to clear all weapon animations and camera effects")
			Service:SetInHand(Player, true)
			Service:Release(Player, Aim)
			Check(Character:GetAttribute("BowEquipped") == false and #Casts == ShotCount, "An unequipped inventory item cannot be drawn or fired")
		end
	end)

	Container:Destroy()
	assert(Success, Failure)
	return string.format("Tanegashima service: %d checks passed", Checks)
end
