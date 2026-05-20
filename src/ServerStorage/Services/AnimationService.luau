local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local AnimationService = Knit.CreateService({
	Name = "AnimationService",
	Client = {
		PlayAnimation = Knit.CreateSignal(),
		StopAnimation = Knit.CreateSignal(),
		PlayRandomAnimation = Knit.CreateSignal(),
		StopAttackAnimations = Knit.CreateSignal(),
		PlayFolderAnimation = Knit.CreateSignal(),
	},
})

function AnimationService:GetAnimator(Character: Model)
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

function AnimationService:GetAnimationFind(Character: Model, AnimationName: string)
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

function AnimationService:StopAnimationFind(Character: Model, AnimationName: string)
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

function AnimationService:StopAttackAnimations(Character: Model)
	AnimationService:StopAnimationFind(Character, "M2")
	AnimationService:StopAnimationFind(Character, "M1_")
end

function AnimationService:PlayRandomAnimationFromFolder(Character: Model, Folder: Folder)
	local Animator = self:GetAnimator(Character)
	if not Animator then
		return
	end

	local Animation = Folder:GetChildren()[math.random(1, #Folder:GetChildren())]
	local Track = Animator:LoadAnimation(Animation)
	Track.Name = Folder.Name .. "_" .. Animation.Name
	Track:Play()
end
function AnimationService:PlayAnimation(Character: Model, Animation: Animation): AnimationTrack
	local Animator = self:GetAnimator(Character)
	if not Animator then
		return
	end

	if type(Animation) == "string" then
		Animation = game.ReplicatedStorage.Assets.Animations:FindFirstChild(Animation, true)
	end

	if not Animation then
		return
	end

	local Track = Animator:LoadAnimation(Animation)
	Track:SetAttribute("Parent", Animator.Parent.Name)

	if Animation:GetAttribute("Priority") then
		Track.Priority = Animation:GetAttribute("Priority")
	end

	for Name, Value in Animation:GetAttributes() do
		Track:SetAttribute(Name, Value)
	end

	Track:Play()

	return Track, Animation
end

return AnimationService
