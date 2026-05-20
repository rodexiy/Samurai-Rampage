local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
	if Character:GetAttribute("Ragdoll") then
		Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	else
		Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)
