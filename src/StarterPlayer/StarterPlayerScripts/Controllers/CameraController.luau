local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local SharedConstants = require(ReplicatedStorage.Shared.Constants)
local CameraShaker = require(ReplicatedStorage.Assets.Libraries.CameraShaker)
local BowConfig = require(ReplicatedStorage.Shared.BowConfig)
local RangedWeaponConfig = require(ReplicatedStorage.Shared.RangedWeaponConfig)
local ShouldFaceAim = require(ReplicatedStorage.Shared.Utils.ShouldFaceAim)
local MountedAim = require(ReplicatedStorage.Shared.Utils.MountedAim)
local CameraUtils = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
	:WaitForChild("CameraModule"):WaitForChild("CameraUtils") :: ModuleScript)

local CameraController = Knit.CreateController({ Name = "CameraController" })

local COMBAT_MIN_ZOOM = 4
local COMBAT_MAX_ZOOM = 12
local SHOULDER_OFFSET = Vector2.new(2.15, 0.25)
local SHOULDER_RESPONSE = 10
local ANIMATION_INFLUENCE = 0.18
local MAX_CAMERA_ROLL = math.rad(0.35)
local MOVEMENT_TURN_RESPONSE = 8
local AIM_TURN_RESPONSE = 32
local COLLISION_RADIUS = 0.35

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Character: Model? = nil
local Humanoid: Humanoid? = nil
local RootPart: BasePart? = nil
local Torso: BasePart? = nil
local HeadSubject: BasePart? = nil
local camShake
local LerpAlpha = 0.35
local HeadSubjectCFrame: CFrame? = nil
local CustomOffsetCFrame: CFrame? = nil
local SmoothedOffset = Vector3.new(0, 0.9, 0)
local ShoulderSide = 1
local SmoothedShoulderSide = 1
local ShoulderBlend = 0
local CameraRoll = 0
local CharacterRotation: CFrame? = nil
local TransitionCapture: CFrame? = nil
local TransitionFocusCapture: Vector3? = nil
local TransitionOffset: CFrame? = nil
local TransitionFocusOffset = Vector3.zero
local TransitionWeight = 0
local SavedZoomBounds: Vector2? = nil
local ZoomRestoreBounds: Vector2? = nil
local PendingZoomDistance: number? = nil
local AppliedCamera: Camera? = nil
local NativeCFrame: CFrame? = nil
local NativeFocus: CFrame? = nil
local PresentedCFrame: CFrame? = nil
local ShakeCamera: Camera? = nil
local UnshakenCFrame: CFrame? = nil
local ShakenCFrame: CFrame? = nil
local FovPulse: Tween? = nil
local FovPulseRevision = 0
local ForcedShiftLocks: { [string]: boolean } = {}
local SavedMouseIcon: boolean? = nil
local ForcedMouseApplied = false
local MenuMouseApplied = false
local SavedMenuMouseIcon: boolean? = nil
local HotbarController
local BowDrawStarted: number? = nil
local BowDrawSeed = 0
local BowFocusZoom = false
local BowFovTween: Tween? = nil
local BowFovCamera: Camera? = nil
local BowFovBase: number? = nil
local SavedBowSensitivity: number? = nil
local AppliedBowSensitivity: number? = nil
local SmoothedBowSway = CFrame.identity
local LastShakeTime: number? = nil

local function IsMenuMouseUnlocked(): boolean
	local PlayerGui = Player:FindFirstChildWhichIsA("PlayerGui")
	local Menus = PlayerGui and PlayerGui:FindFirstChild("Menu")
	local MainMenu = PlayerGui and (PlayerGui:FindFirstChild("MainMenu") or (Menus and Menus:FindFirstChild("MainMenu"))) :: ScreenGui?

	return (MainMenu ~= nil and MainMenu.Enabled) or (HotbarController ~= nil and HotbarController:IsSelectingSlot())
end

function CameraController:IsMouseUnlocked(): boolean
	return IsMenuMouseUnlocked()
end

local function IsShiftLocked(): boolean
	return not IsMenuMouseUnlocked() and (Player:GetAttribute("MouseLocked") == true or next(ForcedShiftLocks) ~= nil)
