local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RagdollService = Knit.CreateService({
	Name = "RagdollService",
	Client = {},
})

local Ragdoll = require(game.ReplicatedStorage.Assets.Libraries.Ragdoll)

function RagdollService:Ragdoll(Character: Model, Impulse: number?, Direction: Vector3?, ImpulseDuration: number?)
	Ragdoll:Ragdoll(Character, Impulse, Direction, ImpulseDuration)
end

function RagdollService:Unragdoll(Character: Model)
	Ragdoll:Unragdoll(Character)
end

function RagdollService.KnitInit() end

function RagdollService.KnitStart() end

return RagdollService
