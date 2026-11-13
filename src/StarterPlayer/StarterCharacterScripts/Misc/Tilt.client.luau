local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local TiltController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.TiltController)

local Character = script.Parent.Parent.Parent :: Model
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
if not Character.PrimaryPart then
	Character:GetPropertyChangedSignal("PrimaryPart"):Wait()
end
local Root = Character.PrimaryPart
if not Root then
	return
end
Root:WaitForChild("RootJoint")

local State = TiltController.Create(Character)
if not State then
	return
end

local Binding = "LocalCharacterTilt_" .. HttpService:GenerateGUID(false)
RunService:BindToRenderStep(Binding, Enum.RenderPriority.Camera.Value + 7, function(DeltaTime: number)
	if Players.LocalPlayer.Character ~= Character or not Character:IsDescendantOf(workspace) then
		TiltController.Reset(State)
		return
	end

	TiltController.Update(State, Humanoid.MoveDirection, DeltaTime)
end)
local RemovingConnection: RBXScriptConnection?
local function Cleanup()
	RunService:UnbindFromRenderStep(Binding)
	TiltController.Reset(State)
	if RemovingConnection then
		RemovingConnection:Disconnect()
		RemovingConnection = nil
	end
end

RemovingConnection = Players.LocalPlayer.CharacterRemoving:Connect(function(Removing: Model)
	if Removing == Character then
		Cleanup()
	end
end)
Character.Destroying:Once(Cleanup)