end

local function ReleaseForcedMouse()
	if not ForcedMouseApplied then
		return
	end

	-- Share the native camera's override so it never saves our LockCenter as its baseline.
	CameraUtils.restoreMouseBehavior()
	if SavedMouseIcon ~= nil then
		UserInputService.MouseIconEnabled = SavedMouseIcon
	end
	SavedMouseIcon = nil
	ForcedMouseApplied = false
end

local function UpdateMenuMouse()
	if IsMenuMouseUnlocked() then
		if not MenuMouseApplied then
			ReleaseForcedMouse()
			SavedMenuMouseIcon = UserInputService.MouseIconEnabled
			MenuMouseApplied = true
		end

		CameraUtils.setMouseBehaviorOverride(Enum.MouseBehavior.Default)
		UserInputService.MouseIconEnabled = true
	elseif MenuMouseApplied then
		CameraUtils.restoreMouseBehavior()
		if SavedMenuMouseIcon ~= nil then
			UserInputService.MouseIconEnabled = SavedMenuMouseIcon
		end
		SavedMenuMouseIcon = nil
		MenuMouseApplied = false
	end
end

function CameraController:SetForcedShiftLock(Source: string, Enabled: boolean)
	if (ForcedShiftLocks[Source] == true) == Enabled then
		return
	end

	if Enabled then
		ForcedShiftLocks[Source] = true
	else
		ForcedShiftLocks[Source] = nil
		if next(ForcedShiftLocks) == nil then
			ReleaseForcedMouse()
		end
	end
end

local CollisionParams = RaycastParams.new()
CollisionParams.FilterType = Enum.RaycastFilterType.Exclude
CollisionParams.RespectCanCollide = true
CollisionParams.IgnoreWater = true

local function SmoothingAlpha(Response: number, DeltaTime: number): number
	return 1 - math.exp(-Response * math.max(DeltaTime, 0))
end

local function IsGameplayCamera(): boolean
	if not Camera or not Character or not Character.Parent then
		return false
	end
	if Character:GetAttribute("CameraCutscene") or Character:GetAttribute("RealmTeleporting") then
		return false
	end

	return Camera.CameraType == Enum.CameraType.Custom or Character:GetAttribute("LockedOnEnemy") == true
end

local function ClearBowFieldOfView(Restore: boolean)
	local PreviousTween, PreviousCamera, PreviousBase = BowFovTween, BowFovCamera, BowFovBase
	BowFovTween = nil
	BowFovCamera = nil
	BowFovBase = nil

	local CanRestore = not PreviousTween or PreviousTween.PlaybackState ~= Enum.PlaybackState.Cancelled
	if PreviousTween then
		PreviousTween:Cancel()
	end
	if Restore and CanRestore and PreviousCamera and PreviousBase then
		PreviousCamera.FieldOfView = PreviousBase
	end
end

local function UpdateBowSensitivity()
	if not IsGameplayCamera() or (BowDrawStarted == nil and not BowFocusZoom) then
		if SavedBowSensitivity ~= nil and UserInputService.MouseDeltaSensitivity == AppliedBowSensitivity then
			UserInputService.MouseDeltaSensitivity = SavedBowSensitivity
		end
		SavedBowSensitivity = nil
		AppliedBowSensitivity = nil
		return
	end

	if SavedBowSensitivity == nil then
		SavedBowSensitivity = UserInputService.MouseDeltaSensitivity
	end
	local Multiplier = if BowFocusZoom then BowConfig.FocusSensitivityMultiplier else BowConfig.AimSensitivityMultiplier
	UserInputService.MouseDeltaSensitivity = SavedBowSensitivity * Multiplier
	AppliedBowSensitivity = UserInputService.MouseDeltaSensitivity
end

