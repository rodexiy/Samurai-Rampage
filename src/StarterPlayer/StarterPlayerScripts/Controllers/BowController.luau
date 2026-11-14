local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BowConfig = require(ReplicatedStorage.Shared.BowConfig)
local RangedWeaponConfig = require(ReplicatedStorage.Shared.RangedWeaponConfig)
local BowRaycast = require(ReplicatedStorage.Shared.Utils.BowRaycast)
local MountedAim = require(ReplicatedStorage.Shared.Utils.MountedAim)
local Validate = require(ReplicatedStorage.Shared.Validate)
local BowController = Knit.CreateController({ Name = "BowController" })

local Player = Players.LocalPlayer
local BowService
local InventoryService
local CameraController
local CursorController
local FocusController
local BowSoundController
local RangedWeaponEffectsController
local AimEvent: UnreliableRemoteEvent
local Character: Model? = nil
local Tracks: { [string]: AnimationTrack } = {}
local NockedArrows: { [Model]: { Arrow: BasePart } } = {}
local CharacterConnections: { RBXScriptConnection } = {}
local Holding = false
local WindowFocused = true
local FocusActive = false
local FocusStillSince: number? = nil
local Started: number? = nil
local Seed = 0
local ArrowCount = 0
local AmmoCounts: { [string]: number } = {}
local LastAimUpdate = 0
local NextShot = 0
local ReloadSoundSequence = 0
local ReloadSequence = 0
local ReloadPending = false
local ReloadShotConnection: RBXScriptConnection? = nil
local ReloadEndConnection: RBXScriptConnection? = nil
local ReloadLengthConnection: RBXScriptConnection? = nil
local PlayTransitionAnimation: (boolean) -> ()
local AimParams = RaycastParams.new()
AimParams.FilterType = Enum.RaycastFilterType.Exclude
AimParams.IgnoreWater = true

local RangedAnimationIds: { [string]: boolean } = {}
for _, ItemName in { "Bow", "Tanegashima" } do
	for _, Animation in RangedWeaponConfig.Get(ItemName).Animations do
		RangedAnimationIds[Animation.Id:match("%d+") or Animation.Id] = true
	end
end

local function StopReload()
	ReloadSequence += 1
	ReloadPending = false
	if ReloadShotConnection then
		ReloadShotConnection:Disconnect()
		ReloadShotConnection = nil
	end
	if ReloadEndConnection then
		ReloadEndConnection:Disconnect()
		ReloadEndConnection = nil
	end
	if ReloadLengthConnection then
		ReloadLengthConnection:Disconnect()
		ReloadLengthConnection = nil
	end

	local Reload = Tracks.Reload
	if Reload then
		Reload:Stop(0.1)
	end
end

local function UpdateReloadTiming()
	local Reload = Tracks.Reload
	if not ReloadPending or not Reload then
		return
	end

	local Remaining = NextShot - workspace:GetServerTimeNow()
	if Remaining <= 0 then
		StopReload()
		return
	end
	if Reload.IsPlaying and Reload.Length > 0 then
		Reload:AdjustSpeed(math.max(0.001, Reload.Length - Reload.TimePosition) / Remaining)
	end

	local Sequence = ReloadSequence
	task.delay(Remaining, function()
		if Sequence == ReloadSequence and workspace:GetServerTimeNow() >= NextShot then
			StopReload()
		end
	end)
end

local function StopEquipmentAnimations(Target: Model?)
	StopReload()
	local ToStop: { [AnimationTrack]: boolean } = {}
	for _, Track in Tracks do
		ToStop[Track] = true
	end

	local Humanoid = Target and Target:FindFirstChildWhichIsA("Humanoid")
	local Animator = Humanoid and Humanoid:FindFirstChildWhichIsA("Animator")
	if Animator then
		for _, Track in Animator:GetPlayingAnimationTracks() do
			local Animation = Track.Animation
			local Id = Animation and (Animation.AnimationId:match("%d+") or Animation.AnimationId)
			if Track:GetAttribute("RangedWeaponAnimation") or (Id and RangedAnimationIds[Id]) then
				ToStop[Track] = true
			end
		end
	end

	for Track in ToStop do
		-- Destroying an AnimationTrack alone can leave its animation playing on the Animator.
		Track:Stop(0)
		Track:Destroy()
	end
	table.clear(Tracks)
