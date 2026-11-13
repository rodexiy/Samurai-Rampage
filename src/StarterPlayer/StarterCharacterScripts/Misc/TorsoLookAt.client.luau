local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local CharacterLookController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.CharacterLookController)

local Character = script.Parent.Parent.Parent :: Model
local Torso = Character:WaitForChild("Torso") :: BasePart
Character:WaitForChild("Head")
if not Character.PrimaryPart then
	Character:GetPropertyChangedSignal("PrimaryPart"):Wait()
end
local Root = Character.PrimaryPart
if not Root then
	return
end
Root:WaitForChild("RootJoint")
for _, Name in { "Neck", "Right Hip", "Left Hip", "Right Shoulder", "Left Shoulder" } do
	Torso:WaitForChild(Name)
end

local State = CharacterLookController.Create(Character)
if not State then
	return
end

local Binding = "LocalCharacterLook_" .. HttpService:GenerateGUID(false)
RunService:BindToRenderStep(Binding, Enum.RenderPriority.Camera.Value + 8, function(DeltaTime: number)
	if Players.LocalPlayer.Character ~= Character or not Character:IsDescendantOf(workspace) then
		CharacterLookController.Reset(State)
		return
	end

	local Camera = workspace.CurrentCamera
	CharacterLookController.Update(State, Players.LocalPlayer, if Camera then Camera.CFrame else nil,
		Camera ~= nil and Camera.CameraType == Enum.CameraType.Custom, DeltaTime)
end)
local RemovingConnection: RBXScriptConnection?
local function Cleanup()
	RunService:UnbindFromRenderStep(Binding)
	CharacterLookController.Reset(State)
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
