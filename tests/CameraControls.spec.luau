return function(ProductionSource: string): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Checks = 0
	local Fixture = Instance.new("Folder")
	Fixture.Parent = workspace
	local Character = Instance.new("Model")
	Character.Parent = Fixture
	local Root = Instance.new("Part")
	Root.Anchored = false
	Root.Parent = Character
	Character.PrimaryPart = Root
	local Attributes = {}
	local FirstPerson, Menu, RightMouse = false, false, false
	local Player = {
		GetAttribute = function(_Self: any, Name: string): any return Attributes[Name] end,
		FindFirstChildWhichIsA = function(): any return nil end,
	}
	local Input = { MouseBehavior = Enum.MouseBehavior.Default, MouseIconEnabled = true }
	function Input:IsMouseButtonPressed(_Button: Enum.UserInputType): boolean
		return RightMouse
	end
	local SavedBehavior = Enum.MouseBehavior.Default
	local RotationType: Enum.RotationType? = nil
	local LastBehavior: Enum.MouseBehavior? = nil
	local Utils = {
		setRotationTypeOverride = function(Value: Enum.RotationType)
			RotationType = Value
		end,
		setMouseBehaviorOverride = function(Value: Enum.MouseBehavior)
			if Input.MouseBehavior ~= LastBehavior then
				SavedBehavior = Input.MouseBehavior
			end
			Input.MouseBehavior, LastBehavior = Value, Value
		end,
		restoreMouseBehavior = function()
			if Input.MouseBehavior == LastBehavior then
				Input.MouseBehavior = SavedBehavior
			end
			LastBehavior = nil
		end,
	}
	local Humanoid = { AutoRotate = true, MoveDirection = Vector3.xAxis,
		GetState = function(): Enum.HumanoidStateType
			return Enum.HumanoidStateType.Running
		end }
	local Camera = { CameraType = Enum.CameraType.Custom, CFrame = CFrame.identity }
	local Dependencies = {
		Players = { LocalPlayer = Player }, Input = Input, Workspace = { CurrentCamera = Camera },
		Knit = { CreateController = function(Controller: any): any return Controller end },
		CameraUtils = Utils,
		FirstPerson = { IsFirstPerson = function(): boolean return FirstPerson end },
		Character = Character, Root = Root, Humanoid = Humanoid,
		Hotbar = { IsSelectingSlot = function(): boolean return Menu end },
	}
	local Source = string.gsub(ProductionSource, 'local Players = game:GetService%("Players"%)', "local Players = Dependencies.Players")
	Source = string.gsub(Source, 'local UserInputService = game:GetService%("UserInputService"%)', "local UserInputService = Dependencies.Input")
	Source = string.gsub(Source, "local Knit = require%(ReplicatedStorage%.Packages%.Knit%)", "local Knit = Dependencies.Knit")
	Source = string.gsub(Source, "local FirstPersonController = require%([^\n]+%)", "local FirstPersonController = Dependencies.FirstPerson")
	-- The native CameraUtils require spans two lines.
	local Start = string.find(Source, "local CameraUtils = require", 1, true)
	if Start then
		local Finish = assert(string.find(Source, ":: ModuleScript)", Start, true)) + #":: ModuleScript)" - 1
		Source = string.sub(Source, 1, Start - 1) .. "local CameraUtils = Dependencies.CameraUtils" .. string.sub(Source, Finish + 1)
	end
	Source = string.gsub(Source, "return CameraController%s*$", [[
Character, RootPart, Humanoid, HotbarController = Dependencies.Character, Dependencies.Root, Dependencies.Humanoid, Dependencies.Hotbar
return { Controller=CameraController, Rotate=UpdateCharacterRotation, Mouse=UpdateMenuMouse,
 ReleaseForced=ReleaseForcedMouse, ApplyForced=ApplyForcedShiftLock, ReleaseRotation=ReleaseFirstPersonRotation }
]])
	local Module = Instance.new("ModuleScript")
	Module.Name = "CameraControlsValidation"
	Module.Source = "return function(Dependencies)\nlocal workspace=Dependencies.Workspace\n" .. Source .. "\nend"
	Module.Parent = ReplicatedStorage
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local Success, Error = pcall(function()
		local Test = require(ReplicatedStorage.CameraControlsValidation)(Dependencies)
		Check(not Test.Controller:IsFacingCamera(), "Free camera does not select directional combat dashes")
		Character:SetAttribute("WeaponEquipped", true)
		for _, Attribute in { "ClientAttacking", "Blocking", "ClientBlocking" } do
			Character:SetAttribute(Attribute, true)
			Check(Test.Controller:IsFacingCamera(), "Attack and block count as facing locks even with a free mouse")
			Character:SetAttribute(Attribute, false)
		end
		Character:SetAttribute("LockedOnEnemy", true)
		Check(Test.Controller:IsFacingCamera(), "The T target lock selects directional dashes")
		Character:SetAttribute("LockedOnEnemy", false)
		Attributes.MouseLocked = true
		local BeforeShiftLock = Root.CFrame.LookVector
		Camera.CFrame = CFrame.Angles(0, math.rad(90), 0)
		Test.Rotate(1)
		Check(not Test.Controller:IsFacingCamera(), "Shift lock alone does not select directional combat dashes")
		Check(Humanoid.AutoRotate and Root.CFrame.LookVector:Dot(BeforeShiftLock) > 0.999
			and RotationType == Enum.RotationType.MovementRelative,
			"Shift lock preserves movement rotation instead of facing the camera")
		Input.MouseBehavior = Enum.MouseBehavior.LockCenter
		Test.Mouse()
		Check(Input.MouseBehavior == Enum.MouseBehavior.LockCenter, "Shift lock keeps the cursor centered without owning body rotation")
		Character:SetAttribute("ClientBlocking", true)
		Test.Rotate(1)
		Check(Test.Controller:IsFacingCamera() and not Humanoid.AutoRotate and Root.CFrame.LookVector:Dot(Camera.CFrame.LookVector) > 0.999,
			"Blocking with shift lock still turns the character toward the camera")
		Character:SetAttribute("ClientBlocking", false)
		Test.Rotate(1)
		Check(Humanoid.AutoRotate and not Test.Controller:IsFacingCamera(), "Releasing block returns shift lock to movement rotation")
		Attributes.MouseLocked = false
		FirstPerson = true
		Root.CFrame = CFrame.Angles(0, math.rad(40), 0)
		local Entry = Root.CFrame.Rotation
		Camera.CFrame = CFrame.Angles(0, math.rad(-90), 0)
		Test.Rotate(1)
		Check(not Humanoid.AutoRotate and Root.CFrame.LookVector:Dot(Entry.LookVector) > 0.999,
			"Entering first person captures the body heading and disables movement rotation")
		Root.CFrame = CFrame.new(5, 0, 0) * CFrame.Angles(0, math.rad(-45), 0)
		Test.Rotate(1)
		Check(Root.Position.X == 5 and Root.CFrame.LookVector:Dot(Entry.LookVector) > 0.999,
			"Walking and looking around in first person preserve the captured body rotation")
		Character:SetAttribute("ClientAttacking", true)
		Test.Rotate(1)
		Check(Root.CFrame.LookVector:Dot(Camera.CFrame.LookVector) > 0.999,
			"An attack can still turn the body toward the aim direction")
		Character:SetAttribute("ClientAttacking", false)
		local CombatHeading = Root.CFrame.LookVector
		Camera.CFrame = CFrame.identity
		Test.Rotate(1)
		Check(Root.CFrame.LookVector:Dot(CombatHeading) > 0.999, "Ending combat holds the last heading instead of snapping toward movement")
		FirstPerson = false
		Test.Rotate(1)
		Check(Humanoid.AutoRotate, "Leaving first person restores movement rotation")
		Character:SetAttribute("ClientBlocking", true)
		Test.Rotate(1)
		Check(not Humanoid.AutoRotate and Root.CFrame.LookVector:Dot(Camera.CFrame.LookVector) > 0.999,
			"Third-person aim owns body rotation instead of fighting movement auto-rotation")
		Character:SetAttribute("ClientBlocking", false)
		Test.Rotate(1)
		Check(Humanoid.AutoRotate, "Releasing third-person aim returns body rotation to movement")
		Input.MouseBehavior = Enum.MouseBehavior.LockCenter
		Test.Mouse()
		Check(Input.MouseBehavior == Enum.MouseBehavior.Default, "Free third person clears a stale centered mouse")
		RightMouse = true
		Input.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		Test.Mouse()
		Check(Input.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition, "Dragging the camera keeps the native right mouse behavior")
		RightMouse = false
		FirstPerson = true
		Input.MouseBehavior = Enum.MouseBehavior.LockCenter
		Test.Mouse()
		Check(Input.MouseBehavior == Enum.MouseBehavior.LockCenter, "First person retains its intentional cursor lock")
		FirstPerson = false
		Character:SetAttribute("LockedOnEnemy", true)
		Test.Mouse()
		Check(Input.MouseBehavior == Enum.MouseBehavior.LockCenter, "Target lock retains its intentional cursor lock")
		Character:SetAttribute("LockedOnEnemy", false)
		Input.MouseBehavior = Enum.MouseBehavior.Default
		Test.Controller:SetForcedShiftLock("Bow", true)
		Test.ApplyForced()
		Check(Input.MouseBehavior == Enum.MouseBehavior.LockCenter, "Ranged aim applies a temporary mouse lock")
		Test.ReleaseForced()
		Test.ApplyForced()
		Test.Controller:SetForcedShiftLock("Bow", false)
		Test.Mouse()
		Check(Input.MouseBehavior == Enum.MouseBehavior.Default, "Ending ranged aim releases the cursor after repeated native camera frames")
		Menu = true
		Input.MouseBehavior = Enum.MouseBehavior.LockCenter
		Test.Mouse()
		Check(Input.MouseBehavior == Enum.MouseBehavior.Default and Input.MouseIconEnabled, "Menus always release the cursor")
		Menu = false
		Test.Mouse()
		Check(Input.MouseBehavior == Enum.MouseBehavior.Default, "Closing a menu cannot restore an obsolete centered mouse")
	end)
	Fixture:Destroy()
	Module:Destroy()
	assert(Success, tostring(Error))

	return tostring(Checks) .. " camera control checks passed"
end
