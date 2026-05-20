local Debris = game:GetService("Debris")
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local FireSlash = {}

local TweenService = game:GetService("TweenService")
local CraterModule = require(game.ReplicatedStorage.Assets.Libraries.CraterModule)

local RenderController
local CameraController
local SoundEffectController

local Player = game.Players.LocalPlayer

local Assets = game.ReplicatedStorage.Assets.VFX.Skills.KagutsuchiEmblem.FireSlash

function FireSlash.Release(RenderData)
	local RootCFrame = RenderData.RootCFrame
	local Slash = Assets.FireSlash:Clone()
	Slash:PivotTo(RootCFrame)
	Slash.Parent = workspace.VFX

	RenderController:EmitParticles(Slash.Part.Emit)
	SoundEffectController:PlaySoundEffect("FlameWoosh_2", true, Slash.Part)

	local Duration = 1.25
	local i = 0
	while i < Duration do
		local dt = task.wait()
		local newCFrame = Slash:GetPivot() * CFrame.new(0, 0, -40 * dt)
		Slash:PivotTo(newCFrame)
		i += dt
	end

	RenderController:StopParticles(Slash)
	task.wait(0.5)
	Slash:Destroy()
end

function FireSlash.Start()
	RenderController = Knit.GetController("RenderController")
	CameraController = Knit.GetController("CameraController")
	SoundEffectController = Knit.GetController("SoundEffectController")
end

return FireSlash
