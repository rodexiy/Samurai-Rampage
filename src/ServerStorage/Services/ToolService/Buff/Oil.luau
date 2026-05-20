local Oil = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InventoryService = Knit.GetService("InventoryService")
local Players = game:GetService("Players")
local BloodService = Knit.GetService("BloodService")
local DebounceService = Knit.GetService("DebounceService")
local TweenService = game:GetService("TweenService")

local Collector = require(game.ReplicatedStorage.Shared.Collector)

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
	if not Blades then
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

	local Blade = Blades[1]

	local FireVFX: MeshPart = game.ReplicatedStorage.Assets.VFX.Buff.SwordFire:Clone()
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = Blade
	Weld.Part1 = FireVFX
	Weld.Parent = FireVFX

	local SwordTrail = Character.Assets:FindFirstChild("SwordTrail", true)
	local FireTrail = FireVFX:FindFirstChild("FireTrail", true)
	if FireTrail then
		if not SwordTrail then
			FireTrail.Enabled = false
		end

		FireTrail.Attachment0 = SwordTrail.Attachment0
		FireTrail.Attachment1 = SwordTrail.Attachment1
	end

	FireVFX.Name = "FireVFX"
	FireVFX.Size = Blade.Size
	FireVFX:PivotTo(Blade:GetPivot())
	FireVFX.Parent = Blade

	local Connections = Collector.new()
	Connections:Add(Character:GetAttributeChangedSignal("SwordOnFire"):Connect(function()
		if not Character:GetAttribute("SwordOnFire") then
			local Trail = FireVFX:FindFirstChildWhichIsA("Trail", true)
			if Trail then
				Trail.Enabled = false
			end
			for _, VFX in FireVFX:GetChildren() do
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

			task.wait(1)
			FireVFX:Destroy()
			Connections:Destroy()
		end
	end))
end

return Oil
