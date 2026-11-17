local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CharacterShared = require(ReplicatedStorage.Shared.CharacterShared)
local SharedConstants = require(ReplicatedStorage.Shared.Constants)
local Validate = require(ReplicatedStorage.Shared.Validate)

local BlockController = Knit.CreateController({ Name = "BlockController" })
local Player = Players.LocalPlayer
local PostureService
local AnimationController
local DeviceController
local SkillTreeController

type BlockState = {
	Character: Model,
	Held: boolean,
	Accepted: boolean?,
	Sequence: number,
	Visual: boolean,
	Connections: { RBXScriptConnection },
}

local Current: BlockState?
local NextSequence = 0
local FovTween: Tween?
local FovInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local function UpdateFov(Character: Model, Blocking: boolean)
	if FovTween then
		FovTween:Cancel()
		FovTween:Destroy()
		FovTween = nil
	end

	local Camera = workspace.CurrentCamera
	if not Camera or Character:GetAttribute("HeavyDeflect") then
		return
	end

	local Offset = if Blocking and Player:GetAttribute("FovEffects") then 5 else 0
	FovTween = TweenService:Create(Camera, FovInfo, { FieldOfView = SharedConstants.DEFAULT_FIELD_OF_VIEW - Offset })
	FovTween:Play()
end

local function UpdateVisual(State: BlockState)
	local Character = State.Character
	local Enabled = State.Held and State.Accepted ~= false and Validate:CanBlock(Character)
	if State.Visual == Enabled then
		return
	end

	State.Visual = Enabled
	Character:SetAttribute("ClientBlocking", Enabled)
	if Enabled then
		local CombatFolder = AnimationController:GetCombatAnimationFolder(Character)
		if CombatFolder and not AnimationController:GetAnimationFind(Character, "Block") then
			AnimationController:PlayAnimation(Character, CombatFolder.Block)
		end
	else
		AnimationController:StopAnimationFind(Character, "Block")
	end

	UpdateFov(Character, Enabled)
	CharacterShared:UpdateBoth(Character)
end

local function SendInput(State: BlockState, Held: boolean)
	NextSequence += 1
	State.Sequence = NextSequence
	State.Held = Held
	State.Accepted = if Held then nil else false
	UpdateVisual(State)
	PostureService.BlockRequest:Fire(State.Character, Held, State.Sequence)
end

function BlockController:HandleInput(InputState: Enum.UserInputState)
	local State = Current
	if not State then
		return
	end

	if InputState == Enum.UserInputState.End or InputState == Enum.UserInputState.Cancel then
		if State.Held then
			SendInput(State, false)
		end
	elseif InputState == Enum.UserInputState.Begin and not State.Held
		and State.Character:GetAttribute("WeaponEquipped") and not State.Character:GetAttribute("Died") then
		SendInput(State, true)
	end
end

local function Release()
	BlockController:HandleInput(Enum.UserInputState.End)
end

local function RemoveCharacter(Character: Model)
	local State = Current
	if not State or State.Character ~= Character then
		return
	end

	Release()
	Current = nil
	for _, Connection in State.Connections do
		Connection:Disconnect()
	end
	DeviceController:UnbindAction("Block")
end

local function TrackCharacter(Character: Model)
	if Current then
		RemoveCharacter(Current.Character)
	end

	local State: BlockState = {
		Character = Character,
		Held = false,
		Accepted = false,
		Sequence = 0,
		Visual = false,
		Connections = {},
	}
	Current = State
	Character:SetAttribute("ClientBlocking", false)

	local function UpdateWeapon()
		if Character:GetAttribute("WeaponEquipped") then
			DeviceController:BindAction("Block", function(InputState: Enum.UserInputState)
				if Current == State then
					BlockController:HandleInput(InputState)
				end
			end, "Block", UDim2.fromScale(0.875, 0.425))
		else
			Release()
			DeviceController:UnbindAction("Block")
		end
	end

	table.insert(State.Connections, Character.AttributeChanged:Connect(function(Attribute: string)
		if Current ~= State or Attribute == "ClientBlocking" then
			return
		end

		if Attribute == "WeaponEquipped" then
			UpdateWeapon()
		end
		if ((Attribute == "Died" or Attribute == "PostureBreak" or Attribute == "Ragdoll") and Character:GetAttribute(Attribute))
			or (Attribute == "Rolling" and Character:GetAttribute("Rolling") and (Character:GetAttribute("Race") ~= "Raijin"
				or SkillTreeController:IsSkillUnlocked("Lightning Dash"))) then
			Release()
		end

		UpdateVisual(State)
		-- Movement can change after the local animation has already stopped.
		if Attribute == "Blocking" or Attribute == "BeenDeflected"
			or Attribute == "HeavyDeflect" or Attribute == "PostureBreak" then
			CharacterShared:UpdateBoth(Character)
		end

		if Attribute == "HeavyDeflect" and not Character:GetAttribute("HeavyDeflect") then
			UpdateFov(Character, State.Visual)
		end
	end))
	UpdateWeapon()
end

function BlockController.KnitStart()
	PostureService = Knit.GetService("PostureService")
	AnimationController = Knit.GetController("AnimationController")
	DeviceController = Knit.GetController("DeviceController")
	SkillTreeController = Knit.GetController("SkillTreeController")

	PostureService.BlockResult:Connect(function(Character: Model, Sequence: number, Blocking: boolean)
		local State = Current
		if not State or State.Character ~= Character or State.Sequence ~= Sequence or not State.Held then
			return
		end

		State.Accepted = Blocking
		UpdateVisual(State)
	end)
	UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if Input.KeyCode == Enum.KeyCode.F and not Processed then
			BlockController:HandleInput(Enum.UserInputState.Begin)
		end
	end)
	UserInputService.InputEnded:Connect(function(Input: InputObject)
		if Input.KeyCode == Enum.KeyCode.F then
			Release()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(Release)
	UserInputService.TextBoxFocused:Connect(Release)
	Player.CharacterRemoving:Connect(RemoveCharacter)
	Player.CharacterAdded:Connect(TrackCharacter)
	if Player.Character then
		TrackCharacter(Player.Character)
	end
end

return BlockController