end

local function IsBlocked(): boolean
	if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then
		return true
	end

	local PlayerGui = Player:FindFirstChildWhichIsA("PlayerGui")
	local MainMenu = PlayerGui and PlayerGui:FindFirstChild("MainMenu") :: ScreenGui?
	local Menus = PlayerGui and PlayerGui:FindFirstChild("Menu")
	if MainMenu and MainMenu.Enabled then
		return true
	end
	if Menus then
		for _, Menu in Menus:GetChildren() do
			if Menu:IsA("ScreenGui") and Menu.Enabled then
				return true
			end
		end
	end

	return false
end

local function StopDraw()
	Holding = false
	Started = nil
	if BowSoundController and Character then
		BowSoundController:StopCharging(Character)
	end
	if RangedWeaponEffectsController and Character then
		RangedWeaponEffectsController:SetAiming(Character, false)
	end
	if CameraController then
		CameraController:SetBowDrawSway(nil)
	end
	for Name, Track in Tracks do
		if Name ~= "Pose" and Name ~= "Unequip" and Name ~= "Reload" then
			Track:Stop(0.12)
		end
	end
end

local function ScheduleReload(Shot: AnimationTrack)
	StopReload()
	local Reload = Tracks.Reload
	local Shooter = Character
	local ItemName = BowConfig.WeaponName
	if not Reload or not Shooter then
		return
	end

	ReloadPending = true
	local Sequence = ReloadSequence
	ReloadLengthConnection = Reload:GetPropertyChangedSignal("Length"):Connect(UpdateReloadTiming)
	UpdateReloadTiming()
	if not ReloadPending then
		return
	end

	local function IsCurrent(): boolean
		return Sequence == ReloadSequence and Character == Shooter and Shooter.Parent ~= nil
			and Tracks.Reload == Reload and BowConfig.WeaponName == ItemName
			and Shooter:GetAttribute("BowEquipped") == true and BowConfig.CanUse(Shooter)
	end

	local function StartReload()
		if Sequence ~= ReloadSequence then
			return
		end
		ReloadShotConnection = nil
		if not IsCurrent() or workspace:GetServerTimeNow() >= NextShot then
			StopReload()
			return
		end

		local Hold = Tracks.Hold
		if Hold then
			Hold:Stop(0.1)
		end
		ReloadEndConnection = Reload.Ended:Once(function()
			if Sequence == ReloadSequence then
				ReloadEndConnection = nil
				StopReload()
			end
		end)
		Reload:Play(0.1, 1, 1)
		UpdateReloadTiming()
	end

	if Shot.IsPlaying then
		ReloadShotConnection = Shot.Ended:Once(StartReload)
	else
		StartReload()
	end
end

local function ScheduleReadySound(ReadyAt: number, ItemName: string)
	local Shooter = Character
	ReloadSoundSequence += 1
	local Sequence = ReloadSoundSequence
	task.delay(math.max(0, ReadyAt - workspace:GetServerTimeNow()), function()
		if Shooter and Shooter == Character and Shooter.Parent and ReloadSoundSequence == Sequence
			and not Shooter:GetAttribute("Died") then
			RangedWeaponEffectsController:PlayReadySound(Shooter, ItemName)
		end
	end)
end

