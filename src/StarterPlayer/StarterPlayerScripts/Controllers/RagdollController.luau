local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local SetAutoRotate = require(ReplicatedStorage.Shared.Utils.SetAutoRotate)
local Player = Players.LocalPlayer
local RagdollController = Knit.CreateController({ Name = "RagdollController" })
local RagdollService
local PendingRecovery: { Character: Model, Id: number }?
local ConfirmRecovery: (() -> ())?

local Connections: { RBXScriptConnection } = {}

local function StopTrack(Track: AnimationTrack)
	Track:Stop(0)
end

local function UnbindCharacter()
	PendingRecovery = nil
	ConfirmRecovery = nil
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	table.clear(Connections)
end

local function BindCharacter(Character: Model)
	UnbindCharacter()
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	if Player.Character ~= Character then
		return
	end

	local AnimationConnection: RBXScriptConnection?
	local AnimateScript: LocalScript?
	local AnimateWasEnabled = false
	local GettingUpWasEnabled = true
	local IsRagdolled = false

	ConfirmRecovery = function()
		local State = PendingRecovery
		if not State or State.Character ~= Character or not Character.PrimaryPart
			or Character:GetAttribute("RagdollRecoveryId") ~= State.Id then
			return
		end

		-- A delayed confirmation must leave the latest replicated physics intact.
		PendingRecovery = nil
		RagdollService.RecoveryReady:Fire(Character, State.Id)
	end

	local function UpdateRagdoll()
		if Character:GetAttribute("Ragdoll") or Character:GetAttribute("RagdollRecoveryId") then
			if IsRagdolled then
				return
			end
			IsRagdolled = true
			GettingUpWasEnabled = Humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp)
			local Animate = Character:FindFirstChild("Animate")
			if Animate and Animate:IsA("LocalScript") then
				AnimateScript = Animate
				AnimateWasEnabled = Animate.Enabled
				Animate.Enabled = false
			end

			local Animator = Humanoid:FindFirstChildWhichIsA("Animator")
			if Animator then
				AnimationConnection = Animator.AnimationPlayed:Connect(StopTrack)
				table.insert(Connections, AnimationConnection)
				for _, Track in Animator:GetPlayingAnimationTracks() do
					StopTrack(Track)
				end
			end

			Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			Humanoid.AutoRotate = false
			Humanoid.Jump = false
			Humanoid:Move(Vector3.zero)
			Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		elseif IsRagdolled then
			IsRagdolled = false
			if AnimationConnection then
				AnimationConnection:Disconnect()
				local Index = table.find(Connections, AnimationConnection)
				if Index then
					table.remove(Connections, Index)
				end
				AnimationConnection = nil
			end

			Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, GettingUpWasEnabled)
			if AnimateScript and AnimateScript.Parent then
				AnimateScript.Enabled = AnimateWasEnabled
			end
			AnimateScript = nil
			SetAutoRotate(Character, true)
			Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end

	table.insert(Connections, Character:GetAttributeChangedSignal("Ragdoll"):Connect(UpdateRagdoll))
	table.insert(Connections, Character:GetAttributeChangedSignal("RagdollRecoveryId"):Connect(function()
		UpdateRagdoll()
		if ConfirmRecovery then
			ConfirmRecovery()
		end
	end))
	table.insert(Connections, Humanoid:GetPropertyChangedSignal("AutoRotate"):Connect(function()
		if IsRagdolled and Humanoid.AutoRotate then
			Humanoid.AutoRotate = false
		end
	end))
	UpdateRagdoll()
end

function RagdollController.KnitStart()
	RagdollService = Knit.GetService("RagdollService")
	RagdollService.PrepareRecovery:Connect(function(Character: Model, Id: number)
		if Character ~= Player.Character then
			return
		end

		PendingRecovery = { Character = Character, Id = Id }
		if ConfirmRecovery then
			ConfirmRecovery()
		end
	end)
	Player.CharacterRemoving:Connect(UnbindCharacter)
	Player.CharacterAdded:Connect(BindCharacter)
	if Player.Character then
		BindCharacter(Player.Character)
	end
end

return RagdollController
