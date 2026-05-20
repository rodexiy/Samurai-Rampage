local Knit = require(game.ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local Character = script.Parent
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local Controllers = {}

repeat
	task.wait()
until Character:GetAttribute("Loaded")

Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)

local Player = game.Players.LocalPlayer
Player.CameraMaxZoomDistance = 24

repeat
	task.wait()
until #game.StarterPlayer.StarterCharacterScripts.Client:GetDescendants() <= #Character.Client:GetDescendants()

for i, controller in script:GetDescendants() do
	if not controller:IsA("ModuleScript") then
		continue
	end
	Controllers[controller.Name] = require(controller)
end

for i, controller in Controllers do
	if controller.Init then
		controller.Init(Controllers)
	end

	task.spawn(function()
		if controller.Start then
			controller.Start(Controllers)
		end
	end)
end
