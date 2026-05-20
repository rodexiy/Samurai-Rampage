local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RenderController = Knit.GetController("RenderController")
local SoundEffectController = Knit.GetController("SoundEffectController")
local AnimationController = Knit.GetController("AnimationController")
local CameraController = Knit.GetController("CameraController")

local Kurohitsugi = {}

local Assets = game.ReplicatedStorage.Assets.VFX.Skills.DevSpec.Kurohitsugi
function Kurohitsugi.Release(RenderData)
	local CharacterToRender = RenderData.Character
	local RootPart = CharacterToRender:FindFirstChild("HumanoidRootPart")
	SoundEffectController:PlaySoundEffect("Kurohitsugi", true, RenderData.Character.PrimaryPart)

	local chair = Assets.chair:Clone()
	chair.Parent = workspace.VFX
	chair:PivotTo(RootPart.CFrame * CFrame.new(0, -2, 0) * CFrame.Angles(0, math.rad(90), 0))
	TweenService:Create(RootPart, TweenInfo.new(0), { CFrame = RootPart.CFrame * CFrame.new(0, 1, 0) }):Play()

	task.wait(3.5)

	local vfxWhite = Assets.vfxWhite:Clone()
	vfxWhite.Parent = workspace.VFX
	vfxWhite.CFrame = RootPart.CFrame * CFrame.new(0, 0, 0)

	local ShadowVFX = Assets.ShadowVFX:Clone()
	ShadowVFX.Parent = workspace.VFX
	ShadowVFX.CFrame = RootPart.CFrame * CFrame.new(0, 300, 0)

	task.wait(1.2)

	local Kurohitsugi = Assets.Kurohitsugi:Clone()
	local part0 = Kurohitsugi:FindFirstChild("0")

	if part0 then
		Kurohitsugi.Parent = workspace.VFX
		part0.CFrame = RootPart.CFrame * CFrame.new(0, -8.5, 0)

		local weld1 = Instance.new("ManualWeld")
		weld1.Part0 = part0
		weld1.Part1 = RootPart
		weld1.C0 = part0.CFrame:ToObjectSpace(RootPart.CFrame * CFrame.new(0, 0, 0))
		weld1.Parent = part0

		task.wait(0.45)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "1" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 0 }):Play()
			end
		end

		task.wait(0.45)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "2" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 0 }):Play()
			end
		end

		task.wait(0.45)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "3" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 0 }):Play()
			end
		end

		task.wait(0.45)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "4" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 0 }):Play()
			end
		end

		task.wait(0.45)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "5" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 0 }):Play()
			end
		end

		task.wait(0.45)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "6" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 0 }):Play()
			end
		end

		task.wait(0.45)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "7" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 0 }):Play()
			end
		end

		local HitVFX = Assets.HITVFX:Clone()
		HitVFX.Parent = workspace.VFX
		HitVFX.CFrame = part0.CFrame * CFrame.new(0, 300, 0)
		RenderController:EmitParticles(HitVFX)

		game.Debris:AddItem(HitVFX, 3)
		ShadowVFX:Destroy()
		vfxWhite:Destroy()

		task.wait(0.8)

		task.wait(0.065)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "7" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 1 }):Play()
			end
		end

		task.wait(0.065)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "6" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 1 }):Play()
			end
		end

		task.wait(0.065)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "5" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 1 }):Play()
			end
		end

		task.wait(0.065)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "4" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 1 }):Play()
			end
		end

		task.wait(0.065)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "3" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 1 }):Play()
			end
		end

		task.wait(0.065)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "2" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 1 }):Play()
			end
		end

		task.wait(0.065)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "1" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 1 }):Play()
			end
		end

		task.wait(0.065)

		for _, part in ipairs(Kurohitsugi:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "0" then
				TweenService:Create(part, TweenInfo.new(0), { Transparency = 1 }):Play()
			end
		end

		chair:Destroy()

		Kurohitsugi:Destroy()
	end
end

function Kurohitsugi.Hit(RenderData)
	local Character = RenderData.Character

	local HitVFX = Assets.wb:Clone()
	HitVFX.CFrame = Character:GetPivot()
	HitVFX.Parent = workspace.VFX
	for _, part in pairs(HitVFX:GetDescendants()) do
		if part:IsA("ParticleEmitter") then
			task.spawn(function()
				part.Enabled = true
				task.wait(6)
				part.Enabled = false
			end)
		end
	end

	local weldE = Instance.new("ManualWeld")
	weldE.Name = "HitboxWeld"
	weldE.Part0 = HitVFX
	weldE.Part1 = Character.HumanoidRootPart
	weldE.C0 = HitVFX.CFrame:ToObjectSpace(Character:GetPivot())
	weldE.Parent = HitVFX

	task.spawn(function()
		RenderController:ExecuteForCharacter(RenderData.Character, function()
			for i = 1, 360 do
				CameraController:ShakeOnce(3, 15, 0.1, 0.1)
				task.wait(0.01)
			end
		end)
	end)

	task.wait(0.5)
	HitVFX:Destroy()
end

return Kurohitsugi