local function UpdateBowFieldOfView(TransitionTime: number?)
	if BowFovCamera and (BowFovCamera ~= Camera or not IsGameplayCamera()) then
		ClearBowFieldOfView(true)
	end
	local EffectsEnabled = Player:GetAttribute("FovEffects") == true and IsGameplayCamera()
	local Drawing = BowDrawStarted ~= nil and EffectsEnabled
	local Focusing = BowFocusZoom and EffectsEnabled
	local Active = Drawing or Focusing
	if Active and not BowFovCamera then
		BowFovCamera = Camera
		BowFovBase = Camera.FieldOfView
	end
	if not BowFovCamera or not BowFovBase then
		return
	end

	local PreviousTween = BowFovTween
	BowFovTween = nil
	if PreviousTween then
		PreviousTween:Cancel()
	end

	local Target = BowFovBase - (if Drawing then BowConfig.DrawFovReduction else 0)
		- (if Focusing then BowConfig.FocusFovReduction else 0)
	local Config = RangedWeaponConfig.GetForCharacter(Player.Character)
	local Duration = TransitionTime or (if Drawing then Config.AimTransitionTime or BowConfig.FullChargeTime else BowConfig.DrawFovRestoreTime)
	local Tween = TweenService:Create(BowFovCamera, TweenInfo.new(Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		FieldOfView = math.clamp(Target, 1, 120),
	})
	BowFovTween = Tween
	Tween.Completed:Once(function(State: Enum.PlaybackState)
		if BowFovTween == Tween and (not Active or State ~= Enum.PlaybackState.Completed) then
			ClearBowFieldOfView(false)
		end
	end)
	Tween:Play()
end

function CameraController:SetBowFocusZoom(Enabled: boolean)
	if BowFocusZoom == Enabled then
		return
	end

	BowFocusZoom = Enabled
	UpdateBowSensitivity()
	UpdateBowFieldOfView(BowConfig.FocusFovTransitionTime)
end

function CameraController:SetBowDrawSway(StartedAt: number?, Seed: number?)
	local WasDrawing = BowDrawStarted ~= nil
	BowDrawStarted = StartedAt
	BowDrawSeed = Seed or 0

	if WasDrawing ~= (StartedAt ~= nil) then
		UpdateBowSensitivity()
		UpdateBowFieldOfView()
	end
end

local function ApplyForcedShiftLock()
	if not IsMenuMouseUnlocked() and next(ForcedShiftLocks) ~= nil and IsGameplayCamera() and Character
		and not Character:GetAttribute("Ragdoll") and not Character:GetAttribute("Downed")
		and not Character:GetAttribute("Died") and not Character:GetAttribute("Meditating") then
		if not ForcedMouseApplied then
			SavedMouseIcon = UserInputService.MouseIconEnabled
			ForcedMouseApplied = true
		end
		CameraUtils.setMouseBehaviorOverride(Enum.MouseBehavior.LockCenter)
		UserInputService.MouseIconEnabled = false
	else
		ReleaseForcedMouse()
	end
end

function CameraController:GetShoulderSide(): number
	return SmoothedShoulderSide
end

function CameraController:SwapShoulder()
	ShoulderSide = -ShoulderSide
end

local function ClearTransition()
	TransitionCapture = nil
	TransitionFocusCapture = nil
	TransitionOffset = nil
	TransitionWeight = 0
end

local function ClearAppliedFrame()
	AppliedCamera = nil
	NativeCFrame = nil
	NativeFocus = nil
	PresentedCFrame = nil
end

function CameraController:BlendFromCurrentCamera()
	if not Camera then
		return
	end

	TransitionCapture = if ShakeCamera == Camera and Camera.CFrame == ShakenCFrame and UnshakenCFrame
		then UnshakenCFrame else Camera.CFrame
	TransitionFocusCapture = Camera.Focus.Position
	TransitionOffset = nil
	TransitionWeight = 1
end

local function SetZoomBounds(Minimum: number, Maximum: number)
	Player.CameraMinZoomDistance = math.min(Player.CameraMinZoomDistance, Minimum)
	Player.CameraMaxZoomDistance = Maximum
	Player.CameraMinZoomDistance = Minimum
end

local function RestoreZoomBounds()
	local Bounds = SavedZoomBounds or ZoomRestoreBounds
	if Bounds then
		SetZoomBounds(Bounds.X, Bounds.Y)
	end
	SavedZoomBounds = nil
	ZoomRestoreBounds = nil
	PendingZoomDistance = nil
end

