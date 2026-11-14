local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CrouchConfig = require(ReplicatedStorage.Shared.CrouchConfig)
local CrouchAnimationController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.CrouchAnimationController)

local CrouchController = Knit.CreateController({Name = "CrouchController"})
local Player = Players.LocalPlayer
local CrouchService

type Record = {
	Animation: CrouchAnimationController.State?,
	Connections: { RBXScriptConnection },
	AnimationConnections: { RBXScriptConnection },
	Building: boolean,
}
local Records: { [Model]: Record } = {}
local Prompts: { [ProximityPrompt]: boolean } = {}

local function ClearAnimations(Record: Record)
	for _, Connection in Record.AnimationConnections do
		Connection:Disconnect()
	end
	table.clear(Record.AnimationConnections)

	if Record.Animation then
		CrouchAnimationController.Destroy(Record.Animation)
		Record.Animation = nil
	end
end

local function RemoveCharacter(Character: Model)
	local Record = Records[Character]
	if not Record then
		return
	end

	ClearAnimations(Record)
	for _, Connection in Record.Connections do
		Connection:Disconnect()
	end
	Records[Character] = nil
end

local function TrackCharacter(Character: Model)
	RemoveCharacter(Character)
	local Record: Record = {Connections = {}, AnimationConnections = {}, Building = false}
	Records[Character] = Record
	local function BuildAnimations()
		if Record.Animation or Record.Building then
			return
		end

		Record.Building = true
		local State = CrouchAnimationController.Create(Character)
		Record.Building = false
		if not State then
			return
		end
		Record.Animation = State
		local function Refresh()
			CrouchAnimationController.Update(State)
		end

		table.insert(Record.AnimationConnections, State.Humanoid.Running:Connect(function(Speed: number)
			CrouchAnimationController.Update(State, Speed)
		end))
		table.insert(Record.AnimationConnections, Character:GetAttributeChangedSignal("Crouching"):Connect(Refresh))
		for _, Attribute in CrouchConfig.CancelAttributes do
			table.insert(Record.AnimationConnections, Character:GetAttributeChangedSignal(Attribute):Connect(Refresh))
		end
		table.insert(Record.AnimationConnections, State.Humanoid.StateChanged:Connect(Refresh))
		table.insert(Record.AnimationConnections, State.Humanoid:GetPropertyChangedSignal("Sit"):Connect(Refresh))
		table.insert(Record.AnimationConnections, State.Humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(Refresh))
		Refresh()
	end

	table.insert(Record.Connections, Character.DescendantAdded:Connect(BuildAnimations))
	table.insert(Record.Connections, Character.DescendantRemoving:Connect(function(Object: Instance)
		local State = Record.Animation
		if State and (Object == State.Animator or Object == State.Humanoid or Object == State.Root) then
			ClearAnimations(Record)
		end
	end))
	table.insert(Record.Connections, Character:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
		ClearAnimations(Record)
		BuildAnimations()
	end))
	table.insert(Record.Connections, Character.Destroying:Connect(function()
		RemoveCharacter(Character)
	end))
	BuildAnimations()
end

local function InputBlocked(): boolean
	if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() or workspace:GetAttribute("InMainMenu") then
		return true
	end
	for Prompt in Prompts do
		if Prompt.Parent and Prompt.Enabled and Prompt.KeyboardKeyCode == CrouchConfig.Key then
			return true
		end
	end

	local Gui = Player:FindFirstChildWhichIsA("PlayerGui")
	local Main = Gui and Gui:FindFirstChild("MainMenu") :: ScreenGui?
	if Main and Main.Enabled then
		return true
	end
	local Menus = Gui and Gui:FindFirstChild("Menu")
	if Menus then
		for _, Menu in Menus:GetChildren() do
			if Menu:IsA("ScreenGui") and Menu.Enabled then
				return true
			end
		end
	end

	return false
end

function CrouchController.KnitStart()
	CrouchService = Knit.GetService("CrouchService")
	UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		local Character = Player.Character
		if Processed or Input.KeyCode ~= CrouchConfig.Key or not Character or InputBlocked() then
			return
		end

		CrouchService.Request:Fire(Character:GetAttribute("Crouching") ~= true)
	end)
	ProximityPromptService.PromptShown:Connect(function(Prompt: ProximityPrompt)
		Prompts[Prompt] = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(Prompt: ProximityPrompt)
		Prompts[Prompt] = nil
	end)

	-- The owning player's Animator replicates these tracks to the other clients.
	Player.CharacterAdded:Connect(TrackCharacter)
	Player.CharacterRemoving:Connect(RemoveCharacter)
	if Player.Character then
		TrackCharacter(Player.Character)
	end
end

return CrouchController
