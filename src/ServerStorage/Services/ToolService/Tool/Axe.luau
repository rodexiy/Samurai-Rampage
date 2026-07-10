local Axe = {}

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

local TreeParams = OverlapParams.new()
TreeParams.FilterType = Enum.RaycastFilterType.Whitelist

local TREE_MAX_HEALTH = 5

local function GetTreesFolder(): Folder?
	local Map = workspace:FindFirstChild("Map")
	local Vegetation = Map and Map:FindFirstChild("Vegetation")
	local TreesFolder = Vegetation and Vegetation:FindFirstChild("Trees")
	if TreesFolder and TreesFolder:IsA("Folder") then
		return TreesFolder
	end

	return nil
end

local function GetTreeFilterInstances(TreesFolder: Folder): { Instance }
	local FilterInstances = { TreesFolder }

	for _, TaggedTree in CollectionService:GetTagged("Tree") do
		table.insert(FilterInstances, TaggedTree)
	end

	return FilterInstances
end

local function GetTreeFromPart(Part: BasePart, TreesFolder: Folder): Model?
	local Current = Part.Parent
	while Current and Current ~= TreesFolder do
		if Current:IsA("Model") and (Current.Parent == TreesFolder or CollectionService:HasTag(Current, "Tree")) then
			return Current
		end

		Current = Current.Parent
	end

	return nil
end

function Axe.Activated(Character: Model, Data: { any })
	local TreesFolder = GetTreesFolder()
	if not TreesFolder then
		return
	end

	TreeParams.FilterDescendantsInstances = GetTreeFilterInstances(TreesFolder)

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


	DebounceService:AddDebounce(Character, "AxePick", 2)
	local Track = AnimationService:PlayAnimation(Character, AxeAnimation)
	Track.Priority = Enum.AnimationPriority.Action4

	local Player = game.Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end

	local TreeParts =
		workspace:GetPartBoundsInBox(Character:GetPivot() * CFrame.new(0, 0, -2.5), Vector3.new(5, 5, 5), TreeParams)

	local Trees = {}

	for _, Part in TreeParts do
		local Tree = GetTreeFromPart(Part, TreesFolder)
		if Tree and not table.find(Trees, Tree) then
			table.insert(Trees, Tree)
		end
	end

	local Player = Players:GetPlayerFromCharacter(Character)

	for _, Tree in Trees do
		if not RealmService:HasOwnership(Player, Tree) then
			continue
		end

		if Tree:GetAttribute("Broken") then
			continue
		end

		
		if not Tree:GetAttribute("Health") then
			Tree:SetAttribute("MaxHealth", TREE_MAX_HEALTH)
			Tree:SetAttribute("Health", TREE_MAX_HEALTH)
		end

		RenderService:RenderForAllPlayers("Resource", "Shake", { Character = Character, Resource = Tree })
		SoundEffectService:PlayRandomFromFolder("ChopTree", true, Tree)
		
		local Health = Tree:GetAttribute("Health") - 1
		Tree:SetAttribute("Health", Health)

		if Health <= 0 then

			Tree:SetAttribute("Broken", true)
			SoundEffectService:PlayRandomFromFolder("FallTree", true, Tree)
			ResourceService:BreakResource(Player, Tree)
		end
	end
end

return Axe
