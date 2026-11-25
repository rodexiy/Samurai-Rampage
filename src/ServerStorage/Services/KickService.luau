local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.KickConfig)
local Validate = require(ReplicatedStorage.Shared.Validate)
local CharacterShared = require(ReplicatedStorage.Shared.CharacterShared)

local KickService = Knit.CreateService({
	Name = "KickService",
	Client = {
		Request = Knit.CreateSignal(),
		Started = Knit.CreateSignal(),
		Stopped = Knit.CreateSignal(),
		Impact = Knit.CreateSignal(),
	},
})

local DebounceService
local HitboxService
local DamageService
local HitService
local KnockbackService
local StatService
local DoorService
local StaminaService

type KickState = {
	Started: number,
	Hitted: { [Model]: boolean },
	Notified: { [Model]: boolean },
	Connections: { RBXScriptConnection },
	DoorHitbox: Part?,
}

local Active: { [Model]: KickState } = {}
local LastSides: { [Model]: string } = setmetatable({}, { __mode = "k" })
local CancelAttributes =
	{ "Died", "Downed", "Ragdoll", "BeenHitted", "PostureBreak", "BeenDeflected", "RealmEditing", "Mounted" }

function KickService:HitTarget(Attacker: Model, Character: Model)
	if
		not Character.PrimaryPart
		or (not Character:GetAttribute("IntroTutorialProtected") and not DamageService:CanDamage(Character, Attacker))
		or Character:GetAttribute("InCell")
		or Character:GetAttribute("InLabor")
	then
		return
	end

	local Damage = Config.BaseDamage + StatService:GetLevel(Attacker, "Strength") * Config.StrengthDamage
	local WasMounted = Character:GetAttribute("Mounted") == true
	local Result = HitService:NormalHit(Character, Attacker, Damage, {
		By = "Kick",
		Action = "Kick",
		DontApplyForce = true,
		RayCFrame = Character:GetPivot(),
	})
	if Result ~= "Hit" and Result ~= "Block" and Result ~= "Deflect" and Result ~= "TutorialKick" then
		return
	end

	self.Client.Impact:FireAll(Character)
	if WasMounted and Result == "Hit" then
		return
	end

	if Result == "Deflect" then
		return
	end

	local Offset = Character:GetPivot().Position - Attacker:GetPivot().Position
	local Direction = Vector3.new(Offset.X, 0, Offset.Z)
	if Direction.Magnitude <= 0.001 then
		local Look = Attacker:GetPivot().LookVector
		Direction = Vector3.new(Look.X, 0, Look.Z)
	end
	if Direction.Magnitude <= 0.001 then
		return
	end

	local Speed = Config.KnockbackSpeed * (if Result == "Block" then Config.BlockKnockbackMultiplier else 1)
	KnockbackService:FlingWithVelocity(Character, Direction.Unit * Speed, Result == "Hit" or Result == "TutorialKick")
end

function KickService:Stop(Character: Model, Completed: boolean?)
	local State = Active[Character]
	if not State then
		return
	end

	Active[Character] = nil
	for _, Connection in State.Connections do
		Connection:Disconnect()
	end
	if State.DoorHitbox then
		State.DoorHitbox:Destroy()
	end

	Character:SetAttribute("Kicking", false)
	CharacterShared:UpdateBoth(Character)
	if not Completed then
		self.Client.Stopped:FireAll(Character)
	end
end

