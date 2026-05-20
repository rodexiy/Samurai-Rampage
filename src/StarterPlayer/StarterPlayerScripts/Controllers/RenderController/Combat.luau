local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Combat = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local BloodEngine = require(game.ReplicatedStorage.Assets.Libraries.BloodEngine)

local LightningBolt = require(game.ReplicatedStorage.Assets.Libraries.LightningBolt)
local LightningSparks = require(game.ReplicatedStorage.Assets.Libraries.LightningBolt.LightningSparks)

local RenderController = Knit.GetController("RenderController")
local SoundEffectController = Knit.GetController("SoundEffectController")
local ScreenParticleController = Knit.GetController("ScreenParticleController")
local AnimationController = Knit.GetController("AnimationController")

local CameraController = Knit.GetController("CameraController")

local CombatVFX = game.ReplicatedStorage.Assets.VFX.Combat

local Engine = BloodEngine.new({
	Limit = 500,
	Type = "Decal",
	Expansion = true,
	DecayDelay = { 3, 6 },
	DefaultSize = { 1.5, 2 },
	DefaultTransparency = { 0, 0.1 },
	OffsetRange = { -10, 10 },
	Filter = { workspace:WaitForChild("Entity") },
})

local UnequipEngine = BloodEngine.new({
	Limit = 500,
	Type = "Decal",
	Expansion = true,
	DefaultSize = { 1, 1.5 },
	DefaultTransparency = { 0, 0.1 },
	DecayDelay = { 3, 6 },
	OffsetRange = { -15, 15 },
	Filter = { workspace:WaitForChild("Entity") },
})

function Combat.AttackSlash(Data)
	local CharacterToRender = Data.Character
	local CFrameOffset = Data.SlashCFrame
	local SlashName = Data.Slash or "NormalSlash"
	local Reversed = Data.SlashReverse or false

	if Reversed then
		SlashName = "Reverse" .. SlashName
	end

	local Model = Instance.new("Model")
	local VFX

	if Data.SlashInstance then
		VFX = Data.SlashInstance:Clone()
		CFrameOffset = CFrame.Angles(VFX:GetPivot():ToOrientation())
	else
		if not CombatVFX.Slash:FindFirstChild(SlashName) then
			return
		end
		VFX = CombatVFX.Slash[SlashName]:Clone()
	end

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

	VFX.Parent = Model
	Model.PrimaryPart = VFX
	Model:PivotTo(CharacterToRender:GetPivot() * CFrameOffset)

	VFX.Anchored = true
	--RenderController:WeldConstraint(CharacterToRender, Model)

	RenderController:EmitParticles(VFX)

	Model.Parent = workspace.VFX
	Debris:AddItem(Model, 2)
end

function Combat.ScreenParticle(RenderData)
	local CharacterToRender = RenderData.Character

	RenderController:ExecuteForCharacter(CharacterToRender, function()
		ScreenParticleController:EmitParticle(RenderData.Particle, RenderData.Duration)
	end)
end

function Combat.Blood(Data)
	local CharacterToRender = Data.Character
	local Attacker = Data.Attacker

	local Player = Players:GetPlayerFromCharacter(CharacterToRender)

	if Player and Player:GetAttribute("BloodFX") then
		Engine:EmitAmount(CharacterToRender.PrimaryPart, nil, math.random(2, 5))
	end

	if not Data.Ranged then
		RenderController:ExecuteForCharacter(CharacterToRender, function()
			CameraController:ShakeOnce(3, 10, 0.1, 0.1)
			ScreenParticleController:EmitParticle("Blood", 1.5)
		end)
	end

	RenderController:ExecuteForCharacter(Data.Attacker, function()
		CameraController:ShakeOnce(2, 10, 0.1, 0.1)
	end)

	local VFX
	if Attacker:GetAttribute("SwordOnFire") then
		VFX = CombatVFX.HitFlame:Clone()
	elseif Attacker:GetAttribute("ConfettiOnSword") then
		VFX = CombatVFX.HitConfetti:Clone()
	else
		VFX = CombatVFX.Hit:Clone()
	end

	VFX.Anchored = true
	--RenderController:WeldConstraint(CharacterToRender, VFX)
	VFX:PivotTo(CharacterToRender:GetPivot())
	RenderController:EmitParticles(VFX)
	VFX.Parent = workspace.VFX

	Debris:AddItem(VFX, 2)

	SoundEffectController:PlayRandomFromFolder("Hit", true, CharacterToRender.PrimaryPart)