function CameraController:GetCombatZoomLimits(): (number, number)
	return COMBAT_MIN_ZOOM, COMBAT_MAX_ZOOM
end

function CameraController:GetCombatZoomDistance(): number
	local Distance = if NativeCFrame and NativeFocus and AppliedCamera == Camera
		then (NativeCFrame.Position - NativeFocus.Position).Magnitude
		else (Camera.CFrame.Position - Camera.Focus.Position).Magnitude

	return math.clamp(Distance, COMBAT_MIN_ZOOM, COMBAT_MAX_ZOOM)
end

function CameraController:SetCombatZoomDistance(Distance: number)
	PendingZoomDistance = math.clamp(Distance, COMBAT_MIN_ZOOM, COMBAT_MAX_ZOOM)
end

local function UpdateCombatZoom()
	if ZoomRestoreBounds then
		SetZoomBounds(ZoomRestoreBounds.X, ZoomRestoreBounds.Y)
		ZoomRestoreBounds = nil
	end

	local Active = Character and IsGameplayCamera()
		and (IsShiftLocked() or Character:GetAttribute("LockedOnEnemy") == true)
	local Bounds = Vector2.new(Player.CameraMinZoomDistance, Player.CameraMaxZoomDistance)

	if Active then
		if not SavedZoomBounds then
			SavedZoomBounds = Bounds
		end

		Bounds = Vector2.new(COMBAT_MIN_ZOOM, COMBAT_MAX_ZOOM)
	elseif SavedZoomBounds then
		Bounds = SavedZoomBounds
		SavedZoomBounds = nil
	end

	if PendingZoomDistance then
		local Distance = math.clamp(PendingZoomDistance, Bounds.X, Bounds.Y)
		ZoomRestoreBounds = Bounds
		PendingZoomDistance = nil
		SetZoomBounds(Distance, Distance)
	else
		SetZoomBounds(Bounds.X, Bounds.Y)
	end
end

local function ApplyTransition(Pose: CFrame, Focus: Vector3, DeltaTime: number): (CFrame, Vector3)
	if TransitionCapture then
		if (Pose.Position - TransitionCapture.Position).Magnitude > 40 then
			ClearTransition()
			return Pose, Focus
		end

		TransitionOffset = Pose:ToObjectSpace(TransitionCapture)
		TransitionFocusOffset = (TransitionFocusCapture or Focus) - Focus
		TransitionCapture = nil
		TransitionFocusCapture = nil
	elseif TransitionOffset then
		TransitionWeight *= math.exp(-12 * math.max(DeltaTime, 0))
	end

	if not TransitionOffset then
		return Pose, Focus
	end
	if TransitionWeight < 0.001 then
		ClearTransition()
		return Pose, Focus
	end

	return Pose * TransitionOffset:Lerp(CFrame.identity, 1 - TransitionWeight), Focus + TransitionFocusOffset * TransitionWeight
end

function CameraController:GetCollisionSafePosition(Origin: Vector3, Position: Vector3): Vector3
	local Direction = Position - Origin
	if Direction.Magnitude < 0.001 then
		return Position
	end

	local Hit = workspace:Spherecast(Origin, COLLISION_RADIUS, Direction, CollisionParams)
	return if Hit then Origin + Direction.Unit * math.max(0, Hit.Distance - 0.1) else Position
end

function CameraController:Shake(Preset: any)
	if camShake and Player:GetAttribute("CameraShake") and IsGameplayCamera() then
		camShake:Shake(Preset)
	end
end

function CameraController:ShakeOnce(Magnitude: number, Roughness: number, FadeInTime: number, FadeOutTime: number)
	if not camShake or not Player:GetAttribute("CameraShake") or not IsGameplayCamera() then
		return
	end

	camShake:ShakeOnce(
		math.clamp(Magnitude, 0, 12),
		math.clamp(Roughness, 0, 30),
		math.max(FadeInTime, 0),
		math.max(FadeOutTime, 0.08),
		Vector3.new(0.1, 0.09, 0.06),
		Vector3.new(0.8, 0.65, 0.3)
	)
end

