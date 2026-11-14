-- CreateHarness loads the production reload functions with a controlled clock and animation tracks.
return function(CreateHarness: (any) -> any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Signal(): any
		local Event = {Connections = {}}
		function Event:Connect(Callback: () -> ()): any
			local Connection = {Connected = true, Callback = Callback}
			function Connection.Disconnect(Target: any)
				Target.Connected = false
			end
			table.insert(self.Connections, Connection)
			return Connection
		end
		function Event:Once(Callback: () -> ()): any
			local Connection
			Connection = self:Connect(function()
				Connection:Disconnect()
				Callback()
			end)
			return Connection
		end
		function Event:Fire()
			for _, Connection in table.clone(self.Connections) do
				if Connection.Connected then
					Connection.Callback()
				end
			end
		end
		return Event
	end

	local function Setup(Seconds: number, Length: number?): any
		local Context = {Now = 100, ReadyAt = 100 + Seconds, Delays = {}}
		local function Track(): any
			local Value = {Length = Length or 6, TimePosition = 0, IsPlaying = false, Speed = 1, Ended = Signal(), LengthChanged = Signal()}
			function Value:Stop()
				self.IsPlaying = false
			end
			function Value:Play()
				self.IsPlaying = true
				self.TimePosition = 0
			end
			function Value:AdjustSpeed(Speed: number)
				self.Speed = Speed
			end
			function Value:GetPropertyChangedSignal(): any
				return self.LengthChanged
			end
			return Value
		end
		Context.Tracks = {Reload = Track(), Shot = Track(), Hold = Track()}
		Context.Character = {Parent = true, GetAttribute = function(_Self: any, Name: string): any
			return Name == "BowEquipped"
		end}
		Context.Harness = CreateHarness(Context)
		return Context
	end

	for _, Seconds in {0.25, 2, 7, 15} do
		local Context = Setup(Seconds)
		local Reload = Context.Tracks.Reload
		Context.Harness.Schedule(Context.Tracks.Shot)
		Check(Reload.IsPlaying and math.abs(Reload.Length / Reload.Speed - Seconds) < 0.001, "Reload speed must fit the remaining server cooldown")
	end

	local Context = Setup(7)
	local Reload = Context.Tracks.Reload
	Context.Tracks.Shot.IsPlaying = true
	Context.Harness.Schedule(Context.Tracks.Shot)
	Check(not Reload.IsPlaying, "Reload must wait for the shot animation to end")
	Context.Now = 101
	Context.Tracks.Shot.IsPlaying = false
	Context.Tracks.Shot.Ended:Fire()
	Check(Reload.IsPlaying and math.abs(Reload.Speed - 1) < 0.001, "The shot animation's elapsed time must be deducted from reload duration")
	Reload.TimePosition = 2
	Context.Now = 103
	Context.Harness.Deadline(105)
	Check(math.abs(Reload.Speed - 2) < 0.001, "Shortening an active cooldown must speed up the remaining animation")
	Context.Harness.Deadline(111)
	Check(math.abs(Reload.Speed - 0.5) < 0.001, "Extending an active cooldown must slow the remaining animation")
	Context.Now = 107
	for _, Delay in table.clone(Context.Delays) do
		Delay.Callback()
	end
	Check(Reload.IsPlaying, "Obsolete timers must not stop a reload whose deadline was extended")
	Context.Now = 111
	for _, Delay in table.clone(Context.Delays) do
		Delay.Callback()
	end
	Check(not Reload.IsPlaying and not Context.Harness.Pending(), "The reload must stop when the authoritative cooldown ends")

	Context = Setup(0)
	Context.Harness.Schedule(Context.Tracks.Shot)
	Check(not Context.Tracks.Reload.IsPlaying and not Context.Harness.Pending(), "Zero cooldown must skip reload without leaving input blocked")
	Context = Setup(0.1)
	Context.Tracks.Shot.IsPlaying = true
	Context.Harness.Schedule(Context.Tracks.Shot)
	Context.Now = 101
	for _, Delay in table.clone(Context.Delays) do
		Delay.Callback()
	end
	Context.Tracks.Shot.Ended:Fire()
	Check(not Context.Tracks.Reload.IsPlaying and not Context.Harness.Pending(), "Cooldowns shorter than the shot animation must not start a late reload")

	Context = Setup(2, 0)
	Reload = Context.Tracks.Reload
	Context.Harness.Schedule(Context.Tracks.Shot)
	Reload.Length = 6
	Context.Now = 101
	Reload.LengthChanged:Fire()
	Check(math.abs(Reload.Speed - 6) < 0.001, "Animation assets that finish loading late must use the remaining cooldown")
	Context.Harness.Deadline(100)
	Check(not Reload.IsPlaying and not Context.Harness.Pending(), "Removing an active cooldown must stop reload immediately")

	return tostring(Checks) .. " Tanegashima reload timing checks passed"
end
