local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BowConfig = require(ReplicatedStorage.Shared.BowConfig)
local BowRaycast = require(ReplicatedStorage.Shared.Utils.BowRaycast)
local CharacterShared = require(ReplicatedStorage.Shared.CharacterShared)
local FastCast = require(ReplicatedStorage.Assets.Libraries.FastCast)

local BowService = Knit.CreateService({
	Name = "BowService",
	Client = {
		Request = Knit.CreateSignal(),
		Feedback = Knit.CreateSignal(),
		Projectile = Knit.CreateSignal(),
	},
})

type BowState = {
	Character: Model,
	Started: number?,
	Seed: number,
	Aim: Vector3?,
	LastShot: number,
	LastAim: number,
	LastToggle: number,
	LastBegin: number,
	Grip: Motor6D?,
}

local DataService
local InventoryService
local ItemService
local WeaponService
local HitService
local AlertService
local AimEvent: UnreliableRemoteEvent
local Caster = FastCast.new()
local States: { [Player]: BowState } = {}
local PlayerConnections: { [Player]: RBXScriptConnection } = {}
local ShotId = 0
local RandomGenerator = Random.new()

local function GetState(Player: Player): BowState?
	local State = States[Player]
	return if State and State.Character == Player.Character and State.Character.Parent then State else nil
end

local function HasArrows(Player: Player): boolean
	local Item = InventoryService:GetRawPlayerItemByName(Player, BowConfig.ArrowItem)
	return Item ~= nil and (Item.Stack or 0) > 0
end

local function CanUse(Player: Player, State: BowState): boolean
	return BowConfig.CanUse(State.Character) and not Player:GetAttribute("CantAttack")
		and State.Character:GetAttribute("Loaded") == true
end

local function SetAim(State: BowState, Aim: any)
	if not BowConfig.IsValidAim(Aim) then
		return
	end

	local Root = State.Character.PrimaryPart
	if Root and (Aim - Root.Position).Magnitude <= BowConfig.MaxDistance + 100 then
		State.Aim = Aim
	end
end

function BowService:CancelDraw(Player: Player)
	local State = GetState(Player)
	if not State or not State.Started then
		return
	end

	State.Started = nil
	State.Character:SetAttribute("BowDrawing", false)
	State.Character:SetAttribute("BowDrawStarted", nil)
	self.Client.Feedback:Fire(Player, "Cancel")
end

function BowService:SetInHand(Player: Player, InHand: boolean)
	local State = GetState(Player)
	if not State or not State.Grip then
		return
	end

	local Character = State.Character
	local BodyPart = Character:FindFirstChild(if InHand then "Left Arm" else "Torso") :: BasePart?
	if not BodyPart then
		return
	end

	self:CancelDraw(Player)
	State.Grip.Enabled = true
	State.Grip.Part0 = BodyPart
	State.Grip.C0 = if InHand then BowConfig.HandOffset else BowConfig.GetBackOffset()
	State.Grip.C1 = CFrame.identity
	State.Grip.Parent = BodyPart
	Character:SetAttribute("BowEquipped", InHand)

	if InHand and Character:GetAttribute("WeaponEquipped") then
		WeaponService:Equip(Character, false, 0)
	end
end

function BowService:Unload(Player: Player)
	local State = GetState(Player)
	if not State then
		return
	end

	self:CancelDraw(Player)
	if State.Grip then
		State.Grip:Destroy()
		State.Grip = nil
	end

	local Model = State.Character:FindFirstChild("BowModel")
	if Model then
		Model:Destroy()
	end
	State.Character:SetAttribute("BowEquipped", false)
	State.Character:SetAttribute("Bow", nil)
end

function BowService:UnequipItem(Player: Player)
	local Data = DataService:GetData(Player)
	Data.Equipped.Bow = nil
	self:Unload(Player)
end

