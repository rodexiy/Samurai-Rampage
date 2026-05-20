local Debris = game:GetService("Debris")
local Tags = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local RenderController = Knit.GetController("RenderController")

local VFXs = game.ReplicatedStorage.Assets.VFX.Tags
function Tags.ApplyEffect(RenderData)
	local CharacterToRender = RenderData.Character
	if VFXs:FindFirstChild(RenderData.Effect) then
		local VFX = RenderController:CreateInstance(Tags, CharacterToRender, VFXs[RenderData.Effect]:Clone())
		VFX.Size = Vector3.new(1.85, 1.85, 0.85)
		VFX.CanCollide = false
		VFX.Anchored = false
		VFX.Massless = true

		RenderController:WeldConstraint(CharacterToRender, VFX)
		VFX:PivotTo(CharacterToRender:GetPivot())

		VFX.Parent = workspace.VFX
	end
end

function Tags.RemoveEffect(RenderData)
	local CharacterToRender = RenderData.Character
	local vfx, index = RenderController:GetInstance(Tags, CharacterToRender, RenderData.Effect)
	if index then
		for _, particle: ParticleEmitter in vfx:GetDescendants() do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = false
			end
		end

		RenderController:RemoveInstance(Tags, CharacterToRender, index)
		Debris:AddItem(vfx, 2)
	end
end

function Tags.Caller(RenderData)
	local subbed = string.gsub(RenderData.Effect, "Remove_", "")
	if subbed == RenderData.Effect then
		Tags.ApplyEffect(RenderData)
	else
		RenderData.Effect = subbed
		Tags.RemoveEffect(RenderData)
	end
end

return Tags
