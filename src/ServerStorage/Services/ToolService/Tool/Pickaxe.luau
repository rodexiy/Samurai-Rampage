local Pickaxe = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local AnimationService = Knit.GetService("AnimationService")
local CollectionService = game:GetService("CollectionService")
local DebounceService = Knit.GetService("DebounceService")
local Players = game:GetService("Players")
local StaminaService = Knit.GetService("StaminaService")
local ResourceService = Knit.GetService("ResourceService")
local RenderService = Knit.GetService("RenderService")
local RealmService = Knit.GetService("RealmService")
local SoundEffectService = Knit.GetService("SoundEffectService")

local OresParams = OverlapParams.new()
OresParams.FilterType = Enum.RaycastFilterType.Include

local ORE_MAX_HEALTH_RANGE = { 2, 4 }

function Pickaxe.Activated(Character: Model, Data: { any })
	local Tool = Character:FindFirstChildWhichIsA("Tool")
	if
		not Tool
		or Character:GetAttribute("PickaxePick")
		or Character:GetAttribute("Died")
		or Character:GetAttribute("Ragdoll")
		or Character:GetAttribute("Stamina") < 15
	then
		return
	end

	local PickAnimation = Tool:FindFirstChild("Activated", true)
	if not PickAnimation then
		return
	end

	DebounceService:AddDebounce(Character, "PickaxePick", 1)
	local Track = AnimationService:PlayAnimation(Character, PickAnimation)
	Track.Priority = Enum.AnimationPriority.Action4

	local Player = game.Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end

	task.wait(0.3)

	OresParams.FilterDescendantsInstances = { workspace.Ores, CollectionService:GetTagged("Ore") }

	local _Ores =
		workspace:GetPartBoundsInBox(Character:GetPivot() * CFrame.new(0, 0, -2.5), Vector3.new(5, 5, 5), OresParams)

	local Ores = {}

	for _, Part in _Ores do
		local Ore = Part:FindFirstAncestorWhichIsA("Model")

		if Ore and not table.find(Ores, Ore) then
			table.insert(Ores, Ore)
		end
	end

	local Player = Players:GetPlayerFromCharacter(Character)

	for _, Ore in Ores do
		if Ore:GetAttribute("Broken") then
			continue
		end

		if not RealmService:HasOwnership(Player, Ore) then
			continue
		end

		if not Ore:GetAttribute("Health") then
			local MaxHealth = math.random(ORE_MAX_HEALTH_RANGE[1], ORE_MAX_HEALTH_RANGE[2])
			Ore:SetAttribute("MaxHealth", MaxHealth)
			Ore:SetAttribute("Health", MaxHealth)
		end

		RenderService:RenderForAllPlayers(
			"Resource",
			"Pick",
			{ Character = Player.Character, ResourceCFrame = Ore:GetPivot() }
		)
		RenderService:RenderForAllPlayers("Resource", "Shake", { Character = Character, Resource = Ore })


		SoundEffectService:PlayRandomFromFolder("PickaxeHit", true, Ore)
		local Health = Ore:GetAttribute("Health") - 1
		Ore:SetAttribute("Health", Health)

		if Health <= 0 then
			Ore:SetAttribute("Broken", true)
			ResourceService:BreakResource(Player, Ore)
		end
	end
end

return Pickaxe
