local Debris = game:GetService("Debris")
local Enemy = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SoundEffectController = Knit.GetController("SoundEffectController")
local RenderController = Knit.GetController("RenderController")

local VFX = game.ReplicatedStorage.Assets.VFX

function Enemy.Detect(Data)
	local CharacterToRender = Data.Character
	SoundEffectController:PlaySoundEffect("Enemy_Detected", true)
	local Exclamation = VFX.Misc.Exclamation:Clone()
	--RenderController:WeldConstraint(CharacterToRender, Exclamation)
	Exclamation.Anchored = true
	Exclamation:PivotTo(CharacterToRender:GetPivot())
	Exclamation.Parent = workspace.VFX
	RenderController:EmitParticles(Exclamation)
	Debris:AddItem(Exclamation, 1)
end

return Enemy
