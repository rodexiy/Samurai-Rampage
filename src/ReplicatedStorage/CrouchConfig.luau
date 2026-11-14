local CrouchConfig = {
	Key = Enum.KeyCode.C,
	WalkSpeed = 6,
	HeightDrop = 0.85,
	FadeTime = 0.15,
	MoveThreshold = 0.5,
	AnimationPriority = Enum.AnimationPriority.Action2,
	Animations = {
		Idle = "rbxassetid://99254308802301",
		Walk = "rbxassetid://83428367691067",
	},
	RequestInterval = 0.15,
	CancelAttributes = {
		"BeenHitted", "Ragdoll", "Died", "Downed", "Mounted", "InHorse",
		"Rolling", "Climbing", "WallRunning", "Vaulting", "Meditating",
		"Carried", "Carrying", "InCell", "InLabor", "PostureBreak",
		"HeavyDeflect", "BeenDeflected", "Attack", "Attacking",
		"SkillLockMovement", "UsingSkillCantAttack", "CameraCutscene", "RealmTeleporting",
	},
}

function CrouchConfig.CanCrouch(Character: Model): boolean
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if not Character.Parent or not Character.PrimaryPart or not Humanoid or Humanoid.Health <= 0
		or Humanoid.RigType ~= Enum.HumanoidRigType.R6 or Humanoid.Sit or Humanoid.PlatformStand
		or Character:GetAttribute("Loaded") ~= true then
		return false
	end

	for _, Attribute in CrouchConfig.CancelAttributes do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end

	local State = Humanoid:GetState()
	return State ~= Enum.HumanoidStateType.Swimming and State ~= Enum.HumanoidStateType.Climbing
		and State ~= Enum.HumanoidStateType.Jumping and State ~= Enum.HumanoidStateType.Freefall
		and State ~= Enum.HumanoidStateType.Physics and State ~= Enum.HumanoidStateType.Dead
end

return CrouchConfig
