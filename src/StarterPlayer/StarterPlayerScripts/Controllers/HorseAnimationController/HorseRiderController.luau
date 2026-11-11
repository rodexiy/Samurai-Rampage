local HorseRiderController = {}

export type State = {
	Joint: Weld?,
	Rest: CFrame?,
}

function HorseRiderController.Create(): State
	return {}
end

function HorseRiderController.Reset(State: State)
	if State.Joint and State.Joint.Parent and State.Rest then
		State.Joint.C0 = State.Rest
	end
	State.Joint = nil
	State.Rest = nil
end

function HorseRiderController.Update(State: State, Model: Model, BodyMotion: CFrame)
	local Root = Model.PrimaryPart
	local Joint = Root and Root:FindFirstChild("RiderWeld")
	if typeof(Model:GetAttribute("RiderUserId")) ~= "number" or not Root or not Joint or not Joint:IsA("Weld")
		or Joint.Part0 ~= Root or not Joint.Part1 or not Joint.Part1:IsDescendantOf(workspace)
	then
		HorseRiderController.Reset(State)
		return
	end

	if State.Joint ~= Joint then
		HorseRiderController.Reset(State)
		State.Joint = Joint
		State.Rest = Joint.C0
	end
	if State.Rest then
		-- Apply the same root-space motion as the skinned body, including saddle pitch.
		Joint.C0 = BodyMotion * State.Rest
	end
end

return HorseRiderController