function BowService:LoadBow(Player: Player)
	local State = GetState(Player)
	if not State then
		return
	end

	self:Unload(Player)
	local Data = DataService:GetData(Player)
	local ItemName = Data.Equipped.Bow
	local Item = ItemName and InventoryService:GetRawPlayerItemByName(Player, ItemName)
	local ItemData = ItemName and ItemService:GetItemData(ItemName)
	if not Item or Item.Stack <= 0 or not ItemData or ItemData.Type ~= "Bow" then
		Data.Equipped.Bow = nil
		return
	end

	local Model = ReplicatedStorage.Assets.Models.Bow.Bow:Clone() :: Model
	Model.Name = "BowModel"
	for _, Script in Model:QueryDescendants("LuaSourceContainer") do
		Script:Destroy()
	end
	for _, Part: BasePart in Model:QueryDescendants("BasePart") do
		Part.Anchored = false
		Part.Massless = true
		Part.CanCollide = false
		Part.CanTouch = false
		Part.CanQuery = false
	end
	-- Keep the bow assembled while the character's body joints enter ragdoll.
	for _, Motor: Motor6D in Model:QueryDescendants("Motor6D") do
		Motor:SetAttribute("NotRagdoll", true)
		Motor.Enabled = true
	end

	local Root = Model.PrimaryPart
	local Torso = State.Character:FindFirstChild("Torso") :: BasePart?
	if not Root or not Torso then
		Model:Destroy()
		return
	end

	local Grip = Model:FindFirstChild("Weld") :: Motor6D?
	if not Grip then
		Grip = Instance.new("Motor6D")
	end
	Grip.Name = "RootPart"
	Grip:SetAttribute("NotRagdoll", true)
	Grip.Part1 = Root
	State.Grip = Grip
	Model:PivotTo(Torso.CFrame * BowConfig.GetBackOffset())
	Model.Parent = State.Character
	State.Character:SetAttribute("Bow", ItemName)
	self:SetInHand(Player, false)
end

function BowService:EquipItem(Player: Player, ItemName: string)
	local Item = InventoryService:GetRawPlayerItemByName(Player, ItemName)
	local ItemData = ItemService:GetItemData(ItemName)
	if not Item or Item.Stack <= 0 or not ItemData or ItemData.Type ~= "Bow" then
		return
	end

	local Data = DataService:GetData(Player)
	if Data.Equipped.Bow == ItemName then
		self:UnequipItem(Player)
	else
		Data.Equipped.Bow = ItemName
		self:LoadBow(Player)
	end
end

function BowService:BeginDraw(Player: Player, Aim: any)
	local State = GetState(Player)
	if not State or State.Started or not State.Character:GetAttribute("BowEquipped") then
		return
	end

	local Now = workspace:GetServerTimeNow()
	if Now - State.LastBegin < 0.15 then
		self.Client.Feedback:Fire(Player, "Cancel")
		return
	end
	State.LastBegin = Now
	if not CanUse(Player, State) or Now - State.LastShot < BowConfig.ShotCooldown or not HasArrows(Player) then
		self.Client.Feedback:Fire(Player, "Cancel")
		if not HasArrows(Player) then
			AlertService:AlertPlayer(Player, "You need arrows to use the bow.", "Warn")
		end
		return
	end

	State.Aim = nil
	SetAim(State, Aim)
	if not State.Aim then
		self.Client.Feedback:Fire(Player, "Cancel")
		return
	end
	State.Started = Now
	State.Seed = RandomGenerator:NextInteger(1, 100000)
	State.Character:SetAttribute("Running", false)
	State.Character:SetAttribute("BowAimSeed", State.Seed)
	State.Character:SetAttribute("BowDrawStarted", Now)
	State.Character:SetAttribute("BowDrawing", true)
	self.Client.Feedback:Fire(Player, "Draw", Now, State.Seed)

	task.delay(BowConfig.MaxHoldTime, function()
		if GetState(Player) == State and State.Started == Now then
			self:Release(Player)
		end
	end)
end

