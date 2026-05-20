local Confetti = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InventoryService = Knit.GetService("InventoryService")
local Players = game:GetService("Players")
local BloodService = Knit.GetService("BloodService")
local DebounceService = Knit.GetService("DebounceService")
local TweenService = game:GetService("TweenService")

local Collector = require(game.ReplicatedStorage.Shared.Collector)

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
	if not Blades then
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

	local Blade = Blades[1]

	local ConfettiVFX: MeshPart = game.ReplicatedStorage.Assets.VFX.Buff.SwordConfetti:Clone()
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = Blade
	Weld.Part1 = ConfettiVFX
	Weld.Parent = ConfettiVFX
	ConfettiVFX.Name = "ConfettiVFX"
	ConfettiVFX.Size = Blade.Size
	ConfettiVFX:PivotTo(Blade:GetPivot())
	ConfettiVFX.Parent = Blade

	local SwordTrail = Character.Assets:FindFirstChild("SwordTrail", true)
	local ConfettiTrail = ConfettiVFX:FindFirstChild("ConfettiTrail", true)
	if ConfettiTrail then
		if not SwordTrail then
			ConfettiTrail.Enabled = false
		end

		ConfettiTrail.Attachment0 = SwordTrail.Attachment0
		ConfettiTrail.Attachment1 = SwordTrail.Attachment1
	end

	local Connections = Collector.new()
	Connections:Add(Character:GetAttributeChangedSignal("ConfettiOnSword"):Connect(function()
		if not Character:GetAttribute("ConfettiOnSword") then
			local Trail = ConfettiVFX:FindFirstChildWhichIsA("Trail", true)
			if Trail then
				Trail.Enabled = false
			end
			for _, VFX in ConfettiVFX:GetChildren() do
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

			task.wait(1)
			ConfettiVFX:Destroy()
			Connections:Destroy()
		end
	end))
end

return Confetti