function CameraController:PulseFieldOfView(Offset: number, Duration: number)
	if not Player:GetAttribute("FovEffects") or not IsGameplayCamera() then
		return
	end

	FovPulseRevision += 1
	local Revision = FovPulseRevision
	if FovPulse then
		FovPulse:Cancel()
	end

	local PulseCamera = Camera
	FovPulse = TweenService:Create(
		PulseCamera,
		TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = math.clamp(SharedConstants.DEFAULT_FIELD_OF_VIEW + Offset, 1, 120) }
	)
	FovPulse.Completed:Once(function(State: Enum.PlaybackState)
		if State ~= Enum.PlaybackState.Completed or Revision ~= FovPulseRevision or Camera ~= PulseCamera then
			return
		end

		FovPulse = TweenService:Create(
			PulseCamera,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ FieldOfView = SharedConstants.DEFAULT_FIELD_OF_VIEW }
		)
		FovPulse:Play()
	end)
	FovPulse:Play()
end

local function UpdateSubject()
	if Camera and Humanoid and HeadSubject then
		Camera.CameraSubject = if Player:GetAttribute("AnimationsInfluence") then HeadSubject else Humanoid
	end
end

local function UpdateFollowSubject(DeltaTime: number)
	if not RootPart or not RootPart.Parent or not Torso or not HeadSubject then
		return
	end

	local Offset = (CustomOffsetCFrame or CameraController:GetDefaultCameraSubjectCFrameOffset()).Position
	if Player:GetAttribute("AnimationsInfluence") and not IsShiftLocked() then
		local AnimationOffset = Torso.Position - RootPart.Position
		Offset += Vector3.new(
			math.clamp(AnimationOffset.X, -1, 1),
			math.clamp(AnimationOffset.Y, -1, 1),
			math.clamp(AnimationOffset.Z, -1, 1)
		) * ANIMATION_INFLUENCE
	end
	if HeadSubjectCFrame then
		Offset = HeadSubjectCFrame.Position - RootPart.Position
	end

	local Alpha = 1 - (1 - LerpAlpha) ^ (math.max(DeltaTime, 0) * 60)
	SmoothedOffset = SmoothedOffset:Lerp(Offset, Alpha)
	HeadSubject.CFrame = CFrame.new(RootPart.Position + SmoothedOffset)
end

local function PrepareNativeCamera(DeltaTime: number)
	UpdateMenuMouse()
	ApplyForcedShiftLock()
	-- Capture transitions from the displayed view, then remove last frame's visual offsets.
	UpdateCombatZoom()

	if Camera and Camera.CameraType == Enum.CameraType.Custom and AppliedCamera == Camera
		and Camera.CFrame == PresentedCFrame and NativeCFrame and NativeFocus
	then
		Camera.CFrame = NativeCFrame
		Camera.Focus = NativeFocus
	end
	ClearAppliedFrame()

	UpdateFollowSubject(DeltaTime)
end

local function ConstrainMountedCamera()
	if Camera and Camera.CameraType == Enum.CameraType.Custom and RootPart and MountedAim.IsActive(Character) then
		Camera.CFrame = MountedAim.ClampCamera(RootPart.CFrame, Camera.CFrame, Camera.Focus.Position)
	end
end

