local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Player = game.Players.LocalPlayer
local Character = Player.Character
local Humanoid = Character:WaitForChild("Humanoid")

local PostureService
local AnimationController
local DeviceController
local SkillTreeController

local Validate = require(game.ReplicatedStorage.Shared.Validate)
local CharacterShared = require(game.ReplicatedStorage.Shared.CharacterShared)

local FovTween
local Camera = workspace.CurrentCamera

local FovInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
function TweenIn()
	if not Player:GetAttribute("FovEffects") then
		return
	end
	if FovTween then
		FovTween:Cancel()
		FovTween:Destroy()
	end

	if Character:GetAttribute("HeavyDeflect") then
		return
	end

	FovTween = TweenService:Create(Camera, FovInfo, { FieldOfView = 70 })
	FovTween:Play()
end

function TweenOut()
	if FovTween then
		FovTween:Cancel()
		FovTween:Destroy()
	end

	if Character:GetAttribute("HeavyDeflect") then
		return
	end

	FovTween = TweenService:Create(Camera, FovInfo, { FieldOfView = 75 })
	FovTween:Play()
end

local function StopBlock(onlyClient)
	TweenOut()

	Character:SetAttribute("ClientBlocking", false)
	AnimationController:StopAnimationFind(Character, "Block")

	if onlyClient then
		return
	end
	PostureService:Block(false)
end

local RequestBlock: UnreliableRemoteEvent = game.ReplicatedStorage.Assets.Public.RequestBlock

function PlayBlockAnimation()
	local CombatFolder = AnimationController:GetCombatAnimationFolder(Character)
	if CombatFolder then
		if AnimationController:GetAnimationFind(Character, "Block") then
			return
		end
		AnimationController:PlayAnimation(Character, CombatFolder.Block)
	end
end

local Block = {
	callback = function(inputState)
		if inputState ~= Enum.UserInputState.Begin and inputState ~= Enum.UserInputState.End then
			return
		end

		if inputState == Enum.UserInputState.End then
			StopBlock()
			return
		end

		if not Character:GetAttribute("WeaponEquipped") then
			return
		end

		if inputState == Enum.UserInputState.Begin then
			while
				not Validate:CanBlock(Character)
				or not (UserInputService:IsKeyDown(Enum.KeyCode.F) or DeviceController:IsDown("Block"))
			do
				if Character:GetAttribute("ClientBlocking") and Character:GetAttribute("Blocking") then
					break
				end
				if not (UserInputService:IsKeyDown(Enum.KeyCode.F) or DeviceController:IsDown("Block")) then
					break
				end
				RequestBlock:FireServer()

				task.wait()
			end

			if not UserInputService:IsKeyDown(Enum.KeyCode.F) and not DeviceController:IsDown("Block") then
				StopBlock(true)
				return
			end
		end

		if not Validate:CanBlock(Character) then
			return
		end

		PlayBlockAnimation()

		Character:SetAttribute("ClientBlocking", true)
		TweenIn()
		if not PostureService:Block(true) then
			print("Stop")
			StopBlock(true)
		end
	end,

	keys = { Enum.KeyCode.F },
}

Character:GetAttributeChangedSignal("WeaponEquipped"):Connect(function()
	if Character:GetAttribute("WeaponEquipped") then
		DeviceController:BindAction("Block", Block.callback, "Block", UDim2.fromScale(0.875, 0.425))
	else
		DeviceController:UnbindAction("Block")
	end
end)

function Block.Start()
	PostureService = Knit.GetService("PostureService")
	AnimationController = Knit.GetController("AnimationController")
	DeviceController = Knit.GetController("DeviceController")
	SkillTreeController = Knit.GetController("SkillTreeController")

	Character:GetAttributeChangedSignal("Blocking"):Connect(function()
		if not Character:GetAttribute("Blocking") then
			TweenOut()
		else
			TweenIn()
			PlayBlockAnimation()
		end

		CharacterShared:UpdateBoth(Character)
	end)

	-- Character:GetAttributeChangedSignal("ClientBlocking"):Connect(function()
	-- 	if not Character:GetAttribute("ClientBlocking") then
	-- 		StopBlock(true)
	-- 	end
	-- end)

	Character:GetAttributeChangedSignal("PostureBreak"):Connect(function()
		if Character:GetAttribute("PostureBreak") then
			StopBlock()
		end
	end)

	Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if Character:GetAttribute("Ragdoll") then
			StopBlock()
		end
	end)
	Character:GetAttributeChangedSignal("Rolling"):Connect(function()
		if
			Character:GetAttribute("Rolling")
			and (Character:GetAttribute("Race") ~= "Raijin")
		then
			StopBlock()
		end
	end)
end

return Block
