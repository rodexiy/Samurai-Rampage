return function(ProductionSource: string, Sway: any, FirstPerson: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Fixture = Instance.new("Folder")
	Fixture.Parent = workspace
	local Character = Instance.new("Model")
	Character.Parent = Fixture
	local Root = Instance.new("Part")
	Root.Anchored = true
	Root.Parent = Character
	Character.PrimaryPart = Root
	local Head = Root:Clone()
	Head.Name = "Head"
	Head.Parent = Character
	local Subject = Root:Clone()
	Subject.Parent = Character
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Parent = Character
	local Camera = Instance.new("Camera")
	Camera.CameraType = Enum.CameraType.Custom
	Camera.CameraSubject = Humanoid
	Camera.Parent = Fixture
	local Attributes = {}
	local Player = {
		CameraMinZoomDistance = 0.5,
		CameraMaxZoomDistance = 12,
		GetAttribute = function(_Self: any, Name: string): any return Attributes[Name] end,
		FindFirstChildWhichIsA = function(): any return nil end,
	}
	local Input = {
		MouseBehavior = Enum.MouseBehavior.Default,
		IsMouseButtonPressed = function(): boolean
			return false
		end,
	}
	local Dependencies = {
		Players = { LocalPlayer = Player }, Input = Input, FirstPerson = FirstPerson,
		Workspace = { CurrentCamera = Camera, Spherecast = function(): RaycastResult? return nil end },
		Knit = { CreateController = function(Controller: any): any return Controller end },
		CameraUtils = { restoreMouseBehavior = function() end, setMouseBehaviorOverride = function() end },
		Character = Character, Root = Root, Humanoid = Humanoid, Subject = Subject,
		Sway = { ApplyCameraSway = function(_Self: any, Frame: CFrame): CFrame
			return Sway.GetSwayFrame(Frame, CFrame.identity, 1.5, 1)
		end },
	}
	local Source = ProductionSource:gsub('local Players = game:GetService%("Players"%)', "local Players = Dependencies.Players")
	Source = Source:gsub('local UserInputService = game:GetService%("UserInputService"%)', "local UserInputService = Dependencies.Input")
	Source = Source:gsub("local Knit = require%(ReplicatedStorage%.Packages%.Knit%)", "local Knit = Dependencies.Knit")
	Source = Source:gsub("local FirstPersonController = require%([^\n]+%)", "local FirstPersonController = Dependencies.FirstPerson")
	local Start = assert(Source:find("local CameraUtils = require", 1, true))
	local Finish = assert(Source:find(":: ModuleScript)", Start, true)) + #":: ModuleScript)" - 1
	Source = Source:sub(1, Start - 1) .. "local CameraUtils = Dependencies.CameraUtils" .. Source:sub(Finish + 1)
	Source = Source:gsub("return CameraController%s*$", [[
Character, RootPart, Torso = Dependencies.Character, Dependencies.Root, Dependencies.Root
Humanoid, HeadSubject = Dependencies.Humanoid, Dependencies.Subject
IntroCutsceneController = Dependencies.Sway
return { Prepare = PrepareNativeCamera, Present = UpdateShoulderCamera }
]])
	local Module = Instance.new("ModuleScript")
	Module.Name = "BoatCameraIntegrationSubject"
	Module.Source = "return function(Dependencies)\nlocal workspace = Dependencies.Workspace\n" .. Source .. "\nend"
	Module.Parent = ReplicatedStorage
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Near(First: CFrame, Second: CFrame): boolean
		return (First.Position - Second.Position).Magnitude < 0.0001
			and (First.LookVector - Second.LookVector).Magnitude < 0.0001
			and (First.UpVector - Second.UpVector).Magnitude < 0.0001
	end

	local Success, Error = pcall(function()
		local Pipeline = require(ReplicatedStorage.BoatCameraIntegrationSubject)(Dependencies)
		for _, Mode in { "ThirdPerson", "ShiftLock", "FirstPerson" } do
			Attributes.MouseLocked = Mode == "ShiftLock"
			Input.MouseBehavior = if Mode == "ThirdPerson" then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
			local OriginalMouse = Input.MouseBehavior
			local Distance = if Mode == "FirstPerson" then 0.5 else 10
			local Native = CFrame.new(0, 0, Distance)
			local Focus = CFrame.identity
			Camera.CFrame, Camera.Focus = Native, Focus
			local OriginalRoot = Root.CFrame
			for _ = 1, 120 do
				Pipeline.Present(1 / 60)
				Check(Camera.CameraType == Enum.CameraType.Custom and Camera.CameraSubject == Humanoid,
					Mode .. " retains the native camera and subject")
				if Mode == "FirstPerson" then
					Check(FirstPerson.IsFirstPerson(Camera, Character), "Sway preserves first-person detection")
				end
				Pipeline.Prepare(1 / 60)
				Check(Near(Camera.CFrame, Native) and Near(Camera.Focus, Focus),
					Mode .. " removes sway before native mouse input without accumulating tilt")
			end
			Check(Input.MouseBehavior == OriginalMouse, Mode .. " preserves mouse locking")
			Check(Root.CFrame == OriginalRoot and Humanoid.AutoRotate, Mode .. " preserves character rotation")
		end
	end)
	Module:Destroy()
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("BoatCameraIntegration: %d checks passed", Checks)
end
