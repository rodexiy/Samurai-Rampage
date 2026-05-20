local Debris = game:GetService("Debris")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RenderController = Knit.GetController("RenderController")
local SoundEffectController = Knit.GetController("SoundEffectController")

local UpSlash = {}

function ChangeColor(CharacterToRender, VFX)
	for _, Particle in VFX:GetDescendants() do
		if Particle:IsA("ParticleEmitter") then
			if CharacterToRender:GetAttribute("SwordOnFire") then
				Particle.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 195, 112)),
					ColorSequenceKeypoint.new(0.154, Color3.fromRGB(255, 94, 19)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 6, 6)),
				})
			elseif CharacterToRender:GetAttribute("ConfettiOnSword") then
				Particle.Color = ColorSequence.new(Color3.fromRGB(168, 87, 235))
			end
		end
	end
end

local Assets = game.ReplicatedStorage.Assets.VFX.Skills.Kendo.UpSlash
function UpSlash.Release(RenderData)
	local CharacterToRender = RenderData.Character

	local VFX = Assets.Slash:Clone()
	VFX.Size = Vector3.new(1.85, 1.85, 0.85)

	ChangeColor(CharacterToRender, VFX)
	VFX:PivotTo(CharacterToRender:GetPivot() * CFrame.Angles(math.rad(90), math.rad(-45), 0))
	RenderController:RenderSteppedWeldConstraint(CharacterToRender, VFX)

	task.delay(0.1, function()
		SoundEffectController:PlaySoundEffect("SlashCut", true, CharacterToRender.PrimaryPart)
	end)

	RenderController:EmitParticles(VFX)
	VFX.Parent = workspace.VFX

	Debris:AddItem(VFX, 3)
end

function UpSlash.Hit(RenderData)
	local CharacterToRender = RenderData.Character

	local VFX = Assets.Hit:Clone()

	ChangeColor(RenderData.Attacker, VFX)

	VFX:PivotTo(CharacterToRender:GetPivot() * CFrame.Angles(math.rad(90), math.rad(-45), 0))
	RenderController:RenderSteppedWeldConstraint(CharacterToRender, VFX)

	RenderController:EmitParticles(VFX)
	VFX.Parent = workspace.VFX

	Debris:AddItem(VFX, 3)
end

return UpSlash