function KickService:CheckHitbox(Character: Model, State: KickState, CanHit: boolean)
	local Root = Character.PrimaryPart
	if not Root then
		self:Stop(Character)
		return
	end

	if CanHit and not State.DoorHitbox then
		local Hitbox = Instance.new("Part")
		Hitbox.Name = "KickDoorHitbox"
		Hitbox.Size = Config.DoorHitboxSize
		Hitbox.Anchored = true
		Hitbox.CanCollide = false
		Hitbox.CanTouch = false
		Hitbox.CanQuery = false
		Hitbox.Transparency = 1
		Hitbox.Parent = workspace
		State.DoorHitbox = Hitbox
	end

	if CanHit and State.DoorHitbox then
		State.DoorHitbox.CFrame = Root.CFrame * CFrame.new(0, 0, -Config.DoorHitboxSize.Z / 2)
		DoorService:BreakInHitbox(Character, State.DoorHitbox, State.Hitted)
	end

	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = CollectionService:GetTagged("HitboxDetectable")
	local Targets = HitboxService:GetCharactersInBoxArea(
		Root.CFrame * CFrame.new(0, 0, -Config.HitboxSize.Z / 2),
		Config.HitboxSize,
		Params
	)

	for _, Target: Model in Targets do
		if Target == Character or State.Hitted[Target] or not Target.PrimaryPart then
			continue
		end

		local RayParams = RaycastParams.new()
		RayParams.FilterType = Enum.RaycastFilterType.Exclude
		RayParams.FilterDescendantsInstances = { Character, Target }
		if workspace:Raycast(Root.Position, Target.PrimaryPart.Position - Root.Position, RayParams) then
			continue
		end

		if not State.Notified[Target] then
			State.Notified[Target] = true
			local Detected = Target:FindFirstChild("HitboxDetected")
			if Target:GetAttribute("IsAI") and Detected and Detected:IsA("BindableEvent") then
				Detected:Fire(Character, {
					Action = "Kick",
					TimeUntilHit = math.max(0, Config.HitDelay - (workspace:GetServerTimeNow() - State.Started)),
				})
			end
		end
		if not CanHit then
			continue
		end

		State.Hitted[Target] = true
		task.spawn(function()
			if Active[Character] == State then
				self:HitTarget(Character, Target)
			end
		end)
	end
end

function KickService:Kick(Character: Model)
	if Active[Character] or not Character:IsDescendantOf(workspace) or not Validate:CanKick(Character) then
		return
	end

	local State: KickState = { Started = workspace:GetServerTimeNow(), Hitted = {}, Notified = {}, Connections = {} }
	local TotalDuration = Config.HitDelay + Config.Duration
	Active[Character] = State
	StaminaService:RemoveStamina(Character, Config.StaminaCost)
	local Side = if LastSides[Character] == "Right" then "Left" else "Right"
	LastSides[Character] = Side

	DebounceService:AddDebounce(Character, "KickDebounce", Config.Cooldown)
	Character:SetAttribute("Running", false)
	Character:SetAttribute("Kicking", true)
	CharacterShared:UpdateBoth(Character)
	self.Client.Started:FireAll(Character, Side, State.Started)

	table.insert(
		State.Connections,
		Character.AttributeChanged:Connect(function(Attribute: string)
			if table.find(CancelAttributes, Attribute) and Character:GetAttribute(Attribute) then
				self:Stop(Character)
			end
		end)
	)
	table.insert(
		State.Connections,
		Character.Destroying:Connect(function()
			self:Stop(Character)
		end)
	)
	table.insert(
		State.Connections,
		RunService.Heartbeat:Connect(function()
			local Elapsed = workspace:GetServerTimeNow() - State.Started
			if not Character:IsDescendantOf(workspace) then
				self:Stop(Character)
			elseif Elapsed >= TotalDuration then
				self:Stop(Character, true)
			else
				self:CheckHitbox(Character, State, Elapsed >= Config.HitDelay)
			end
		end)
	)
	task.delay(TotalDuration, function()
		if Active[Character] == State then
			self:Stop(Character, true)
		end
	end)
end

function KickService.KnitInit()
	DebounceService = Knit.GetService("DebounceService")
	HitboxService = Knit.GetService("HitboxService")
	DamageService = Knit.GetService("DamageService")
	HitService = Knit.GetService("HitService")
	KnockbackService = Knit.GetService("KnockbackService")
	StatService = Knit.GetService("StatService")
	DoorService = Knit.GetService("DoorService")
	StaminaService = Knit.GetService("StaminaService")
end

function KickService.KnitStart()
	KickService.Client.Request:Connect(function(Player: Player, Character: Model)
		if typeof(Character) == "Instance" and Character:IsA("Model") and Player.Character == Character then
			KickService:Kick(Character)
		end
	end)
	Players.PlayerRemoving:Connect(function(Player: Player)
		if Player.Character then
			KickService:Stop(Player.Character)
		end
	end)
end

return KickService