local function UpdateShoulderCamera(DeltaTime: number)
	ApplyForcedShiftLock()
	SmoothedShoulderSide += (ShoulderSide - SmoothedShoulderSide) * SmoothingAlpha(SHOULDER_RESPONSE, DeltaTime)
	if not Camera or not RootPart or not HeadSubject or not Character then
		return
	end

	local Subject = Camera.CameraSubject
	if Camera.CameraType ~= Enum.CameraType.Custom or (Subject ~= Humanoid and Subject ~= HeadSubject) then
		CameraRoll = 0
		return
	end

	local BaseCFrame = Camera.CFrame
	local BaseFocus = Camera.Focus.Position
	local CameraOffset = BaseCFrame.Position - BaseFocus
	local Distance = CameraOffset.Magnitude
	local Active = IsShiftLocked() and Distance > 1
	ShoulderBlend += ((if Active then 1 else 0) - ShoulderBlend) * SmoothingAlpha(SHOULDER_RESPONSE, DeltaTime)

	local RollTarget = 0
	if Player:GetAttribute("CameraTilt") and Active and Humanoid then
		local Strafe = Humanoid.MoveDirection:Dot(BaseCFrame.RightVector)
		RollTarget = -math.clamp(Strafe, -1, 1) * MAX_CAMERA_ROLL
	end
	CameraRoll += (RollTarget - CameraRoll) * SmoothingAlpha(9, DeltaTime)
	if Distance < 0.001 then
		return
	end

	-- Replace the native lateral offset so entering and swapping shoulders blend smoothly.
	local SubjectPosition = if Subject == HeadSubject then HeadSubject.Position else RootPart.Position
	local NativeOffset = if Active then (BaseFocus - SubjectPosition):Dot(BaseCFrame.RightVector) else 0
	local LateralOffset = SmoothedShoulderSide * SHOULDER_OFFSET.X * ShoulderBlend - NativeOffset
	local Offset = BaseCFrame.RightVector * LateralOffset + Vector3.yAxis * SHOULDER_OFFSET.Y * ShoulderBlend
	local Focus = BaseFocus + Offset
	local Pose = CFrame.new(BaseCFrame.Position + Offset) * BaseCFrame.Rotation * CFrame.Angles(0, 0, CameraRoll)
	Pose, Focus = ApplyTransition(Pose, Focus, DeltaTime)
	if MountedAim.IsActive(Character) then
		Pose = MountedAim.ClampCamera(RootPart.CFrame, Pose, Focus)
	end

	if ShoulderBlend > 0.001 or TransitionOffset then
		local Position = CameraController:GetCollisionSafePosition(HeadSubject.Position, Pose.Position)
		Pose = CFrame.new(Position) * Pose.Rotation
	end

	AppliedCamera = Camera
	NativeCFrame = BaseCFrame
	NativeFocus = Camera.Focus
	Camera.Focus = CFrame.new(Focus)
	Camera.CFrame = Pose
	PresentedCFrame = Pose
end

local function UpdateCharacterRotation(DeltaTime: number)
	local Aiming = Character ~= nil and ShouldFaceAim(Character)

	if not Camera or not Character or not RootPart or not RootPart.Parent or RootPart.Anchored or not Humanoid
		or Camera.CameraType ~= Enum.CameraType.Custom or (not IsShiftLocked() and not Aiming)
		or not Humanoid.AutoRotate or Character:GetAttribute("LockedOnEnemy")
		or Character:GetAttribute("Died") or Character:GetAttribute("Downed")
		or Character:GetAttribute("Ragdoll") or Character:GetAttribute("PostureBreak")
		or Character:GetAttribute("HeavyDeflect") or Character:GetAttribute("Meditating")
		or Character:GetAttribute("Climbing") or Character:GetAttribute("WallRunning")
		or Character:GetAttribute("Rolling")
		or Character:GetAttribute("Vaulting") or Character:GetAttribute("CameraCutscene")
		or Character:GetAttribute("RealmTeleporting") or Character:GetAttribute("SkillLockMovement")
		or Humanoid:GetState() == Enum.HumanoidStateType.Seated
	then
		CharacterRotation = nil
		return
	end

	local MouseFacing = RootPart:FindFirstChild("LookAtMouse") :: AlignOrientation?
	if MouseFacing and MouseFacing.Enabled then
		CharacterRotation = nil
		return
	end

	-- Face movement while free; use the native camera direction while attacking, blocking, or drawing.
	local Direction = if Aiming then Camera.CFrame.LookVector else Humanoid.MoveDirection
	Direction *= Vector3.new(1, 0, 1)
	if Direction.Magnitude < 0.001 then
		CharacterRotation = RootPart.CFrame.Rotation
		return
	end

	local Target = CFrame.lookAt(Vector3.zero, Direction)
	CharacterRotation = (CharacterRotation or RootPart.CFrame.Rotation):Lerp(
		Target,
		SmoothingAlpha(if Aiming then AIM_TURN_RESPONSE else MOVEMENT_TURN_RESPONSE, DeltaTime)
	)
	RootPart.CFrame = CFrame.new(RootPart.Position) * CharacterRotation
