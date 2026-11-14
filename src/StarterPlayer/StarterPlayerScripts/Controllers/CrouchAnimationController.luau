local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrouchConfig = require(ReplicatedStorage.Shared.CrouchConfig)

local CrouchAnimationController = {}

export type State = {
	Character: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Animator: Animator,
	Idle: AnimationTrack,
	Walk: AnimationTrack,
	Assets: { Animation },
	Current: AnimationTrack?,
	Speed: number,
	Destroyed: boolean,
}

local function LoadTrack(Animator: Animator, Name: string, Id: string): (AnimationTrack, Animation)
	local Asset = Instance.new("Animation")
	Asset.Name = "Crouch" .. Name
	Asset.AnimationId = Id

	local Track = Animator:LoadAnimation(Asset)
	Track.Name = Asset.Name
	Track.Priority = CrouchConfig.AnimationPriority
	Track.Looped = true

	return Track, Asset
end

function CrouchAnimationController.Create(Character: Model): State?
	local Root = Character.PrimaryPart
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	local Animator = Humanoid and Humanoid:FindFirstChildWhichIsA("Animator")
	if not Root or not Humanoid or not Animator or not Character:IsDescendantOf(workspace) then
		return nil
	end

	local Idle, IdleAsset = LoadTrack(Animator, "Idle", CrouchConfig.Animations.Idle)
	local Walk, WalkAsset = LoadTrack(Animator, "Walk", CrouchConfig.Animations.Walk)

	return {
		Character = Character, Root = Root, Humanoid = Humanoid, Animator = Animator,
		Idle = Idle, Walk = Walk, Assets = {IdleAsset, WalkAsset},
		Speed = (Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude, Destroyed = false,
	}
end

function CrouchAnimationController.Reset(State: State, Fade: number?)
	if State.Destroyed then
		return
	end

	if State.Current or Fade == 0 then
		State.Idle:Stop(Fade or CrouchConfig.FadeTime)
		State.Walk:Stop(Fade or CrouchConfig.FadeTime)
	end
	State.Current = nil
end

function CrouchAnimationController.Destroy(State: State)
	if State.Destroyed then
		return
	end

	CrouchAnimationController.Reset(State, 0)
	State.Idle:Destroy()
	State.Walk:Destroy()
	for _, Asset in State.Assets do
		Asset:Destroy()
	end
	State.Destroyed = true
end

function CrouchAnimationController.Update(State: State, Speed: number?)
	if State.Destroyed then
		return
	end
	if Speed then
		State.Speed = math.max(0, Speed)
	end
	if not CrouchConfig.CanCrouch(State.Character) then
		CrouchAnimationController.Reset(State, 0)
		return
	end
	if State.Character:GetAttribute("Crouching") ~= true then
		CrouchAnimationController.Reset(State)
		return
	end

	local Moving = State.Speed > CrouchConfig.MoveThreshold
	local Track = if Moving then State.Walk else State.Idle
	local PlaybackSpeed = if Moving then math.clamp(State.Speed / CrouchConfig.WalkSpeed, 0.1, 2) else 1
	if State.Current ~= Track then
		if State.Current then
			State.Current:Stop(CrouchConfig.FadeTime)
		end
		Track:Play(CrouchConfig.FadeTime, 1, PlaybackSpeed)
		State.Current = Track
	elseif math.abs(Track.Speed - PlaybackSpeed) > 0.01 then
		Track:AdjustSpeed(PlaybackSpeed)
	end
end

return CrouchAnimationController
