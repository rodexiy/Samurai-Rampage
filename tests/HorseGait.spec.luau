return function(Gait: any, Steering: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Settings = Config.Gaits
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	for _, FPS in { 30, 60, 120 } do
		local State = Gait.Create()
		Check(State.Multiplier == Settings.TrotMultiplier, "Start in trot")
		Gait.SetHeld(State, true, 0)
		for Frame = 1, FPS * 2 do
			Gait.SetHeld(State, true, Frame / FPS)
			Gait.Update(State, 1 / FPS, Frame / FPS, true)
		end
		Check(State.Boost == 0 and math.abs(State.Multiplier - Settings.GallopMultiplier) < 0.001,
			"Holding Shift reaches gallop without generating repeated taps")
		State = Gait.Create()
		for Frame = 0, FPS * 3 do
			local Time = Frame / FPS
			local Held = Time % 0.3 < 0.1
			Gait.SetHeld(State, Held, Time)
			Gait.Update(State, 1 / FPS, Time, true)
		end
		Gait.SetHeld(State, false, 3)
		Check(State.Boost > 0.99 and State.Multiplier > 0.99, "Repeated presses build up to running at " .. FPS .. " FPS")
		local Previous = State.Multiplier
		for Frame = 1, FPS * 5 do
			local Value = Gait.Update(State, 1 / FPS, 3 + Frame / FPS, true)
			Check(Value <= Previous + 0.0001 and Previous - Value <= Settings.TransitionDown / FPS + 0.0001,
				"Returning to trot is gradual and never accelerates without input")
			Previous = Value
			if Frame == FPS / 2 then
				Check(Value > Settings.GallopMultiplier, "Stopping the taps preserves momentum briefly")
			end
		end
		Check(math.abs(State.Multiplier - Settings.TrotMultiplier) < 0.001 and State.Boost == 0,
			"No new presses eventually return to trot")
	end

	local State = Gait.Create()
	Gait.SetHeld(State, true, 0)
	Gait.SetHeld(State, false, 0.01)
	Gait.SetHeld(State, true, 0.02)
	Check(State.Boost == 0, "Ignore unrealistically fast duplicate presses")
	for Frame = 1, 120 do
		Gait.SetHeld(State, Frame % 10 < 5, Frame / 60)
		Gait.Update(State, 1 / 60, Frame / 60, false)
	end
	Check(State.Boost == 0 and State.Multiplier == Settings.TrotMultiplier, "Standing still cannot bank running boosts")
	Gait.Cancel(State)
	Check(not State.Held and State.Boost == 0, "Losing focus releases the gait control")

	for _, Stats in Config.Tiers do
		local Motion = Steering.Create(CFrame.identity, Vector3.zero)
		for _, Multiplier in { Settings.TrotMultiplier, Settings.GallopMultiplier, 1 } do
			for _ = 1, 180 do
				local Frame = CFrame.lookAt(Vector3.zero, Motion.Heading)
				Steering.Update(Motion, Frame, Frame.LookVector * Motion.Speed, -Vector3.zAxis,
					Stats, 1 / 60, true, Vector3.zero, Multiplier)
			end
			Check(math.abs(Motion.Speed - Stats.Speed * Multiplier) < 0.01, "Each tier reaches the selected gait speed")
		end
		local Before = Motion.Speed
		Steering.Update(Motion, CFrame.identity, -Vector3.zAxis * Before, -Vector3.zAxis,
			Stats, 1 / 60, true, Vector3.zero, Settings.TrotMultiplier)
		Check(Motion.Speed > Stats.Speed * Settings.TrotMultiplier and Motion.Speed < Before,
			"Changing the gait cannot instantly clamp the physical speed")
	end

	return string.format("HorseGait: %d checks passed", Checks)
end
