local Debris = game:GetService("Debris")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RenderController = Knit.GetController("RenderController")
local SoundEffectController = Knit.GetController("SoundEffectController")

local Misc = {}
local NumberIndicator = require(game.ReplicatedStorage.Shared.Utils.NumberIndicator)

local MiscVFX = game.ReplicatedStorage.Assets.VFX.Misc
function Misc.LevelUp(RenderData)
	local CharacterToRender = RenderData.Character

	local LevelUp = MiscVFX.LevelUp:Clone()
	RenderController:WeldConstraint(CharacterToRender, LevelUp)
	LevelUp:PivotTo(CharacterToRender:GetPivot())
	LevelUp.Parent = workspace.VFX

	RenderController:EmitParticles(LevelUp)

	SoundEffectController:PlaySoundEffect("LevelUp", true, CharacterToRender.PrimaryPart)

	Debris:AddItem(LevelUp, 3)
end

function Misc.EarnExp(RenderData)
	local CharacterToRender = RenderData.Character

	local EarnExp = MiscVFX.EarnExp:Clone()
	RenderController:WeldConstraint(CharacterToRender, EarnExp)
	EarnExp:PivotTo(CharacterToRender:GetPivot())
	EarnExp.Parent = workspace.VFX

	RenderController:EmitParticles(EarnExp)

	RenderController:ExecuteForCharacter(CharacterToRender, function()
		NumberIndicator:Indicate("+" .. RenderData.Amount, CharacterToRender, "Exp", 2)
	end)
	--SoundEffectController:PlaySoundEffect("LevelUp", true, CharacterToRender.PrimaryPart)

	Debris:AddItem(EarnExp, 3)
end

function Misc.Countdown(RenderData)
	local CharacterToRender = RenderData.Character

	RenderController:ExecuteForCharacter(CharacterToRender, function()
		NumberIndicator:Countdown(RenderData.InitialValue, CharacterToRender, "Countdown", 2)
	end)
end

function Misc.MeditateNewRug(RenderData)
	local CharacterToRender = RenderData.Character

	local LevelUp = MiscVFX.MeditateNewRug:Clone()
	RenderController:WeldConstraint(CharacterToRender, LevelUp)
	LevelUp:PivotTo(CharacterToRender:GetPivot())
	LevelUp.Parent = workspace.VFX

	RenderController:EmitParticles(LevelUp)

	Debris:AddItem(LevelUp, 3)
end

return Misc