end

function CameraController:BindShiftLock()
	self:UnbindShiftLock()

	RunService:BindToRenderStep("CameraUpdateFirst", Enum.RenderPriority.Camera.Value - 2, PrepareNativeCamera)
	RunService:BindToRenderStep("MountedAimCamera", Enum.RenderPriority.Camera.Value + 1, ConstrainMountedCamera)
	RunService:BindToRenderStep("CameraLockUpdate", Enum.RenderPriority.Camera.Value + 2, UpdateCharacterRotation)
	RunService:BindToRenderStep("CinematicShoulderCamera", Enum.RenderPriority.Camera.Value + 3, UpdateShoulderCamera)
end

function CameraController:UnbindShiftLock()
	RunService:UnbindFromRenderStep("MountedAimCamera")
	RunService:UnbindFromRenderStep("CameraLockUpdate")
	RunService:UnbindFromRenderStep("CameraUpdateFirst")
	RunService:UnbindFromRenderStep("CinematicShoulderCamera")
end

function CameraController:LerpHeadSubject(Cframe: CFrame, Alpha: number)
	if HeadSubject then
		HeadSubjectCFrame = HeadSubject.CFrame:Lerp(Cframe, math.clamp(Alpha, 0, 1))
	end
end

function CameraController:SetCameraLerpAlpha(Alpha: number?)
	LerpAlpha = math.clamp(Alpha or 0.35, 0, 1)
end

function CameraController:SetDefaultCameraLerpAlpha()
	LerpAlpha = 0.35
end

function CameraController:SetCustomCameraSubjectCFrameOffset(Offset: CFrame?)
	CustomOffsetCFrame = Offset
end

function CameraController:GetDefaultCameraSubjectCFrameOffset(): CFrame
	return CFrame.new(0, 0.9, 0)
end

function CameraController:SetDefaultCameraSubjectCFrameOffset()
	HeadSubjectCFrame = nil
	CustomOffsetCFrame = nil
end

local function ResetCharacter()
	CameraController:UnbindShiftLock()
	table.clear(ForcedShiftLocks)
	ReleaseForcedMouse()
	CameraController:SetBowFocusZoom(false)
	CameraController:SetBowDrawSway(nil)
	ClearBowFieldOfView(true)
	SmoothedBowSway = CFrame.identity
	LastShakeTime = nil
	FovPulseRevision += 1
	if FovPulse then
		FovPulse:Cancel()
		FovPulse = nil
	end

	Character = nil
	Humanoid = nil
	RootPart = nil
	Torso = nil
	HeadSubject = nil
	HeadSubjectCFrame = nil
	CustomOffsetCFrame = nil
	ShoulderBlend = 0
	CameraRoll = 0
	CharacterRotation = nil
	ClearTransition()
	ClearAppliedFrame()
	RestoreZoomBounds()
	ShakeCamera = nil
	UnshakenCFrame = nil
	ShakenCFrame = nil
end

local function UpdateCharacter(NewCharacter: Model)
	local NewHumanoid = NewCharacter:WaitForChild("Humanoid", 15) :: Humanoid?
	local NewTorso = NewCharacter:WaitForChild("Torso", 15) :: BasePart?
	local NewRootPart = NewCharacter.PrimaryPart
	if Player.Character ~= NewCharacter or not NewCharacter.Parent or not NewHumanoid or not NewTorso or not NewRootPart then
		return
	end

	ResetCharacter()
	Character = NewCharacter
	Humanoid = NewHumanoid
	RootPart = NewRootPart
	Torso = NewTorso
	HeadSubject = NewCharacter:FindFirstChild("HeadSubject") :: BasePart?
	if not HeadSubject then
		HeadSubject = Instance.new("Part")
		HeadSubject.Name = "HeadSubject"
		HeadSubject.Size = Vector3.one
		HeadSubject.Transparency = 1
		HeadSubject.Anchored = true
		HeadSubject.Massless = true
		HeadSubject.Parent = NewCharacter
	end
	HeadSubject.CanCollide = false
	HeadSubject.CanTouch = false
	HeadSubject.CanQuery = false

	local Excluded: { Instance } = { NewCharacter }
	for _, Name in { "Entity", "VFX" } do
		local Folder = workspace:FindFirstChild(Name)
		if Folder then
			table.insert(Excluded, Folder)
		end
	end
	CollisionParams.FilterDescendantsInstances = Excluded
	SmoothedOffset = CameraController:GetDefaultCameraSubjectCFrameOffset().Position
	HeadSubject.CFrame = CFrame.new(NewRootPart.Position + SmoothedOffset)

	UpdateSubject()
	CameraController:BindShiftLock()
