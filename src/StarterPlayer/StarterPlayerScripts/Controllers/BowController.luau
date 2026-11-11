local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BowConfig = require(ReplicatedStorage.Shared.BowConfig)
local BowRaycast = require(ReplicatedStorage.Shared.Utils.BowRaycast)
local BowController = Knit.CreateController({ Name = "BowController" })

local Player = Players.LocalPlayer
local BowService
local InventoryService
local CameraController
local CursorController
local FocusController
local BowSoundController
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
local LastAimUpdate = 0
local NextShot = 0
local PlayTransitionAnimation: (boolean) -> ()
local AimParams = RaycastParams.new()
AimParams.FilterType = Enum.RaycastFilterType.Exclude
AimParams.IgnoreWater = true

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
	if CameraController then
		CameraController:SetBowDrawSway(nil)
	end
	for Name, Track in Tracks do
		if Name ~= "Pose" and Name ~= "Unequip" then
			Track:Stop(0.12)
		end
	end
end

local function CanFocusZoom(): boolean
	if not Character or not WindowFocused
		or not (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
		return false
	end

	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	local Root = Character.PrimaryPart
	local MaxSpeed = if FocusActive then BowConfig.FocusExitMoveSpeed else BowConfig.FocusMaxMoveSpeed
	return Humanoid ~= nil and Root ~= nil and not Humanoid.Sit
		and Humanoid.FloorMaterial ~= Enum.Material.Air
		and Humanoid.MoveDirection.Magnitude < BowConfig.FocusMoveInputDeadzone
		and Root:GetVelocityAtPosition(Root.Position).Magnitude <= MaxSpeed
		and not Character:GetAttribute("Running") and BowConfig.CanUse(Character)
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
		Pose:Stop(0.15)
	end
end

function BowController:CancelDraw()
	if Holding or Started then
		BowService.Request:Fire("Cancel")
	end
	StopDraw()
end

local function GetAimPoint(): Vector3
	local Camera = workspace.CurrentCamera
	local Origin = Camera.CFrame.Position
	local Direction = Camera.CFrame.LookVector * BowConfig.MaxDistance
	local Hit = BowRaycast.Aim(Origin, Direction, AimParams)
	return if Hit then Hit.Position else Origin + Direction
end

local function UpdateAmmo(Items: { any })
	ArrowCount = 0
	for _, Item in Items do
		if Item.Name == BowConfig.ArrowItem then
			ArrowCount += Item.Stack or 0
		end
	end
end

local function UpdateNock(Target: Model)
	local Existing = NockedArrows[Target]
	if not Target.Parent or not Target:GetAttribute("BowDrawing") or not Target:GetAttribute("BowEquipped") then
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
	for _, Track in Tracks do
		Track:Destroy()
	end
	table.clear(Tracks)
	Character = NewCharacter
	UpdateFocusZoom(false)
	CameraController:SetBowFocusZoom(false)
	FocusController:SetActive(false)
	CameraController:SetForcedShiftLock("Bow", false)
	local Excluded: { Instance } = { NewCharacter }
	local Effects = workspace:FindFirstChild("VFX")
	if Effects then
		table.insert(Excluded, Effects)
	end
	AimParams.FilterDescendantsInstances = Excluded
	NextShot = 0

	for _, Attribute in BowConfig.CancelAttributes do
		table.insert(CharacterConnections, NewCharacter:GetAttributeChangedSignal(Attribute):Connect(function()
			if NewCharacter:GetAttribute(Attribute) then
				BowController:CancelDraw()
				StopTransitionAnimations()
			end
		end))
	end
	table.insert(CharacterConnections, NewCharacter:GetAttributeChangedSignal("BowEquipped"):Connect(function()
		if NewCharacter:GetAttribute("BowEquipped") then
			PlayTransitionAnimation(true)
		else
			BowController:CancelDraw()
			PlayTransitionAnimation(false)
		end
	end))
end

local function LoadTracks()
	if not Character or Tracks.Aim then
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
		Track.Priority = if Name == "Pose" then Enum.AnimationPriority.Action
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
	if not Character or not BowConfig.CanUse(Character) then
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
	if not Character or Holding or ArrowCount <= 0 or workspace:GetServerTimeNow() < NextShot
		or not BowConfig.CanUse(Character) or not Character:GetAttribute("BowEquipped") or IsBlocked() then
		return
	end

	Holding = true
	Started = workspace:GetServerTimeNow()
	Seed = 0
	CameraController:SetBowDrawSway(Started, Seed)
	LoadTracks()
	StopTransitionAnimations()
	if Tracks.Aim then
		local Duration = if Tracks.Aim.Length > 0 then Tracks.Aim.Length else BowConfig.FullChargeTime
		Tracks.Aim:Play(0.12, 1, Duration / BowConfig.FullChargeTime)
	end
	BowService.Request:Fire("Begin", GetAimPoint())
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
				NextShot = Now + BowConfig.ShotCooldown
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
		if Elapsed >= BowConfig.FullChargeTime then
			HoldDrawPose()
		elseif Tracks.Aim and Tracks.Aim.Length > 0 then
			local Speed = Tracks.Aim.Length / BowConfig.FullChargeTime
			if math.abs(Tracks.Aim.Speed - Speed) > 0.001 then
				Tracks.Aim:AdjustSpeed(Speed)
				Tracks.Aim.TimePosition = Elapsed * Speed
			end
		end
	end
	CursorController:Update(CursorPosition, Elapsed, ArrowCount)
end

function BowController.KnitStart()
	BowService = Knit.GetService("BowService")
	InventoryService = Knit.GetService("InventoryService")
	CameraController = Knit.GetController("CameraController")
	CursorController = Knit.GetController("BowCursorController")
	FocusController = Knit.GetController("BowFocusController")
	BowSoundController = Knit.GetController("BowSoundController")
	AimEvent = ReplicatedStorage.Assets.Events:WaitForChild("BowAim") :: UnreliableRemoteEvent
	InventoryService.InventoryUpdated:Connect(UpdateAmmo)
	task.spawn(function()
		UpdateAmmo(InventoryService:GetInventory())
	end)
	BowService.Feedback:Connect(function(Action: string, Value: number?, NewSeed: number?)
		if Action == "Draw" then
			if Holding then
				Started = Value
				Seed = NewSeed or 0
				CameraController:SetBowDrawSway(Started, Seed)
			end
		elseif Action == "Shot" then
			StopDraw()
			NextShot = workspace:GetServerTimeNow() + BowConfig.ShotCooldown
			local Charge = Value or 0
			local Track = if Charge >= 1 then Tracks.ShotLooped
				elseif Charge < 0.2 then Tracks.Shoot else Tracks.Shot
			if Track and Character and Character:GetAttribute("BowEquipped") and BowConfig.CanUse(Character) then
				Track:Play(0.05)
			end
		elseif Action == "Cancel" then
			StopDraw()
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
			StopTransitionAnimations()
			StopPose()
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
