local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ConsoleControlsController = Knit.CreateController({ Name = "ConsoleControlsController" })
local Player = Players.LocalPlayer
local PRIORITY = Enum.ContextActionPriority.High.Value + 10
local SHOULDER_HOLD_TIME = 0.4
local Keys = {
	[Enum.KeyCode.ButtonL2] = "Block",
	[Enum.KeyCode.ButtonR2] = "Attack",
	[Enum.KeyCode.ButtonY] = "StrongAttack",
	[Enum.KeyCode.ButtonB] = "Roll",
	[Enum.KeyCode.ButtonA] = "Jump",
	[Enum.KeyCode.ButtonX] = "KickClimb",
	[Enum.KeyCode.DPadUp] = "EquipWeapon",
	[Enum.KeyCode.DPadRight] = "ShiftLock",
	[Enum.KeyCode.DPadDown] = "LockOn",
	[Enum.KeyCode.DPadLeft] = "Ranged",
	[Enum.KeyCode.ButtonL3] = "Run",
}

type HeldAction = { Action: string, Input: InputObject }
local Held: { [Enum.KeyCode]: HeldAction } = {}
local Prompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" })
local BlockController
local BowController
local CameraController
local FeintController
local KickController
local MenuController
local ShiftLocked = false
local ShoulderSwapped = false
local ShiftRevision = 0
local RunInput: InputObject? = nil

local function GetInputController(): any
	local Character = Player.Character
	local Client = Character and Character:FindFirstChild("Client")
	if not Client or not Client:FindFirstChild("InputController") then
		return nil
	end

	local InputController = require(Players.LocalPlayer.Character.Client.InputController)
	return if InputController.Ready then InputController else nil
end

local function CallAction(Action: string, State: Enum.UserInputState, Input: InputObject?)
	local InputController = GetInputController()
	if InputController then
		if Action == "Run" and State == Enum.UserInputState.Begin then
			task.spawn(InputController.Caller, Action, State, Input)
		else
			InputController.Caller(Action, State, Input)
		end
	end
end

local function HasMenu(): boolean
	local PlayerGui = Player:FindFirstChildWhichIsA("PlayerGui")
	local Menus = PlayerGui and PlayerGui:FindFirstChild("Menu")
	local Inventory = MenuController:GetMenu("Inventory")
	if Inventory and Inventory.Enabled then
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

local function CanPlay(): boolean
	local Character = Player.Character
	return Character ~= nil and Character:GetAttribute("Loaded") == true
		and not Character:GetAttribute("Died") and not Character:GetAttribute("Downed")
		and not Character:GetAttribute("Ragdoll") and not Character:GetAttribute("RealmEditing")
		and not Character:GetAttribute("RealmTeleporting") and not Character:GetAttribute("CameraCutscene")
		and not workspace:GetAttribute("InMainMenu") and not GuiService.MenuIsOpen
		and not UserInputService:GetFocusedTextBox() and not Player:GetAttribute("InDialog")
		and not Player:GetAttribute("InIntroCutscene") and not Player:GetAttribute("EditingMobileControls")
		and not Player:GetAttribute("ActionWheelOpen") and not Player:GetAttribute("ConsoleHotbarOpen")
		and not HasMenu() and GetInputController() ~= nil
end

local function ReleaseAction(Action: HeldAction, State: Enum.UserInputState)
	if Action.Action == "Block" then
		BlockController:HandleInput(State)
	elseif Action.Action == "BowDraw" or Action.Action == "BowCancel" then
		BowController:HandleConsoleInput(Action.Action, State)
	elseif Action.Action == "EquipWeapon" then
		CallAction("EquipWeapon", State, Action.Input)
	end
end

local function ReleaseInputs()
	ShiftRevision += 1
	for Key, Action in Held do
		Held[Key] = nil
		ReleaseAction(Action, Enum.UserInputState.Cancel)
	end
	if RunInput then
		local Input = RunInput
		RunInput = nil
		CallAction("Run", Enum.UserInputState.End, Input)
	end
end

local function ShiftInput(State: Enum.UserInputState, Input: InputObject)
	if State == Enum.UserInputState.Begin then
		ShiftRevision += 1
		local Revision = ShiftRevision
		ShoulderSwapped = false
		task.delay(SHOULDER_HOLD_TIME, function()
			if Revision ~= ShiftRevision or not Held[Input.KeyCode] or not CanPlay() then
				return
			end

			ShoulderSwapped = true
			ShiftLocked = true
			CameraController:SetForcedShiftLock("Console", true)
			CameraController:SwapShoulder()
		end)
	elseif State == Enum.UserInputState.End then
		ShiftRevision += 1
		if not ShoulderSwapped and CanPlay() then
			ShiftLocked = not ShiftLocked
			CameraController:SetForcedShiftLock("Console", ShiftLocked)
		end
	end
end

