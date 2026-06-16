local Oil = {}

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

local function DisableFireVFX(FireVFX: Instance)
	local Trail = FireVFX:FindFirstChildWhichIsA("Trail", true)
	if Trail then
		Trail.Enabled = false
	end

	for _, VFX in FireVFX:GetDescendants() do
		if VFX:IsA("ParticleEmitter") then
			VFX.Enabled = false
		end
	end

	local Sound = FireVFX:FindFirstChildWhichIsA("Sound", true)
	if Sound then
		TweenService:Create(Sound, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { Volume = 0 }):Play()
	end

	local PointLight = FireVFX:FindFirstChildWhichIsA("PointLight", true)
	if PointLight then
		TweenService:Create(PointLight, TweenInfo.new(0.5, Enum.EasingStyle.Linear), { Brightness = 0 }):Play()
	end
end

function Oil.Activated(Character: Model, Data: { any })
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

	local WasOnFire = Character:GetAttribute("SwordOnFire")
	DebounceService:AddDebounce(Character, "SwordOnFire", 30)

	Character:SetAttribute("ConfettiOnSword", false)
	if Player then
		InventoryService:RemoveItemFromPlayer(Player, "Oil", 1)
		task.defer(function()
			Character.Humanoid:UnequipTools()
		end)
	end

	if WasOnFire then
		return
	end

	local FireVFXs = {}
	for _, Blade in Blades do
		local FireVFX: MeshPart = game.ReplicatedStorage.Assets.VFX.Buff.SwordFire:Clone()
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = Blade
		Weld.Part1 = FireVFX
		Weld.Parent = FireVFX

		AttachEffectTrailToBlade(FireVFX, Blade, "FireTrail")

		FireVFX.Name = "FireVFX"
		FireVFX.Size = Blade.Size
		FireVFX:PivotTo(Blade:GetPivot())
		FireVFX.Parent = Blade
		table.insert(FireVFXs, FireVFX)
	end

	local Connections = Collector.new()
	Connections:Add(Character:GetAttributeChangedSignal("SwordOnFire"):Connect(function()
		if not Character:GetAttribute("SwordOnFire") then
			for _, FireVFX in FireVFXs do
				DisableFireVFX(FireVFX)
			end

			task.wait(1)
			for _, FireVFX in FireVFXs do
				FireVFX:Destroy()
			end
			Connections:Destroy()
		end
	end))
end

return Oil
