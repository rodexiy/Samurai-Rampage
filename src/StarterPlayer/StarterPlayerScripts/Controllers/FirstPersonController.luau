local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local FirstPersonVisibilityController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.FirstPersonVisibilityController)
local FirstPersonController = Knit.CreateController({ Name = "FirstPersonController" })
local Player = Players.LocalPlayer
local Visibility: FirstPersonVisibilityController.State? = nil
local CAMERA_HEIGHT_OFFSET = 0.6
local CAMERA_FORWARD_OFFSET = 0.5

function FirstPersonController.GetCameraOffset(Frame: CFrame): Vector3
	return Vector3.yAxis * CAMERA_HEIGHT_OFFSET + Frame.LookVector * CAMERA_FORWARD_OFFSET
end

function FirstPersonController.GetCameraPosition(Frame: CFrame, Head: BasePart): Vector3
	return Head.Position + FirstPersonController.GetCameraOffset(Frame)
end

local function SetCharacter(Character: Model?)
	if Visibility then
		FirstPersonVisibilityController.Destroy(Visibility)
		Visibility = nil
	end
	if Character then
		Visibility = FirstPersonVisibilityController.Create(Character)
		FirstPersonVisibilityController.Refresh(Visibility)
	end
end

function FirstPersonController.IsFirstPerson(Camera: Camera, Character: Model): boolean
	if Camera.CameraType ~= Enum.CameraType.Custom or Character:GetAttribute("CameraCutscene")
		or Character:GetAttribute("RealmTeleporting") then
		return false
	end
	local Subject = Camera.CameraSubject
	if not Subject or not Subject:IsDescendantOf(Character) then
		return false
	end

	return (Camera.CFrame.Position - Camera.Focus.Position).Magnitude <= 1
end

function FirstPersonController.KnitStart()
	Player.CharacterAdded:Connect(SetCharacter)
	Player.CharacterRemoving:Connect(function(Character: Model)
		if Visibility and Visibility.Character == Character then
			SetCharacter(nil)
		end
	end)
	SetCharacter(Player.Character)

	-- Capture new equipment before the native camera writes its transparency modifiers.
	RunService:BindToRenderStep("FirstPersonTrack", Enum.RenderPriority.Camera.Value - 3, function()
		if Visibility then
			FirstPersonVisibilityController.Refresh(Visibility)
		end
	end)
	RunService:BindToRenderStep("FirstPersonVisibility", Enum.RenderPriority.Camera.Value + 6, function()
		local Camera = workspace.CurrentCamera
		if Visibility then
			local Active = Camera ~= nil and FirstPersonController.IsFirstPerson(Camera, Visibility.Character)
			FirstPersonVisibilityController.Update(Visibility, Active)
		end
	end)
end

return FirstPersonController
