local Confetti = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InventoryService = Knit.GetService("InventoryService")
local Players = game:GetService("Players")
local BloodService = Knit.GetService("BloodService")
local DebounceService = Knit.GetService("DebounceService")
local TweenService = game:GetService("TweenService")

local Collector = require(game.ReplicatedStorage.Shared.Collector)

local function GetBladeSwordTrail(Blade: BasePart): Trail?
	local DirectTrail = Blade:FindFirstChild("SwordTrail")
	if DirectTrail and DirectTrail:IsA("Trail") then
		return DirectTrail
	end

	local Weapon = Blade:FindFirstAncestorWhichIsA("Model")
	if not Weapon then
		return nil
	end

	local SwordTrail = Weapon:FindFirstChild("SwordTrail", true)
	if SwordTrail and SwordTrail:IsA("Trail") then
		return SwordTrail
	end

	return nil
end

local function AttachEffectTrailToBlade(EffectVFX: Instance, Blade: BasePart, TrailName: string)
	local EffectTrail = EffectVFX:FindFirstChild(TrailName, true)
	if not EffectTrail or not EffectTrail:IsA("Trail") then
		return
	end

	local SwordTrail = GetBladeSwordTrail(Blade)
	if not SwordTrail then
		EffectTrail.Enabled = false
		return
	end

	EffectTrail.Attachment0 = SwordTrail.Attachment0
	EffectTrail.Attachment1 = SwordTrail.Attachment1
end

local function DisableConfettiVFX(ConfettiVFX: Instance)
	local Trail = ConfettiVFX:FindFirstChildWhichIsA("Trail", true)
	if Trail then
		Trail.Enabled = false
	end

	for _, VFX in ConfettiVFX:GetDescendants() do
		if VFX:IsA("ParticleEmitter") then
			VFX.Enabled = false
		end
	end

	local Sound = ConfettiVFX:FindFirstChildWhichIsA("Sound", true)
	local PointLight = ConfettiVFX:FindFirstChildWhichIsA("PointLight", true)
	if Sound then
		TweenService:Create(Sound, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { Volume = 0 }):Play()
	end
	if PointLight then
		TweenService:Create(PointLight, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { Brightness = 0 }):Play()
	end
end

function Confetti.Activated(Character: Model, Data: { any })
	local Player = Players:GetPlayerFromCharacter(Character)

	if
		Character:GetAttribute("Ragdoll")
		or Character:GetAttribute("Died")
		or not Character:GetAttribute("WeaponEquipped")
	then
		return
	end

	local Blades = BloodService:GetBlades(Character)
	if #Blades == 0 then
		return
	end

	local WasOnConfetti = Character:GetAttribute("ConfettiOnSword")
	Character:SetAttribute("SwordOnFire", false)
	DebounceService:AddDebounce(Character, "ConfettiOnSword", 30)

	if Player then
		InventoryService:RemoveItemFromPlayer(Player, "Confetti", 1)
		task.defer(function()
			Character.Humanoid:UnequipTools()
		end)
	end

	if WasOnConfetti then
		return
	end

	local ConfettiVFXs = {}
	for _, Blade in Blades do
		local ConfettiVFX: MeshPart = game.ReplicatedStorage.Assets.VFX.Buff.SwordConfetti:Clone()
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = Blade
		Weld.Part1 = ConfettiVFX
		Weld.Parent = ConfettiVFX
		ConfettiVFX.Name = "ConfettiVFX"
		ConfettiVFX.Size = Blade.Size
		ConfettiVFX:PivotTo(Blade:GetPivot())
		ConfettiVFX.Parent = Blade

		AttachEffectTrailToBlade(ConfettiVFX, Blade, "ConfettiTrail")
		table.insert(ConfettiVFXs, ConfettiVFX)
	end

	local Connections = Collector.new()
	Connections:Add(Character:GetAttributeChangedSignal("ConfettiOnSword"):Connect(function()
		if not Character:GetAttribute("ConfettiOnSword") then
			for _, ConfettiVFX in ConfettiVFXs do
				DisableConfettiVFX(ConfettiVFX)
			end

			task.wait(1)
			for _, ConfettiVFX in ConfettiVFXs do
				ConfettiVFX:Destroy()
			end
			Connections:Destroy()
		end
	end))
end

return Confetti
