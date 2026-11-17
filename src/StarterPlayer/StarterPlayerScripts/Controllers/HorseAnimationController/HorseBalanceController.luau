local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local Settings = HorseConfig.Animation.Balance
local MinimumNormal = math.cos(HorseConfig.Grounding.MaximumSupportSlope)
local HorseBalanceController = {}

export type Sample = { Rest: Vector3, Hit: RaycastResult?, Frame: CFrame?, Clearance: number? }
type Contact = { Point: Vector3, Normal: Vector3, Support: BasePart?, Time: number }
export type State = {
	Contacts: { [number]: Contact },
	Time: number,
	Active: boolean,
	Offset: number,
	Velocity: number,
}

function HorseBalanceController.Create(): State
	return { Contacts = {}, Time = 0, Active = false, Offset = 0, Velocity = 0 }
end

function HorseBalanceController.Reset(State: State)
	table.clear(State.Contacts)
	State.Time = 0
	State.Active = false
	State.Offset = 0
	State.Velocity = 0
end

local function Observe(State: State, Index: number, Sample: Sample): boolean
	local Hit = Sample.Hit
	if not Hit or not Hit.Instance:IsDescendantOf(workspace) then
		return false
	end

	local Support = if Hit.Instance:IsA("BasePart") and not Hit.Instance:IsA("Terrain") then Hit.Instance else nil
	local Point, Normal = Hit.Position, Hit.Normal
	if Support then
		local Frame = Sample.Frame or Support.CFrame
		Point = Frame:PointToObjectSpace(Point)
		Normal = Frame:VectorToObjectSpace(Normal)
	end
	State.Contacts[Index] = { Point = Point, Normal = Normal, Support = Support, Time = State.Time }

	return true
end

local function GetTarget(State: State, Frame: CFrame, Scale: number, Samples: { Sample }): number
	local LiveContacts = 0
	for Index, Sample in Samples do
		if Observe(State, Index, Sample) then
			LiveContacts += 1
		end
	end
	if LiveContacts == 0 then
		-- Contact memory only bridges partial probe failures, never actual loss of all support.
		table.clear(State.Contacts)
		State.Active = false
		return 0
	end

	local Lowest, Highest = math.huge, -math.huge
	local Count = 0
	for Index, Sample in Samples do
		local Contact = State.Contacts[Index]
		if not Contact or State.Time - Contact.Time > Settings.ContactGrace then
			State.Contacts[Index] = nil
			continue
		end
		local Point, Normal = Contact.Point, Contact.Normal
		if Contact.Support then
			if not Contact.Support:IsDescendantOf(workspace) then
				State.Contacts[Index] = nil
				continue
			end
			Point = Contact.Support.CFrame:PointToWorldSpace(Point)
			Normal = Contact.Support.CFrame:VectorToWorldSpace(Normal)
		end

		local Rest = Frame:PointToWorldSpace(Sample.Rest)
		local Height = Point.Y - ((Rest.X - Point.X) * Normal.X + (Rest.Z - Point.Z) * Normal.Z)
			/ math.max(Normal.Y, MinimumNormal)
		Height += (Sample.Clearance or 0) / math.max(Normal.Y, MinimumNormal)
		local Offset = (Height - Rest.Y) * Frame.UpVector.Y
		Lowest = math.min(Lowest, Offset)
		Highest = math.max(Highest, Offset)
		Count += 1
	end

	local Range = if Count >= 2 then Highest - Lowest else 0
	local Release = Settings.ReleaseTolerance * Scale
	local Engage = Settings.HeightTolerance * Scale
	State.Active = Range > (if State.Active then Release else Engage)
	if not State.Active then
		return 0
	end

	local Weight = math.clamp((Range - Release) / Engage, 0, 1)

	return math.clamp(Lowest, -Settings.MaximumBodyDrop * Scale, 0) * Weight
end

function HorseBalanceController.Update(State: State, Frame: CFrame, Scale: number, DeltaTime: number, Samples: { Sample }): number
	DeltaTime = math.max(DeltaTime, 0)
	State.Time += DeltaTime
	local Target = GetTarget(State, Frame, Scale, Samples)
	local Omega = math.pi * 2 * Settings.Frequency
	local Offset = State.Offset - Target
	local Step = (State.Velocity + Omega * Offset) * DeltaTime
	local Decay = math.exp(-Omega * DeltaTime)
	-- Exact critically damped PD response: body and legs consume the same continuous state.
	State.Offset = math.clamp(Target + (Offset + Step) * Decay, -Settings.MaximumBodyDrop * Scale, 0)
	State.Velocity = (State.Velocity - Omega * Step) * Decay
	if Target == 0 and math.abs(State.Offset) < 0.001 * Scale and math.abs(State.Velocity) < 0.01 * Scale then
		State.Offset = 0
		State.Velocity = 0
	end

	return State.Offset
end

return HorseBalanceController