local function CanFocusZoom(): boolean
	if not Character or not WindowFocused
		or not (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
		return false
	end

	return RangedWeaponConfig.CanFocus(Character, FocusActive)
end

local function UpdateFocusZoom(Eligible: boolean): boolean
	if not Eligible or not CanFocusZoom() then
		FocusActive = false
		FocusStillSince = nil
		return false
	end

	local Now = os.clock()
	FocusStillSince = FocusStillSince or Now
	if Now - FocusStillSince >= BowConfig.FocusSettleTime then
		FocusActive = true
	end
	return FocusActive
end

local function ClearEquipmentVisuals()
	StopDraw()
	StopEquipmentAnimations(Character)

	UpdateFocusZoom(false)
	CameraController:SetBowFocusZoom(false)
	CameraController:SetForcedShiftLock("Bow", false)
	FocusController:SetActive(false)
	CursorController:SetVisible(false)
end

local function StopTransitionAnimations()
	for _, Name in { "Equip", "Unequip" } do
		local Track = Tracks[Name]
		if Track and Track.IsPlaying then
			Track:Stop(0.08)
		end
	end
end

local function StopPose()
	local Pose = Tracks.Pose
	if Pose and Pose.IsPlaying then
		Pose:Stop(0)
	end
end

function BowController:CancelDraw()
	if Holding or Started then
		BowService.Request:Fire("Cancel")
	end
	StopDraw()
end

function BowController:EquipSword(): boolean
	if not Character or not Character:GetAttribute("BowEquipped") or IsBlocked()
		or not Validate:CanEquipWeapon(Character, true) then
		return false
	end

	self:CancelDraw()
	ClearEquipmentVisuals()
	BowService.Request:Fire("EquipSword")
	return true
end

local function GetAimPoint(): Vector3
	local Camera = workspace.CurrentCamera
	local Origin = Camera.CFrame.Position
	local Target = MountedAim.ClampTarget(Character, Origin, Origin + Camera.CFrame.LookVector * BowConfig.MaxDistance)
	local Direction = Target - Origin
	AimParams.FilterDescendantsInstances = BowRaycast.GetExclusions(Character)
	local Hit = BowRaycast.Aim(Origin, Direction, AimParams)
	local Point = if Hit then Hit.Position else Target
	local BowOrigin = Character and BowConfig.GetOrigin(Character)
	return MountedAim.ClampTarget(Character, BowOrigin or Origin, Point)
end

local function UpdateAmmo(Items: { any })
	table.clear(AmmoCounts)
	for _, Item in Items do
		AmmoCounts[Item.Name] = (AmmoCounts[Item.Name] or 0) + (Item.Stack or 0)
	end

	ArrowCount = RangedWeaponConfig.GetAmmoCount(BowConfig, AmmoCounts)
end

local function UpdateNock(Target: Model)
	local Existing = NockedArrows[Target]
	if not Target.Parent or not Target:GetAttribute("BowDrawing") or not Target:GetAttribute("BowEquipped")
		or RangedWeaponConfig.GetForCharacter(Target).IsFirearm then
		if Existing then
			Existing.Arrow:Destroy()
			NockedArrows[Target] = nil
		end
		return
	end
	if Existing and Existing.Arrow.Parent then
		return
	end

	local Bow = Target:FindFirstChild("BowModel") :: Model?
	local Hand = Target:FindFirstChild("RightHand") :: BasePart?
	local HandOffset = CFrame.identity
	if not Hand then
		Hand = Target:FindFirstChild("Right Arm") :: BasePart?
		if Hand then
			HandOffset = CFrame.new(0, -Hand.Size.Y * 0.5, 0)
		end
	end
	if not Bow or not Hand then
		return
	end
	local Arrow = ReplicatedStorage.Assets.Models.Bow.Arrow:Clone() :: BasePart
	Arrow.Name = "NockedArrow"
	Arrow.Anchored = false
	Arrow.Massless = true
	Arrow.CanCollide = false
	Arrow.CanTouch = false
	Arrow.CanQuery = false
	local Offset = HandOffset * BowConfig.GetNockedArrowOffset(Arrow.Size.Z)
	Arrow.CFrame = Hand.CFrame * Offset

	local Weld = Instance.new("Weld")
	Weld.Name = "NockedArrowGrip"
	Weld.Part0 = Hand
	Weld.Part1 = Arrow
	Weld.C0 = Offset
	Weld.Parent = Arrow
	Arrow.Parent = Bow
	NockedArrows[Target] = { Arrow = Arrow }
end

local function BindNock(Target: Model)
	Target:GetAttributeChangedSignal("BowDrawing"):Connect(function()
		UpdateNock(Target)
	end)
	Target:GetAttributeChangedSignal("BowEquipped"):Connect(function()
		UpdateNock(Target)
	end)
	Target.ChildAdded:Connect(function(Child: Instance)
		if Child.Name == "BowModel" or Child.Name == "RightHand" or Child.Name == "Right Arm" then
			UpdateNock(Target)
		end
	end)
	Target.Destroying:Once(function()
		NockedArrows[Target] = nil
	end)
	UpdateNock(Target)
end

local function BindCharacter(NewCharacter: Model)
	BowController:CancelDraw()
	for _, Connection in CharacterConnections do
		Connection:Disconnect()
	end
	table.clear(CharacterConnections)
	StopEquipmentAnimations(Character)
	Character = NewCharacter
	StopEquipmentAnimations(NewCharacter)
	BowConfig = RangedWeaponConfig.GetForCharacter(NewCharacter)
	ArrowCount = RangedWeaponConfig.GetAmmoCount(BowConfig, AmmoCounts)
	UpdateFocusZoom(false)
	CameraController:SetBowFocusZoom(false)
	FocusController:SetActive(false)
	CameraController:SetForcedShiftLock("Bow", false)
	NextShot = 0

	table.insert(CharacterConnections, NewCharacter:GetAttributeChangedSignal("Bow"):Connect(function()
		BowController:CancelDraw()
		StopEquipmentAnimations(NewCharacter)

		BowConfig = RangedWeaponConfig.GetForCharacter(NewCharacter)
		ArrowCount = RangedWeaponConfig.GetAmmoCount(BowConfig, AmmoCounts)
		if not NewCharacter:GetAttribute("Bow") then
			ClearEquipmentVisuals()
		end
	end))

	for _, Attribute in BowConfig.CancelAttributes do
		table.insert(CharacterConnections, NewCharacter:GetAttributeChangedSignal(Attribute):Connect(function()
			if NewCharacter:GetAttribute(Attribute) then
				BowController:CancelDraw()
				StopReload()
				StopTransitionAnimations()
				StopPose()
			end
		end))
	end
	table.insert(CharacterConnections, NewCharacter:GetAttributeChangedSignal("BowEquipped"):Connect(function()
		if NewCharacter:GetAttribute("BowEquipped") then
			PlayTransitionAnimation(true)
		else
			BowController:CancelDraw()
			ClearEquipmentVisuals()
			if not NewCharacter:GetAttribute("WeaponEquipped")
				and NewCharacter:GetAttribute("Bow") and NewCharacter:FindFirstChild("BowModel") then
				PlayTransitionAnimation(false)
			end
		end
	end))
	table.insert(CharacterConnections, NewCharacter:GetAttributeChangedSignal("WeaponEquipped"):Connect(function()
		if NewCharacter:GetAttribute("WeaponEquipped") then
			ClearEquipmentVisuals()
		end
	end))
end

local function LoadTracks()
	if not Character or Tracks.Pose then
		return
	end

	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	local Animator = Humanoid and Humanoid:FindFirstChildWhichIsA("Animator")
	if not Animator then
		return
	end
	for Name, Data in BowConfig.Animations do
		local Animation = ReplicatedStorage.Assets.Animations.Bow:FindFirstChild(Data.Name) :: Animation?
		if not Animation then
			Animation = Instance.new("Animation")
			Animation.Name = Data.Name
			Animation.Parent = ReplicatedStorage.Assets.Animations.Bow
		end
		Animation.AnimationId = Data.Id

		local Track = Animator:LoadAnimation(Animation)
		Track.Name = Data.Name
		Track:SetAttribute("RangedWeaponAnimation", true)
		Track.Priority = if BowConfig.IsFirearm and Name == "Shot" then Enum.AnimationPriority.Action4
			elseif Name == "Pose" then Enum.AnimationPriority.Action
			elseif Name == "Equip" or Name == "Unequip" then Enum.AnimationPriority.Action2 else Enum.AnimationPriority.Action3
		-- The looped shot variant plays one recovery cycle for each fully charged arrow.
		Track.Looped = Name == "Hold" or Name == "Pose"
		Tracks[Name] = Track
	end
end

PlayTransitionAnimation = function(InHand: boolean)
	if not Character or not BowConfig.CanUse(Character) then
		return
	end

	LoadTracks()
	StopTransitionAnimations()
	local Track = Tracks[if InHand then "Equip" else "Unequip"]
	if Track then
		Track:Play(0.1)
	end
end

local function UpdatePose()
	if not Character or not Character:GetAttribute("Bow") or not Character:FindFirstChild("BowModel")
		or not BowConfig.CanUse(Character) then
		StopPose()
		return
	end

	LoadTracks()
	local Pose = Tracks.Pose
	if Pose and not Pose.IsPlaying then
		-- Only the keyed bow/arm joints override the default walk and run animations.
		Pose:Play(0.15)
	end
end

local function HoldDrawPose()
	if ReloadPending then
		return
	end

	local Hold = Tracks.Hold
	local Aim = Tracks.Aim
	if Hold and Hold.Length > 0 then
		if not Hold.IsPlaying then
			if Aim then
				Aim:Stop(0.1)
			end
			Hold:Play(0.1)
		end
	elseif Aim and Aim.Length > 0 and (not Aim.IsPlaying or Aim.Speed ~= 0) then
		-- Preserve the drawn pose while the hold asset is unavailable or still loading.
		if not Aim.IsPlaying then
			Aim:Play(0.05, 1, 0)
		end
		Aim:AdjustSpeed(0)
		Aim.TimePosition = math.max(0, Aim.Length - 0.001)
	end
end

function BowController:BeginDraw()
	if not Character or Holding or (not BowConfig.IsFirearm and (ArrowCount <= 0 or workspace:GetServerTimeNow() < NextShot))
		or not BowConfig.CanUse(Character) or not Character:GetAttribute("BowEquipped") or IsBlocked() then
		return
	end

	Holding = true
	Started = workspace:GetServerTimeNow()
	Seed = 0
	CameraController:SetBowDrawSway(Started, Seed)
	LoadTracks()
	StopTransitionAnimations()
	if BowConfig.IsFirearm then
		if not ReloadPending then
			Tracks.Hold:Play(0.12)
		end
		RangedWeaponEffectsController:SetAiming(Character, true)
	elseif Tracks.Aim then
		local Duration = if Tracks.Aim.Length > 0 then Tracks.Aim.Length else BowConfig.FullChargeTime
		Tracks.Aim:Play(0.12, 1, Duration / BowConfig.FullChargeTime)
	end
	BowService.Request:Fire("Begin", GetAimPoint())
end

function BowController:ShootFirearm()
	if not BowConfig.IsFirearm or not Character or not Holding or not Started or not WindowFocused or IsBlocked()
		or not Character:GetAttribute("BowEquipped") or not BowConfig.CanUse(Character)
		or workspace:GetServerTimeNow() < NextShot then
		return
	end

	LoadTracks()
	NextShot = workspace:GetServerTimeNow() + RangedWeaponConfig.GetShotCooldown(BowConfig, Player)
	BowService.Request:Fire("Shoot", GetAimPoint(), FocusActive and CanFocusZoom())
end

local function InputAction(Action: string, State: Enum.UserInputState): Enum.ContextActionResult
	if UserInputService:GetFocusedTextBox() or not Character then
		return Enum.ContextActionResult.Pass
	end

	if Action == "BowToggle" then
		if State == Enum.UserInputState.Begin and not IsBlocked() then
			BowController:CancelDraw()
			BowService.Request:Fire("Toggle")
		end
		return Enum.ContextActionResult.Pass
	end
	if not Character:GetAttribute("BowEquipped") then
		return Enum.ContextActionResult.Pass
	end

	if BowConfig.IsFirearm then
		if Action == "BowCancel" then
			if State == Enum.UserInputState.Begin then
				BowController:BeginDraw()
			elseif State == Enum.UserInputState.End or State == Enum.UserInputState.Cancel then
				BowController:CancelDraw()
			end
		elseif Action == "BowDraw" and State == Enum.UserInputState.Begin then
			BowController:ShootFirearm()
		end

		return if IsBlocked() then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
	end

	if Action == "BowCancel" and State == Enum.UserInputState.Begin then
		BowController:CancelDraw()
	elseif Action == "BowDraw" then
		if State == Enum.UserInputState.Begin then
			BowController:BeginDraw()
		elseif State == Enum.UserInputState.End and Holding then
			local Now = workspace:GetServerTimeNow()
			if not Started or Now - Started < BowConfig.MinDrawTime then
				BowController:CancelDraw()
			else
				BowService.Request:Fire("Release", GetAimPoint())
				NextShot = Now + RangedWeaponConfig.GetShotCooldown(BowConfig, Player)
				StopDraw()
			end
		elseif State == Enum.UserInputState.Cancel then
			BowController:CancelDraw()
		end
	end

	return if IsBlocked() then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
end

local function Render()
	local Camera = workspace.CurrentCamera
	local Equipped = Character and Character.Parent and Character:GetAttribute("BowEquipped") == true
		and Character:GetAttribute("Bow") ~= nil and Character:FindFirstChild("BowModel") ~= nil
		and not Character:GetAttribute("WeaponEquipped")
	if Equipped then
		UpdatePose()
	else
		StopPose()
	end

	local Active = Equipped
		and Character and not Character:GetAttribute("Ragdoll") and not Character:GetAttribute("Downed")
		and not Character:GetAttribute("Died") and not Character:GetAttribute("Meditating")
		and not Character:GetAttribute("CameraCutscene") and not Character:GetAttribute("RealmTeleporting")
		and Camera and Camera.CameraType == Enum.CameraType.Custom and not IsBlocked()
	local Focusing = UpdateFocusZoom(Active == true)
	CameraController:SetBowFocusZoom(Focusing)
	FocusController:SetActive(Focusing and Player:GetAttribute("FovEffects") == true)
	CameraController:SetForcedShiftLock("Bow", Active == true)
	CursorController:SetVisible(Active == true)
	if not Active or not Character then
		if Holding then
			BowController:CancelDraw()
		end
		return
	end
	if Holding and not BowConfig.CanUse(Character) then
		BowController:CancelDraw()
	end

	local Now = workspace:GetServerTimeNow()
	local Elapsed = if Started then math.max(0, Now - Started) else nil
	local Origin = BowConfig.GetOrigin(Character)
	local CursorPosition = Camera.ViewportSize * 0.5
	if Origin and Elapsed then
		local Aim = GetAimPoint()
		local Target = BowConfig.GetAimTarget(Origin, Aim, Elapsed, Seed)
		Target = MountedAim.ClampTarget(Character, Origin, Target)
		local Point = Camera:WorldToViewportPoint(Target)
		if Point.Z > 0 then
			CursorPosition = Vector2.new(
				math.clamp(Point.X, 12, math.max(12, Camera.ViewportSize.X - 12)),
				math.clamp(Point.Y, 12, math.max(12, Camera.ViewportSize.Y - 12))
			)
		end
		if Now - LastAimUpdate >= BowConfig.AimUpdateInterval then
			LastAimUpdate = Now
			AimEvent:FireServer(Aim)
		end
		if BowConfig.IsFirearm or Elapsed >= BowConfig.FullChargeTime then
			HoldDrawPose()
		elseif Tracks.Aim and Tracks.Aim.Length > 0 then
			local Speed = Tracks.Aim.Length / BowConfig.FullChargeTime
			if math.abs(Tracks.Aim.Speed - Speed) > 0.001 then
				Tracks.Aim:AdjustSpeed(Speed)
				Tracks.Aim.TimePosition = Elapsed * Speed
			end
		end
	end
	CursorController:Update(CursorPosition, Elapsed, ArrowCount, BowConfig, AmmoCounts, Focusing)
end

function BowController.KnitStart()
	BowService = Knit.GetService("BowService")
	InventoryService = Knit.GetService("InventoryService")
	CameraController = Knit.GetController("CameraController")
	CursorController = Knit.GetController("BowCursorController")
	FocusController = Knit.GetController("BowFocusController")
	BowSoundController = Knit.GetController("BowSoundController")
	RangedWeaponEffectsController = Knit.GetController("RangedWeaponEffectsController")
	AimEvent = ReplicatedStorage.Assets.Events:WaitForChild("BowAim") :: UnreliableRemoteEvent
	InventoryService.InventoryUpdated:Connect(UpdateAmmo)
	task.spawn(function()
		UpdateAmmo(InventoryService:GetInventory())
	end)
	BowService.Feedback:Connect(function(Action: string, Value: number?, NewSeed: number?, WeaponName: string?, ReadyAt: number?)
		if Action == "Draw" then
			if Holding then
				Started = Value
				Seed = NewSeed or 0
				CameraController:SetBowDrawSway(Started, Seed)
			end
		elseif Action == "Shot" then
			local ShotConfig = if WeaponName then RangedWeaponConfig.Get(WeaponName) else BowConfig
			local SameWeapon = ShotConfig.WeaponName == BowConfig.WeaponName
			if not ShotConfig.IsFirearm and SameWeapon then
				StopDraw()
			end
			NextShot = ReadyAt or (workspace:GetServerTimeNow() + RangedWeaponConfig.GetShotCooldown(ShotConfig, Player))
			if ShotConfig.IsFirearm then
				ScheduleReadySound(NextShot, ShotConfig.WeaponName)
			end
			local Charge = Value or 0
			local Track = if ShotConfig.IsFirearm then Tracks.Shot elseif Charge >= 1 then Tracks.ShotLooped
				elseif Charge < 0.2 then Tracks.Shoot else Tracks.Shot
			if SameWeapon and Track and Character and Character:GetAttribute("BowEquipped") and BowConfig.CanUse(Character) then
				Track:Play(0.05)
				if ShotConfig.IsFirearm then
					ScheduleReload(Track)
				end
			end
		elseif Action == "Cooldown" and WeaponName == "Tanegashima" and BowConfig.WeaponName == WeaponName and Value then
			local WasReloading = ReloadPending or NextShot > workspace:GetServerTimeNow()
			NextShot = Value
			if WasReloading or NextShot > workspace:GetServerTimeNow() then
				ScheduleReadySound(NextShot, WeaponName)
				UpdateReloadTiming()
			end
		elseif Action == "Cancel" then
			StopDraw()
		elseif Action == "Unequipped" then
			ClearEquipmentVisuals()
		end
	end)

	ContextActionService:BindActionAtPriority("BowToggle", InputAction, false, 3000, Enum.KeyCode.B)
	ContextActionService:BindActionAtPriority("BowDraw", InputAction, false, 3000, Enum.UserInputType.MouseButton1)
	ContextActionService:BindActionAtPriority("BowCancel", InputAction, false, 3000, Enum.UserInputType.MouseButton2)
	UserInputService.WindowFocusReleased:Connect(function()
		WindowFocused = false
		UpdateFocusZoom(false)
		CameraController:SetBowFocusZoom(false)
		FocusController:SetActive(false)
		BowController:CancelDraw()
	end)
	UserInputService.WindowFocused:Connect(function()
		WindowFocused = true
	end)
	Player.CharacterAdded:Connect(BindCharacter)
	Player.CharacterRemoving:Connect(function(Removing: Model)
		if Character == Removing then
			BowController:CancelDraw()
			ClearEquipmentVisuals()
			Character = nil
			UpdateFocusZoom(false)
			CameraController:SetBowFocusZoom(false)
			FocusController:SetActive(false)
			CameraController:SetForcedShiftLock("Bow", false)
			CursorController:SetVisible(false)
		end
	end)
	if Player.Character then
		task.spawn(BindCharacter, Player.Character)
	end

	local function ObservePlayer(Other: Player)
		Other.CharacterAdded:Connect(BindNock)
		if Other.Character then
			BindNock(Other.Character)
		end
	end
	Players.PlayerAdded:Connect(ObservePlayer)
	for _, Other in Players:GetPlayers() do
		ObservePlayer(Other)
	end
	RunService:BindToRenderStep("BowAim", Enum.RenderPriority.Camera.Value + 6, Render)
end

return BowController