function BowService:Release(Player: Player, Aim: any?)
	local State = GetState(Player)
	if not State or not State.Started then
		return
	end

	if not CanUse(Player, State) or not State.Character:GetAttribute("BowEquipped") or not HasArrows(Player) then
		self:CancelDraw(Player)
		return
	end
	SetAim(State, Aim)
	local Origin = BowConfig.GetOrigin(State.Character)
	local Root = State.Character.PrimaryPart
	if not Origin or not Root or (Origin - Root.Position).Magnitude > 10 or not State.Aim then
		self:CancelDraw(Player)
		return
	end

	local Now = workspace:GetServerTimeNow()
	local Elapsed = math.clamp(Now - State.Started, 0, BowConfig.MaxHoldTime)
	if Elapsed < BowConfig.MinDrawTime then
		self:CancelDraw(Player)
		return
	end

	local Velocity = BowConfig.GetVelocity(Origin, State.Aim, Elapsed, State.Seed)
	local Charge = BowConfig.GetCharge(Elapsed)
	State.Started = nil
	State.LastShot = Now
	State.Character:SetAttribute("BowDrawing", false)
	State.Character:SetAttribute("BowDrawStarted", nil)
	InventoryService:RemoveItemFromPlayer(Player, BowConfig.ArrowItem, 1, false)

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	local Excluded: { Instance } = { State.Character }
	local Effects = workspace:FindFirstChild("VFX")
	if Effects then
		table.insert(Excluded, Effects)
	end
	Params.FilterDescendantsInstances = Excluded
	local Behavior = FastCast.newBehavior()
	Behavior.RaycastParams = Params
	Behavior.CanPierceFunction = BowRaycast.CanPierce
	-- Launch toward the cursor, then let gravity bend the trajectory downward.
	Behavior.Acceleration = Vector3.new(0, -workspace.Gravity, 0)
	Behavior.MaxDistance = BowConfig.MaxDistance
	ShotId += 1
	local Cast = Caster:Fire(Origin, Velocity.Unit, Velocity, Behavior)
	Cast.UserData = {
		Id = ShotId,
		Character = State.Character,
		Origin = Origin,
		Charge = Charge,
	}
	task.delay(BowConfig.MaxFlightTime, function()
		if Cast.StateInfo and Cast.StateInfo.UpdateConnection then
			Cast:Terminate()
		end
	end)
	self.Client.Feedback:Fire(Player, "Shot", Charge)
	self.Client.Projectile:FireAll("Launch", ShotId, Player, Origin, Velocity, Behavior.Acceleration, Now)
end

local function BindCharacter(Player: Player, Character: Model)
	States[Player] = {
		Character = Character, Seed = 0, LastShot = -math.huge, LastAim = 0,
		LastToggle = 0, LastBegin = 0,
	}
	Character:SetAttribute("BowEquipped", false)
	Character:SetAttribute("BowDrawing", false)
	Character:GetAttributeChangedSignal("BowDrawing"):Connect(function()
		if Character:GetAttribute("BowDrawing") then
			Character:SetAttribute("Running", false)
		end

		CharacterShared:UpdateBoth(Character)
	end)

	for _, Attribute in BowConfig.CancelAttributes do
		Character:GetAttributeChangedSignal(Attribute):Connect(function()
			if not Character:GetAttribute(Attribute) or GetState(Player) == nil then
				return
			end

			BowService:CancelDraw(Player)
			if Attribute == "Died" or Attribute == "Downed" or Attribute == "Ragdoll"
				or Attribute == "CameraCutscene" or Attribute == "RealmTeleporting" then
				BowService:SetInHand(Player, false)
			end
		end)
	end
	Character.ChildAdded:Connect(function(Child: Instance)
		if Child:IsA("Tool") then
			BowService:SetInHand(Player, false)
		end
	end)

	local function LoadWhenReady()
		if Character:GetAttribute("Loaded") and Player.Character == Character then
			BowService:LoadBow(Player)
		end
	end
	Character:GetAttributeChangedSignal("Loaded"):Connect(LoadWhenReady)
	LoadWhenReady()
end

