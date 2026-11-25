local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local EnemyReactionController = Knit.CreateController({ Name = "EnemyReactionController" })

function EnemyReactionController.KnitStart()
	local AnimationController = Knit.GetController("AnimationController")
	local EnemyReactionService = Knit.GetService("EnemyReactionService")
	EnemyReactionService.Dodged:Connect(function(Character: Model, Direction: string)
		if not Character.Parent then
			return
		end

		local Animation = ReplicatedStorage.Assets.Animations.Combat.Roll:FindFirstChild(Direction) :: Animation?
		if not Animation then
			return
		end

		AnimationController:StopAttackAnimations(Character)
		local Track = AnimationController:PlayAnimation(Character, Animation)
		if Track then
			Track.Priority = Enum.AnimationPriority.Action
		end
	end)
end

return EnemyReactionController