end

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local DeflectedCC: ColorCorrectionEffect = game.Lighting:WaitForChild("DeflectedCC")
local DeflectedBlur: BlurEffect = game.Lighting:WaitForChild("DeflectedBlur")
local Vignette: ScreenGui = PlayerGui:WaitForChild("Temporary", math.huge):WaitForChild("Vignette")
function Combat.Deflect(Data)
	local CharacterToRender = Data.Character
	local IsCounter = Data.IsCounter

	local VFX = CombatVFX.Deflect:Clone()
	VFX:PivotTo(Data.RayCFrame or (CharacterToRender:GetPivot() * CFrame.new(0, 0, -1)))
	VFX.Floor.WorldCFrame = CharacterToRender.HumanoidRootPart.CFrame * CFrame.new(0, -2.75, 0)
	RenderController:EmitParticles(VFX)
	VFX.Parent = workspace.VFX

	if not IsCounter then
		local Deflect = SoundEffectController:PlayRandomFromFolder("Deflect", true, CharacterToRender.PrimaryPart)
		SoundEffectController:AddPitchEffect(Deflect, 0.9, 1.25)
	else
		SoundEffectController:PlaySoundEffect("Deflected", true, CharacterToRender.PrimaryPart)
	end

	RenderController:ExecuteForCharacter(CharacterToRender, function()
		CameraController:ShakeOnce(5, 15, 0.1, 0.25)
	end)
	if not Data.Ranged then
		RenderController:ExecuteForCharacter(Data.Attacker, function()
			CameraController:ShakeOnce(5, 15, 0.1, 0.25)
		end)
	end

	Debris:AddItem(VFX.PointLight, 0.15)

	local function ScreenEffects(Char)
		local Player = Players:GetPlayerFromCharacter(Char)
		if not Player:GetAttribute("ScreenParticles") or Data.Ranged then
			return
		end

		local Blur = DeflectedBlur:Clone()
		Blur.Parent = game.Lighting
		Blur.Enabled = true

		TweenService:Create(Blur, TweenInfo.new(0.3, Enum.EasingStyle.Linear), { Size = 0 }):Play()

		Debris:AddItem(Blur, 0.3)

		local CC = DeflectedCC:Clone()
		CC.Parent = game.Lighting
		CC.Enabled = true

		TweenService:Create(
			CC,
			TweenInfo.new(0.5, Enum.EasingStyle.Linear),
			{ Contrast = 0, Saturation = 0, TintColor = Color3.fromRGB(255, 255, 255) }
		):Play()

		local Vignette = Vignette:Clone()
		Vignette.Effect.ImageTransparency = 0.65
		Vignette.Enabled = true
		Vignette.Parent = PlayerGui

		TweenService:Create(Vignette.Effect, TweenInfo.new(0.25, Enum.EasingStyle.Linear), { ImageTransparency = 1 })
			:Play()

		Debris:AddItem(Vignette, 0.3)

		Debris:AddItem(CC, 0.5)
	end

	RenderController:ExecuteForCharacter(CharacterToRender, function()
		ScreenEffects(CharacterToRender)
	end)

	if not Data.Ranged then
		RenderController:ExecuteForCharacter(Data.Attacker, function()
			ScreenEffects(Data.Attacker)
		end)
	end

	Debris:AddItem(VFX, 1)
end

local Camera = workspace.CurrentCamera
function Combat.HeavyDeflect(Data)
	local CharacterToRender = Data.Character

	local VFX = CombatVFX.HeavyDeflect:Clone()
	VFX:PivotTo(CharacterToRender:GetPivot())
	VFX.Parent = workspace.VFX
	VFX.Anchored = true
	RenderController:EmitParticles(VFX)
	Debris:AddItem(VFX, 1.5)

	RenderController:ExecuteForCharacter(CharacterToRender, function()
		RunService:BindToRenderStep("HeavyDeflect", Enum.RenderPriority.Camera.Value + 2, function(dt)
			Camera.CameraType = Enum.CameraType.Scriptable
			Camera.CFrame = Camera.CFrame:Lerp(
				CharacterToRender.HumanoidRootPart:GetPivot()
					* CFrame.new(4.5, 0.5, 7.5)
					* CFrame.Angles(0, math.rad(15), 0),
				5 * dt
			)
		end)

		TweenService
			:Create(Camera, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = 55 })
			:Play()

		task.wait(0.7)

		TweenService
			:Create(Camera, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = 75 })
			:Play()

		task.wait(0.1)
		RunService:UnbindFromRenderStep("HeavyDeflect")
		if not CharacterToRender:GetAttribute("LockedOnEnemy") then
			Camera.CameraType = Enum.CameraType.Custom
		end
	end)
end