local function BeginAction(Action: string, Input: InputObject, Character: Model): string
	if Action == "Block" then
		if Character:GetAttribute("BowEquipped") then
			BowController:HandleConsoleInput("BowCancel", Enum.UserInputState.Begin)
			return "BowCancel"
		end
		BlockController:HandleInput(Enum.UserInputState.Begin)
	elseif Action == "Attack" then
		if Character:GetAttribute("BowEquipped") then
			BowController:HandleConsoleInput("BowDraw", Enum.UserInputState.Begin)
			return "BowDraw"
		end
		CallAction("Attack", Enum.UserInputState.Begin, Input)
	elseif Action == "StrongAttack" then
		if Character:GetAttribute("TalentFeint") and (Character:GetAttribute("Attack")
			or Character:GetAttribute("Attacking") or Character:GetAttribute("ClientAttacking")) then
			FeintController:HandleInput(Enum.UserInputState.Begin)
		else
			CallAction(Action, Enum.UserInputState.Begin, Input)
		end
	elseif Action == "KickClimb" then
		local WasClimbing = Character:GetAttribute("Climbing")
		CallAction("Climb", Enum.UserInputState.Begin, Input)
		if not WasClimbing and not Character:GetAttribute("Climbing") then
			KickController:HandleInput(Enum.UserInputState.Begin)
		end
	elseif Action == "Ranged" then
		BowController:HandleConsoleInput("BowToggle", Enum.UserInputState.Begin)
	elseif Action == "Run" then
		local Running = Character:GetAttribute("Running") == true
		RunInput = if Running then nil else Input
		CallAction("Run", if Running then Enum.UserInputState.End else Enum.UserInputState.Begin, Input)
	elseif Action == "ShiftLock" then
		ShiftInput(Enum.UserInputState.Begin, Input)
	elseif Action == "Jump" then
		CallAction("Vault", Enum.UserInputState.Begin, Input)
		CallAction("WallRun", Enum.UserInputState.Begin, Input)
	else
		CallAction(Action, Enum.UserInputState.Begin, Input)
	end
	return Action
end

local function GameplayInput(_Name: string, State: Enum.UserInputState, Input: InputObject): Enum.ContextActionResult
	local Key = Input.KeyCode
	local Action = Keys[Key]
	local Previous = Held[Key]
	if State == Enum.UserInputState.End or State == Enum.UserInputState.Cancel then
		if not Previous or Previous.Input.UserInputType ~= Input.UserInputType then
			return Enum.ContextActionResult.Pass
		end
		Held[Key] = nil
		ReleaseAction(Previous, State)
		if Action == "ShiftLock" then
			ShiftInput(State, Input)
		end
		return if Action == "Jump" then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
	end
	if State ~= Enum.UserInputState.Begin or not Action then
		return if Previous and Action ~= "Jump" then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end
	if Previous then
		return if Action == "Jump" then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
	end
	if not CanPlay() then
		return if Player:GetAttribute("ActionWheelOpen") or Player:GetAttribute("ConsoleHotbarOpen")
			then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end

	local Character = Player.Character :: Model
	if (Action == "Jump" or Action == "Roll" or Action == "Run")
		and (Character:GetAttribute("Mounted") or Character:GetAttribute("InHorse")) then
		return Enum.ContextActionResult.Pass
	end
	if Action == "KickClimb" then
		for Prompt in Prompts do
			if Prompt.Parent and Prompt.Enabled and Prompt.GamepadKeyCode == Key then
				return Enum.ContextActionResult.Pass
			end
		end
	end
	if Action == "Attack" and not Character:GetAttribute("BowEquipped")
		and Character:FindFirstChildWhichIsA("Tool") then
		return Enum.ContextActionResult.Pass
	end

	local Active: HeldAction = { Action = Action, Input = Input }
	Held[Key] = Active
	Active.Action = BeginAction(Action, Input, Character)
	return if Action == "Jump" then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
end

function ConsoleControlsController.KnitInit()
	BlockController = Knit.GetController("BlockController")
	BowController = Knit.GetController("BowController")
	CameraController = Knit.GetController("CameraController")
	FeintController = Knit.GetController("FeintController")
	KickController = Knit.GetController("KickController")
	MenuController = Knit.GetController("MenuController")
end

function ConsoleControlsController.KnitStart()
	local BoundKeys: { Enum.KeyCode } = {}
	for Key in Keys do
		table.insert(BoundKeys, Key)
	end
	ContextActionService:BindActionAtPriority("ConsoleGameplay", GameplayInput, false, PRIORITY, table.unpack(BoundKeys))
	UserInputService.WindowFocusReleased:Connect(ReleaseInputs)
	UserInputService.TextBoxFocused:Connect(ReleaseInputs)
	UserInputService.GamepadDisconnected:Connect(ReleaseInputs)
	GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(function()
		if GuiService.MenuIsOpen then
			ReleaseInputs()
		end
	end)
	for _, Attribute in { "ActionWheelOpen", "ConsoleHotbarOpen", "InDialog", "InIntroCutscene", "EditingMobileControls" } do
		Player:GetAttributeChangedSignal(Attribute):Connect(function()
			if Player:GetAttribute(Attribute) then
				ReleaseInputs()
			end
		end)
	end
	ProximityPromptService.PromptShown:Connect(function(Prompt: ProximityPrompt)
		Prompts[Prompt] = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(Prompt: ProximityPrompt)
		Prompts[Prompt] = nil
	end)
	Player.CharacterRemoving:Connect(function()
		ReleaseInputs()
		ShiftLocked = false
		CameraController:SetForcedShiftLock("Console", false)
	end)

	local function BindCharacter(Character: Model)
		for _, Attribute in { "Died", "Downed", "Ragdoll", "RealmEditing", "RealmTeleporting", "CameraCutscene", "Meditating" } do
			Character:GetAttributeChangedSignal(Attribute):Connect(function()
				if Player.Character == Character and Character:GetAttribute(Attribute) then
					ReleaseInputs()
				end
			end)
		end
	end
	Player.CharacterAdded:Connect(BindCharacter)
	if Player.Character then
		BindCharacter(Player.Character)
	end
end

return ConsoleControlsController
