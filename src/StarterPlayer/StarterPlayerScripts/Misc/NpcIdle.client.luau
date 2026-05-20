local function Play(NPC)
	local Idle = NPC:FindFirstChild("Idle")
	if Idle then
		local Animation: AnimationTrack = NPC.Humanoid:LoadAnimation(Idle)
		Animation.Looped = true
		Animation:Play()
	end
end

for _, NPC in workspace.NPCs:GetChildren() do
	Play(NPC)
end

workspace.NPCs.ChildAdded:Connect(function(NPC)
	Play(NPC)
end)