function Combat.Block(Data)
	local CharacterToRender = Data.Character
	local VFX = CombatVFX.Block:Clone()
	VFX:PivotTo(Data.RayCFrame or (CharacterToRender:GetPivot() * CFrame.new(0, 0, -1)))
	RenderController:EmitParticles(VFX)
	VFX.Parent = workspace.VFX

	RenderController:ExecuteForCharacter(CharacterToRender, function()
		CameraController:ShakeOnce(1.5, 10, 0.1, 0.1)
	end)

	if not Data.Ranged then
		RenderController:ExecuteForCharacter(Data.Attacker, function()
			CameraController:ShakeOnce(0.75, 10, 0.1, 0.1)
		end)
	end

	SoundEffectController:PlayRandomFromFolder("Block", true, CharacterToRender.PrimaryPart)

	Debris:AddItem(VFX, 2)
end

local MiscFolder = game.ReplicatedStorage.Assets.VFX.Misc
function Combat.Roll(Data)
	local CharacterToRender = Data.Character
	local StartCFrame = Data.StartCFrame
	if not CharacterToRender then
		return
	end

	local ConvertDirection = {
		Forward = CFrame.Angles(0, math.rad(180), 0),
		Backward = CFrame.Angles(0, 0, 0),
		Left = CFrame.Angles(0, math.rad(-90), 0),
		Right = CFrame.Angles(0, math.rad(90), 0),
	}

	local PlayerToRender = Players:GetPlayerFromCharacter(CharacterToRender)
	local HasLightningDash = false

	if PlayerToRender then
		HasLightningDash = PlayerToRender.UnlockedNodes:FindFirstChild("Lightning Dash") ~= nil
	end
	if CharacterToRender:GetAttribute("Race") == "Raijin" and HasLightningDash then
		local A1 = Instance.new("Attachment")
		A1.Parent = workspace.LightningHandler.PrimaryPart
		A1.WorldCFrame = StartCFrame

		local A2 = Instance.new("Attachment")
		A2.Parent = workspace.LightningHandler.PrimaryPart
		A2.WorldCFrame = CharacterToRender.HumanoidRootPart.CFrame

		local NewBolt = LightningBolt.new(A1, A2, 50)
		NewBolt.PulseSpeed = 20
		NewBolt.PulseLength = 2
		NewBolt.Thickness = 1
		NewBolt.FadeLength = 0.2
		NewBolt.AnimationSpeed = 20
		NewBolt.Frequency = 5
		NewBolt.Color = Color3.fromRGB(255, 255, 0)

		LightningSparks.new(NewBolt)

		local Lightning = MiscFolder.DashLightning:Clone()
		local Distance = (StartCFrame.Position - CharacterToRender.HumanoidRootPart.CFrame.Position).Magnitude

		local MiddleCFrame = CFrame.new(StartCFrame.Position, CharacterToRender.HumanoidRootPart.CFrame.Position)
			* CFrame.new(0, 0, -Distance / 2)
			* CFrame.Angles(0, math.rad(90), 0)
		Lightning.Size = Vector3.new(Distance, 3, 3)

		Lightning.CFrame = MiddleCFrame
		Lightning.Anchored = true
		Lightning.Parent = workspace.VFX
		RenderController:EmitParticles(Lightning)
		Debris:AddItem(Lightning, 5)
		Debris:AddItem(A1, 2)
		Debris:AddItem(A2, 2)

		local Sound = SoundEffectController:PlaySoundEffect("LightningTp", true, CharacterToRender.HumanoidRootPart)
		SoundEffectController:AddPitchEffect(Sound, 0.9, 1.1)

		return
	end

	SoundEffectController:PlaySoundEffect("Roll", true, CharacterToRender.PrimaryPart)
	local Dash = CombatVFX.Dash:Clone()

	local RayParams = RaycastParams.new()
	RayParams.FilterDescendantsInstances = { workspace:WaitForChild("Entity") }
	RayParams.FilterType = Enum.RaycastFilterType.Exclude
	RayParams.RespectCanCollide = true

	local cast = workspace:Raycast(
		CharacterToRender:GetPivot().Position,
		-(CharacterToRender:GetPivot().UpVector * 3.5),
		RayParams
	)

	if not cast then
		Dash:Destroy()
		return
	end
	for _, particle in Dash:GetDescendants() do
		if particle:IsA("ParticleEmitter") then
			local x = cast.Instance.Color
			particle.Color = ColorSequence.new(x, x)
		end
	end
	Dash:PivotTo(CharacterToRender:GetPivot() * CFrame.new(0, -2.5, 0) * ConvertDirection[Data.Direction])
	Dash.Parent = workspace.VFX
	Debris:AddItem(Dash, 5)
	RenderController:EmitParticles(Dash)
