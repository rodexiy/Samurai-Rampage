local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)

local BowRaycast = {}

function BowRaycast.GetCharacter(Part: Instance): Model?
	local Current: Instance? = Part
	while Current and Current ~= workspace do
		if Current:IsA("Model") and Current:FindFirstChildWhichIsA("Humanoid") then
			return Current
		end
		Current = Current.Parent
	end

	return nil
end

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

function BowRaycast.CanPierce(Cast: any, Result: RaycastResult, _Velocity: Vector3): boolean
	local Data = Cast.UserData
	if Data and (Data.Harmless or Data.ProtectedCharacters) then
		local Character = BowRaycast.GetCharacter(Result.Instance)
		if Character then
			local Player = Players:GetPlayerFromCharacter(Character)
			if Data.Harmless or (Data.ProtectedCharacters and table.find(Data.ProtectedCharacters, Character))
				or (Player and Data.ProtectedPlayers and table.find(Data.ProtectedPlayers, Player)) then
				return true
			end
		end
	end
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
