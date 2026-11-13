local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimPoseController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.AimPoseController)
local MountedAim = require(ReplicatedStorage.Shared.Utils.MountedAim)

local HorseAimController = {}

export type State = AimPoseController.State

HorseAimController.Create = AimPoseController.Create
HorseAimController.Reset = AimPoseController.Reset

function HorseAimController.Update(State: State, Character: Model, Camera: Camera?, DeltaTime: number): boolean
	if not MountedAim.IsActive(Character) then
		AimPoseController.Reset(State)
		return false
	end

	return AimPoseController.Update(State, Character, Camera, DeltaTime)
end

return HorseAimController
