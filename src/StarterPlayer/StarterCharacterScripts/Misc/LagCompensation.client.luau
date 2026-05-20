local LagCompensationUpdater =
	game.ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Public"):WaitForChild("LagCompensationUpdater")

local MousePositionUpdater =
	game.ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Public"):WaitForChild("MousePositionUpdater")

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

local LookAtMouse = Player.Character:WaitForChild("HumanoidRootPart"):WaitForChild("LookAtMouse")

local Updating = false
LookAtMouse:GetPropertyChangedSignal("Enabled"):Connect(function()
	if Updating then
		return
	end

	Updating = true
	while LookAtMouse.Enabled do
		MousePositionUpdater:FireServer(Mouse.Hit.Position)
		task.wait()
	end
	Updating = false
end)

while true do
	LagCompensationUpdater:FireServer(workspace:GetServerTimeNow())

	task.wait(1)
end
