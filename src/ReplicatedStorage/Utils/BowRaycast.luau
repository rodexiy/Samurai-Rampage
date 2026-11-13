local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)

local BowRaycast = {}

function BowRaycast.GetExclusions(Character: Model?): { Instance }
	local Excluded: { Instance } = {}
	if Character then
		table.insert(Excluded, Character)

		local Player = Players:GetPlayerFromCharacter(Character)
		if Player and Character:GetAttribute("InHorse") == true then
			for _, Horse in CollectionService:GetTagged(HorseConfig.Tag) do
				if Horse:GetAttribute("RiderUserId") == Player.UserId then
					table.insert(Excluded, Horse)
					break
				end
			end
		end
	end

	local Effects = workspace:FindFirstChild("VFX")
	if Effects then
		table.insert(Excluded, Effects)
	end

	return Excluded
end

function BowRaycast.ShouldIgnore(Part: Instance): boolean
	if not Part:IsA("BasePart") or Part:IsA("Terrain") or Part.CanCollide then
		return false
	end

	local Ancestor = Part.Parent
	while Ancestor and Ancestor ~= workspace do
		if Ancestor:IsA("Model") and Ancestor:FindFirstChildWhichIsA("Humanoid") then
			return false
		end
		Ancestor = Ancestor.Parent
	end

	return true
end

function BowRaycast.CanPierce(_Cast: any, Result: RaycastResult, _Velocity: Vector3): boolean
	return BowRaycast.ShouldIgnore(Result.Instance)
end

function BowRaycast.Aim(Origin: Vector3, Direction: Vector3, Params: RaycastParams): RaycastResult?
	local Hit = workspace:Raycast(Origin, Direction, Params)
	if not Hit or not BowRaycast.ShouldIgnore(Hit.Instance) then
		return Hit
	end

	-- Temporarily extend the aim ray's exclusions without retaining plants between frames.
	local OriginalFilter = Params.FilterDescendantsInstances
	local Excluded = table.clone(OriginalFilter)
	repeat
		table.insert(Excluded, Hit.Instance)
		Params.FilterDescendantsInstances = Excluded
		Hit = workspace:Raycast(Origin, Direction, Params)
	until not Hit or not BowRaycast.ShouldIgnore(Hit.Instance)

	Params.FilterDescendantsInstances = OriginalFilter
	return Hit
end

return BowRaycast
