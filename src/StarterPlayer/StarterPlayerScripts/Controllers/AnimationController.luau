local Knit = require(game.ReplicatedStorage.Packages.Knit)

local AnimationController = Knit.CreateController({
	Name = "AnimationController",
})

function AnimationController:GetAnimator(Character: Model)
	local Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then
		return
	end

	local Animator = Humanoid:FindFirstChild("Animator")
	if not Animator then
		return
	end

	return Animator
end

function AnimationController:GetAnimationFind(Character: Model, AnimationName: string)
	local Animator = self:GetAnimator(Character)
	if not Animator then
		return
	end

	for _, track: AnimationTrack in Animator:GetPlayingAnimationTracks() do
		if track.Name:find(AnimationName) then
			return track
		end
	end
end

function AnimationController:StopAnimationFind(Character: Model, AnimationName: string)
	local Animator = self:GetAnimator(Character)
	if not Animator then
		return
	end

	for _, track: AnimationTrack in Animator:GetPlayingAnimationTracks() do
		if track.Name:find(AnimationName) then
			track:Stop()
		end
	end
end

local CombatAnimations = game.ReplicatedStorage.Assets.Animations.Combat
function AnimationController:GetCombatAnimationFolder(Character: Model)
	local WeaponType = Character:GetAttribute("WeaponType") or "Default"

	if CombatAnimations:FindFirstChild(WeaponType) == nil then
		WeaponType = "Default"
	end

	return CombatAnimations[WeaponType]
end

function AnimationController:StopAttackAnimations(Character: Model)
	self:StopAnimationFind(Character, "M2")
	self:StopAnimationFind(Character, "M1")
end

function AnimationController:PlayAnimation(Character: Model, Animation: Animation)
	local Animator = self:GetAnimator(Character)
	if not Animator then
		return
	end

	local Track: AnimationTrack = Animator:LoadAnimation(Animation)
	Track:SetAttribute("Parent", Animator.Parent.Name)

	if Animation:GetAttribute("Priority") then
		Track.Priority = Animation:GetAttribute("Priority")
	end

	for Name, Value in Animation:GetAttributes() do
		Track:SetAttribute(Name, Value)
	end

	Track:Play()

	return Track
end

return AnimationController
