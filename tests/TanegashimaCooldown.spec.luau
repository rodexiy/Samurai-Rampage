-- CreateHarness loads the production BowService, ranged config, and admin command with isolated dependencies.
local Players = game:GetService("Players")

return function(CreateHarness: () -> any): string
	local Harness = CreateHarness()
	local Service = Harness.Service
	local Config = Harness.Config
	local Firearm = Config.Get("Tanegashima")
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Attributes = {}
	local Player: any = {
		Name = "CooldownTestPlayer", Parent = Players,
		GetAttribute = function(_Self: any, Name: string): any return Attributes[Name] end,
		SetAttribute = function(_Self: any, Name: string, Value: any) Attributes[Name] = Value end,
	}
	local OtherAttributes = {}
	local Other: any = {
		Name = "OtherCooldownTestPlayer", Parent = Players,
		GetAttribute = function(_Self: any, Name: string): any return OtherAttributes[Name] end,
		SetAttribute = function(_Self: any, Name: string, Value: any) OtherAttributes[Name] = Value end,
	}
	local Character = Instance.new("Model")
	local Root = Instance.new("Part")
	Root.Anchored = true
	Root.Parent = Character
	Character.PrimaryPart = Root
	Instance.new("Humanoid").Parent = Character
	local Model = Instance.new("Model")
	Model.Name = "BowModel"
	local Muzzle = Instance.new("Attachment")
	Muzzle.Name = "Muzzle"
	Root:Clone().Parent = Model
	Muzzle.Parent = Model:FindFirstChildWhichIsA("BasePart")
	Model.Parent = Character
	Character.Parent = Harness.Container
	Character:SetAttribute("Bow", "Tanegashima")
	Character:SetAttribute("BowEquipped", true)
	Character:SetAttribute("BowDrawing", true)
	Character:SetAttribute("Loaded", true)
	Player.Character = Character
	local State = {Character = Character, Started = 100, Seed = 1, LastShot = -math.huge, LastAim = 0, LastToggle = 0, LastBegin = 0}
	Harness.States[Player] = State
	local Aim = Vector3.new(0, 0, -100)

	local Success, Error = pcall(function()
		Check(Config.GetShotCooldown(Firearm, Player) == 7, "Players must retain the default seven-second cooldown")
		for _, Seconds in {0, 0.25, 2, 15} do
			Check(Service:SetTanegashimaCooldown(Player, Seconds), "Valid nonnegative cooldowns must be accepted")
			Check(Config.GetShotCooldown(Firearm, Player) == Seconds, "The selected player's cooldown must change")
			Check(Config.GetShotCooldown(Firearm, Other) == 7 and Firearm.ShotCooldown == 7, "Overrides must not modify other players or the shared config")
			Check(Config.GetShotCooldown(Config.Get("Bow"), Player) == Config.Get("Bow").ShotCooldown, "Tanegashima overrides must not affect the bow")
		end
		for _, Invalid in {-1, math.huge, -math.huge, 0 / 0, "2", {}} do
			Check(not Service:SetTanegashimaCooldown(Player, Invalid), "Invalid cooldowns must be rejected")
			Check(Attributes.TanegashimaCooldown == 15, "Rejected values must not mutate the current override")
		end
		Check(not Service:SetTanegashimaCooldown(Player, nil), "Missing cooldown values must be rejected")
		Other.Parent = nil
		Check(not Service:SetTanegashimaCooldown(Other, 2), "Disconnected targets must be rejected")
		Other.Parent = Players

		Service:SetTanegashimaCooldown(Player, 2)
		State.LastShot = 99
		Service:Release(Player, Aim)
		Check(#Harness.Casts == 0 and Harness.Ammo.IronBullet == 100, "The server must reject firing before the custom cooldown ends")
		State.LastShot = 97
		Service:Release(Player, Aim)
		Check(#Harness.Casts == 1 and Harness.Ammo.IronBullet == 99, "The server must permit firing after the custom cooldown")
		local Feedback = Service.Client.Feedback.Calls
		local Shot = Feedback[#Feedback]
		Check(Shot[2] == "Shot" and Shot[6] == 102, "Confirmed shots must send the server's exact ready deadline")
		Service:SetTanegashimaCooldown(Player, 10)
		local Changed = Feedback[#Feedback]
		Check(Changed[2] == "Cooldown" and Changed[3] == 110, "Mid-reload changes must update the same shot's server deadline")
		Service:Release(Player, Aim)
		Check(#Harness.Casts == 1, "An extended cooldown must be enforced immediately")
		Service:SetTanegashimaCooldown(Player, 0)
		Service:Release(Player, Aim)
		Service:Release(Player, Aim)
		Check(#Harness.Casts == 3 and Harness.Ammo.IronBullet == 97, "Zero cooldown must allow repeated valid shots while still consuming ammo")

		Check(Harness.Definition.Group == "Admin", "The command must use existing admin permissions")
		local Result = Harness.Command({Executor = Player}, 1.5)
		Check(Attributes.TanegashimaCooldown == 1.5 and Result:find(Player.Name, 1, true) ~= nil, "The command must default to the executor")
		Harness.Command({Executor = Player}, 3, {Player, Other})
		Check(Attributes.TanegashimaCooldown == 3 and OtherAttributes.TanegashimaCooldown == 3, "The command must update every selected player")
		Harness.Command({Executor = Player}, 0, {Other})
		Check(Attributes.TanegashimaCooldown == 3 and OtherAttributes.TanegashimaCooldown == 0, "Targeting one player must leave the executor unchanged")
	end)

	Harness.Container:Destroy()
	assert(Success, tostring(Error))

	return tostring(Checks) .. " Tanegashima cooldown checks passed"
end
