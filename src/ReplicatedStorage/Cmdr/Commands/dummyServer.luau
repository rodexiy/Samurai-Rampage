local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

return function(Context: { Executor: Player }): string
	local Character = Context.Executor.Character
	if not Character or not Character.PrimaryPart then
		return "Your character must be spawned first."
	end

	local MobService = Knit.GetService("MobService")
	local AIService = Knit.GetService("AIService")
	local Location = Character:GetPivot() * CFrame.new(0, 0, -5) * CFrame.Angles(0, math.pi, 0)
	local Dummy = MobService:SpawnMob("Dummy", Location, "Dummy")
	if not Dummy then
		return "Could not create Dummy."
	end

	AIService:AddAI(Dummy, "Dummy", "Dummy")
	return "Spawned Dummy."
end