end

function Combat.Kanji(Data)
	local CharacterToRender = Data.Character
	local VFX = CombatVFX.Kanji:Clone()

	Debris:AddItem(VFX.PointLight, 0.15)

	VFX.Anchored = true
	VFX:PivotTo(CharacterToRender:GetPivot() * CFrame.new(0, 5, 0))
	RenderController:EmitParticles(VFX)
	VFX.Parent = workspace.VFX

	SoundEffectController:PlaySoundEffect("Kanji", true, CharacterToRender.PrimaryPart)

	Debris:AddItem(VFX, 3)
end

function Combat.DodgeKanji(Data)
	local CharacterToRender = Data.Character
	local VFX = CombatVFX.DodgeKanji:Clone()

	Debris:AddItem(VFX.PointLight, 0.15)
	VFX.Anchored = true
	VFX:PivotTo(CharacterToRender:GetPivot() * CFrame.new(0, 5, 0))
	RenderController:EmitParticles(VFX)
	VFX.Parent = workspace.VFX

	SoundEffectController:PlaySoundEffect("DodgeKanji", true, CharacterToRender.PrimaryPart)

	Debris:AddItem(VFX, 3)
end

function Combat.IncomingHit(Data)
	local CharacterToRender = Data.Character
	SoundEffectController:PlaySoundEffect("Kanji", true)
	local Exclamation = CombatVFX.IncomingHit:Clone()
	Exclamation.Anchored = true
	Exclamation:PivotTo(CharacterToRender:GetPivot())
	Exclamation.Parent = workspace.VFX
	RenderController:EmitParticles(Exclamation)
	Debris:AddItem(Exclamation, 1)
end

function Combat.UnequipBlood(Data)
	local CharacterToRender = Data.Character
	local Root = CharacterToRender.PrimaryPart
	if not Root then
		return
	end

	local Weapon = CharacterToRender.Assets.Weapon:FindFirstChild("Weapon")
	local Position = (Root.CFrame * CFrame.new(1.5, -1, -1)).Position

	if Weapon and Weapon.PrimaryPart then
		Position = Weapon.PrimaryPart
	end

	local Player = Players:GetPlayerFromCharacter(CharacterToRender)
	if not Player then
		return
	end
	if Player:GetAttribute("BloodFX") then
		UnequipEngine:EmitAmount(Position, Root.CFrame.RightVector, math.random(4, 6))
	end
end

function Combat.Dodge(Data)
	local CharacterToRender = Data.Character

	local VFX = CombatVFX.Dodge:Clone()
	VFX.Anchored = true
	--RenderController:WeldConstraint(VFX, CharacterToRender.PrimaryPart)
	VFX:PivotTo(CharacterToRender:GetPivot())
	RenderController:EmitParticles(VFX)
	VFX.Parent = workspace.VFX

	Debris:AddItem(VFX, 1.5)
end
function Combat.SheathStar(Data)
	local CharacterToRender = Data.Character

	local WeaponModel = CharacterToRender.Assets.Weapon:FindFirstChild("Weapon")
	if not WeaponModel or not WeaponModel.PrimaryPart then
		return
	end

	SoundEffectController:PlaySoundEffect("SheathStar", true, CharacterToRender.PrimaryPart)
	local VFX = CombatVFX.SheathStar:Clone()
	VFX:PivotTo(WeaponModel.PrimaryPart:GetPivot())
	VFX.Anchored = true
	--RenderController:WeldConstraint(VFX, WeaponModel.PrimaryPart)
	RenderController:EmitParticles(VFX)
	VFX.Parent = workspace.VFX

	Debris:AddItem(VFX, 1.5)
end

function Combat.PostureBreak(Data)
	local CharacterToRender = Data.Character

	RenderController:ExecuteForCharacter(CharacterToRender, function()
		AnimationController:StopAnimationFind(CharacterToRender, "Block")
	end)

	local VFX = CombatVFX.PostureBreak:Clone()
	Debris:AddItem(VFX.PointLight, 0.15)

	VFX.Anchored = true
	VFX:PivotTo(CharacterToRender:GetPivot())
	RenderController:EmitParticles(VFX)
	VFX.Parent = workspace.VFX

	Debris:AddItem(VFX, 5)
end

for _, Sound: Sound in game:GetDescendants() do
	if Sound:IsA("Sound") and Sound.SoundId == "rbxassetid://3537873683" then
		print(Sound)
	end
end

return Combat