end

function CameraController.KnitInit()
	HotbarController = Knit.GetController("HotbarController")
end

function CameraController.KnitStart()
	-- Run after native camera and lock-on code so the open menu owns the cursor.
	RunService:BindToRenderStep("MenuMouseUnlock", Enum.RenderPriority.Last.Value, UpdateMenuMouse)
	Camera.FieldOfView = SharedConstants.DEFAULT_FIELD_OF_VIEW
	Player.CharacterAdded:Connect(UpdateCharacter)
	Player.CharacterRemoving:Connect(function(RemovingCharacter: Model)
		if Character == RemovingCharacter then
			ResetCharacter()
		end
	end)
	if Player.Character then
		task.spawn(UpdateCharacter, Player.Character)
	end

	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		ClearAppliedFrame()
		ClearTransition()
		ClearBowFieldOfView(true)
		Camera = workspace.CurrentCamera
		UpdateSubject()
		UpdateBowSensitivity()
		UpdateBowFieldOfView()
	end)
	Player:GetAttributeChangedSignal("AnimationsInfluence"):Connect(UpdateSubject)
	Player:GetAttributeChangedSignal("FovEffects"):Connect(UpdateBowFieldOfView)

	ContextActionService:BindAction("SwapCameraShoulder", function(_Action: string, State: Enum.UserInputState): Enum.ContextActionResult
		if State == Enum.UserInputState.Begin and IsGameplayCamera()
			and (IsShiftLocked() or (Character and Character:GetAttribute("LockedOnEnemy")))
			and not UserInputService:GetFocusedTextBox()
		then
			CameraController:SwapShoulder()
			return Enum.ContextActionResult.Sink
		end

		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.V)

	camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value + 5, function(ShakeCFrame: CFrame)
		local Now = os.clock()
		local DeltaTime = if LastShakeTime then math.clamp(Now - LastShakeTime, 0, 0.1) else 1 / 60
		LastShakeTime = Now

		if not Camera or not IsGameplayCamera() or not Player:GetAttribute("CameraShake") then
			ShakeCamera = nil
			SmoothedBowSway = CFrame.identity
			return
		end

		local BowSway = CFrame.identity
		if BowDrawStarted and Character and Character:GetAttribute("BowEquipped") then
			local Config = RangedWeaponConfig.GetForCharacter(Player.Character)
			BowSway = Config.GetDrawCameraSway(workspace:GetServerTimeNow() - BowDrawStarted, BowDrawSeed)
		end
		SmoothedBowSway = SmoothedBowSway:Lerp(BowSway, SmoothingAlpha(BowConfig.CameraSwayResponse, DeltaTime))
		ShakeCFrame *= SmoothedBowSway

		local Position = ShakeCFrame.Position
		if Position.Magnitude > 0.6 then
			Position = Position.Unit * 0.6
		end
		local Pitch, Yaw, Roll = ShakeCFrame:ToOrientation()
		local BeforeShake = Camera.CFrame
		Camera.CFrame *= CFrame.new(Position) * CFrame.Angles(
			math.clamp(Pitch, -math.rad(4), math.rad(4)),
			math.clamp(Yaw, -math.rad(4), math.rad(4)),
			math.clamp(Roll, -math.rad(1.5), math.rad(1.5))
		)
		ConstrainMountedCamera()
		ShakeCamera = Camera
		UnshakenCFrame = BeforeShake
		ShakenCFrame = Camera.CFrame

		if AppliedCamera == Camera and PresentedCFrame == BeforeShake then
			PresentedCFrame = Camera.CFrame
		end
	end)
	camShake:Start()
end

return CameraController
