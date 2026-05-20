local Axe = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local AnimationService = Knit.GetService("AnimationService")
local CollectionService = game:GetService("CollectionService")
local DebounceService = Knit.GetService("DebounceService")
local Players = game:GetService("Players")
local StaminaService = Knit.GetService("StaminaService")
local ResourceService = Knit.GetService("ResourceService")

local ShakeObject = require(game.ReplicatedStorage.Shared.ShakeObject)

local TreeParams = OverlapParams.new()
TreeParams.FilterType = Enum.RaycastFilterType.Whitelist

function Axe.Activated(Character: Model, Data: { any })
	TreeParams.FilterDescendantsInstances = { workspace.Map.Vegetation.Trees, CollectionService:GetTagged("Tree") }

	local Tool = Character:FindFirstChildWhichIsA("Tool")
	if
		not Tool
		or Character:GetAttribute("AxePick")
		or Character:GetAttribute("Died")
		or Character:GetAttribute("Ragdoll")
		or Character:GetAttribute("Stamina") < 15
	then
		return
	end

	local AxeAnimation = Tool:FindFirstChild("Activated", true)
	if not AxeAnimation then
		return
	end

	StaminaService:RemoveStamina(Character, 15)

	DebounceService:AddDebounce(Character, "AxePick", 2)
	local Track = AnimationService:PlayAnimation(Character, AxeAnimation)
	Track.Priority = Enum.AnimationPriority.Action4

	local Player = game.Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end

	local Tree =
		workspace:GetPartBoundsInBox(Character:GetPivot() * CFrame.new(0, 0, -2.5), Vector3.new(5, 5, 5), TreeParams)

	local Trees = {}

	for _, Part in Tree do
		local Tree = Part.Parent.Parent
		if Tree and Tree:IsA("Model") and Tree.Name:find("Tree") and not table.find(Trees, Tree) then
			table.insert(Trees, Tree)
		end
	end

	local Player = Players:GetPlayerFromCharacter(Character)

	for _, Tree in Trees do
	

		if Tree:GetAttribute("Broken") then
			continue
		end

		if not Tree:GetAttribute("Health") then
			local _, Size = Tree:GetBoundingBox()
			if not Tree:GetAttribute("MaxHealth") then
				ShakeObject(Tree)
				Tree:SetAttribute("MaxHealth", math.min(1, math.floor(Size.Y / 4)))
				Tree:SetAttribute("Health", Tree:GetAttribute("MaxHealth") - 1)
			end
		end

		if Tree:GetAttribute("Health") <= 0 then
			Tree:SetAttribute("Broken", true)
			ResourceService:BreakResource(Player, Tree)
		else
			ShakeObject(Tree)
			Tree:SetAttribute("Health", Tree:GetAttribute("Health") - 1)
		end
	end
end

return Axe
