local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Debris = game:GetService("Debris")
local ResourceVFX = {}

local RenderController = Knit.GetController("RenderController")

local Assets = game.ReplicatedStorage.Assets.VFX.Misc
function ResourceVFX.Pick(RenderData)
	local ResourceCFrame = RenderData.ResourceCFrame

	local VFX = Assets.Pick:Clone()
	VFX:PivotTo(ResourceCFrame)
	VFX.Parent = workspace.VFX

	Debris:AddItem(VFX, 3)
	RenderController:EmitParticles(VFX)
end

return ResourceVFX
