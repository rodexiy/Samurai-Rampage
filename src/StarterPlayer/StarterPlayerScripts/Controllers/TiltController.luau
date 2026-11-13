local TiltController = {}

export type State = {
	Character: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Joint: Motor6D,
	Rest: CFrame,
	Tilt: CFrame,
}

function TiltController.Create(Character: Model): State?
	local Root = Character.PrimaryPart
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	local Joint = Root and Root:FindFirstChild("RootJoint")
	if not Root or not Humanoid or not Joint or not Joint:IsA("Motor6D") then
		return nil
	end

	return { Character = Character, Root = Root, Humanoid = Humanoid, Joint = Joint, Rest = Joint.C1, Tilt = CFrame.identity }
end

function TiltController.Reset(State: State)
	State.Tilt = CFrame.identity
	State.Joint.C1 = State.Rest
end

function TiltController.Update(State: State, Movement: Vector3, DeltaTime: number)
	local Character = State.Character
	if State.Humanoid.Health <= 0 or State.Humanoid:GetState() == Enum.HumanoidStateType.Seated then
		TiltController.Reset(State)
		return
	end

	for _, Attribute in { "Mounted", "InHorse", "Ragdoll", "Died", "Downed", "PostureBreak", "Meditating" } do
		if Character:GetAttribute(Attribute) then
			TiltController.Reset(State)
			return
		end
	end

	local Maximum = math.rad(if Character:GetAttribute("Climbing") then 15 else 10)
	local Direction = State.Root.CFrame:VectorToObjectSpace(Movement)
	local Target = CFrame.Angles(-Direction.Z * Maximum, -Direction.X * Maximum, 0)
	State.Tilt = State.Tilt:Lerp(Target, 1 - math.exp(-30 * math.max(DeltaTime, 0)))
	State.Joint.C1 = State.Rest * State.Tilt:Inverse()
end

return TiltController
