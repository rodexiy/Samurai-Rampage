local Debris = game:GetService("Debris")
local Artifacts = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local RenderController = Knit.GetController("RenderController")

local UseArtifact = game.ReplicatedStorage.Assets.VFX.UseArtifact
function Artifacts.ThunderHeart(RenderData)
	local CharacterToRender = RenderData.Character

	local VFX = UseArtifact.ThunderHeart:Clone()
	VFX.Parent = workspace.VFX
	VFX:PivotTo(CFrame.new(CharacterToRender:GetPivot().Position) * CFrame.new(0, -1.25, 0))
	RenderController:EmitParticles(VFX)

	Debris:AddItem(VFX, 3)
end

return Artifacts