function BowService.KnitInit()
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	ItemService = Knit.GetService("ItemService")
	WeaponService = Knit.GetService("WeaponService")
	HitService = Knit.GetService("HitService")
	AlertService = Knit.GetService("AlertService")

	local Events = ReplicatedStorage.Assets:FindFirstChild("Events")
	if not Events then
		Events = Instance.new("Folder")
		Events.Name = "Events"
		Events.Parent = ReplicatedStorage.Assets
	end
	AimEvent = Events:FindFirstChild("BowAim") :: UnreliableRemoteEvent
	if not AimEvent then
		AimEvent = Instance.new("UnreliableRemoteEvent")
		AimEvent.Name = "BowAim"
		AimEvent.Parent = Events
	end
end

function BowService.KnitStart()
	BowService.Client.Request:Connect(function(Player: Player, Action: string, Aim: any)
		local State = GetState(Player)
		if not State then
			return
		end

		if Action == "Toggle" then
			local Now = workspace:GetServerTimeNow()
			if Now - State.LastToggle < 0.25 then
				return
			end
			State.LastToggle = Now
			if State.Character:GetAttribute("BowEquipped") then
				BowService:SetInHand(Player, false)
			elseif CanUse(Player, State) then
				BowService:SetInHand(Player, true)
			end
		elseif Action == "Begin" then
			BowService:BeginDraw(Player, Aim)
		elseif Action == "Release" then
			BowService:Release(Player, Aim)
		elseif Action == "Cancel" then
			BowService:CancelDraw(Player)
		end
	end)
	AimEvent.OnServerEvent:Connect(function(Player: Player, Aim: any)
		local State = GetState(Player)
		local Now = workspace:GetServerTimeNow()
		if State and State.Started and Now - State.LastAim >= BowConfig.AimUpdateInterval * 0.75 then
			State.LastAim = Now
			SetAim(State, Aim)
		end
	end)
	Caster.RayHit:Connect(function(Cast: any, Result: RaycastResult, Velocity: Vector3)
		local Data = Cast.UserData
		if not Data then
			return
		end

		local ImpactType = BowConfig.GetImpactSoundType(Result.Instance, Result.Material)
		BowService.Client.Projectile:FireAll("Hit", Data.Id, Result.Position, Velocity, Result.Instance, ImpactType)
		local Target: Instance? = Result.Instance
		while Target and Target ~= workspace do
			if Target:IsA("Model") and Target:FindFirstChildWhichIsA("Humanoid")
				and typeof(Target:GetAttribute("Health")) == "number" then
				if Target ~= Data.Character and Data.Character.Parent and not Target:GetAttribute("Died") then
					local Distance = (Result.Position - Data.Origin).Magnitude
					HitService:NormalHit(Target, Data.Character, BowConfig.GetDamage(Data.Charge, Distance), {
						By = "Bow", Ranged = true, NoStun = true,
						RayCFrame = CFrame.lookAt(Result.Position, Result.Position + Velocity),
					})
				end
				break
			end
			Target = Target.Parent
		end
	end)

	HitService.HitResolved.Event:Connect(function(Target: Model, _Attacker: Model, Result: string)
		if Result == "Hit" then
			local Player = Players:GetPlayerFromCharacter(Target)
			if Player then
				BowService:CancelDraw(Player)
			end
		end
	end)

	local function BindPlayer(Player: Player)
		PlayerConnections[Player] = Player.CharacterAdded:Connect(function(Character: Model)
			BindCharacter(Player, Character)
		end)
		if Player.Character then
			BindCharacter(Player, Player.Character)
		end
	end
	Players.PlayerAdded:Connect(BindPlayer)
	Players.PlayerRemoving:Connect(function(Player: Player)
		States[Player] = nil
		local Connection = PlayerConnections[Player]
		if Connection then
			Connection:Disconnect()
			PlayerConnections[Player] = nil
		end
	end)
	for _, Player in Players:GetPlayers() do
		BindPlayer(Player)
	end
end

return BowService
