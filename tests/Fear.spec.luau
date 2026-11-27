return function(Sources: { [string]: string }): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Signal(): any
		local Callbacks = {}
		local Event = {
			Connect = function(_Self: any, Callback: (...any) -> ())
				table.insert(Callbacks, Callback)
			end,
			Fire = function(_Self: any, ...: any)
				for _, Callback in Callbacks do
					Callback(...)
				end
			end,
		}

		function Event:Once(Callback: (...any) -> ())
			local Fired = false
			self:Connect(function(...: any)
				if not Fired then
					Fired = true
					Callback(...)
				end
			end)
		end

		return Event
	end

	local Attributes = {}
	local Player = {
		Name = "Samurai",
		IsA = function(_Self: any, Name: string): boolean return Name == "Player" end,
		CharacterAdded = Signal(),
		CharacterRemoving = Signal(),
		SetAttribute = function(_Self: any, Name: string, Value: any) Attributes[Name] = Value end,
		GetAttribute = function(_Self: any, Name: string): any return Attributes[Name] end,
	}
	local Players = {
		LocalPlayer = Player,
		PlayerAdded = Signal(),
		PlayerRemoving = Signal(),
		GetPlayers = function(): { any } return { Player } end,
	}
	Player.Parent = Players

	local Now = 0
	local Jobs = {}
	local Task = {
		delay = function(Delay: number, Callback: () -> ()): any
			local Job = { At = Now + Delay, Callback = Callback }
			table.insert(Jobs, Job)
			return Job
		end,
		cancel = function(Job: any) Job.Cancelled = true end,
	}
	local function Advance(Seconds: number)
		local Target = Now + Seconds
		repeat
			local NextJob
			for _, Job in Jobs do
				if not Job.Cancelled and not Job.Done and Job.At <= Target
					and (not NextJob or Job.At < NextJob.At) then
					NextJob = Job
				end
			end
			if not NextJob then
				break
			end

			Now = NextJob.At
			NextJob.Done = true
			NextJob.Callback()
		until false
		Now = Target
	end

	local Knit = {
		CreateService = function(Service: any): any return Service end,
		CreateController = function(Controller: any): any return Controller end,
		CreateSignal = Signal,
	}
	local ReplicatedStorage = { Packages = { Knit = Knit } }
	local Environment = setmetatable({
		game = { GetService = function(_Self: any, Name: string): any
			return if Name == "Players" then Players else ReplicatedStorage
		end },
		require = function(Module: any): any return Module end,
		task = Task,
	}, { __index = getfenv() })
	local function Load(Source: string, Env: any): any
		local Chunk = assert(loadstring(Source))
		setfenv(Chunk, Env)
		return Chunk()
	end

	local Service = Load(Sources.Service, Environment)
	local Updates = {}
	Service.Client.FearChanged:Connect(function(Target: any, Level: number)
		table.insert(Updates, { Player = Target, Level = Level })
	end)
	Service.KnitStart()
	Check(Service:GetFear(Player) == 0 and Attributes.Fear == 0, "New players start without fear")
	Service:SetFear(Player, 100)
	Advance(0.99)
	Check(Service:GetFear(Player) == 100, "Fear does not decay early")
	Advance(0.01)
	Check(Service:GetFear(Player) == 98 and Attributes.Fear == 98, "Fear decays by two each second")
	Service:AddFear(Player, 50)
	Check(Service:GetFear(Player) == 100, "Fear accumulation caps at 100")
	Service:SetFear(Player, 3)
	Advance(2)
	Check(Service:GetFear(Player) == 0, "Decay clamps at zero")
	local Count = #Updates
	Advance(10)
	Check(#Updates == Count, "No decay or networking remains at zero")
	Service:SetFear(Player, -10)
	Check(Service:GetFear(Player) == 0, "Negative fear clamps to zero")
	Check(not pcall(function()
		Service:SetFear(Player, 0 / 0)
	end), "NaN is rejected")
	Check(not pcall(function()
		Service:SetFear(Player, math.huge)
	end), "Infinity is rejected")
	Service:SetFear(Player, 99)
	Player.CharacterRemoving:Fire({})
	Advance(1)
	Check(Service:GetFear(Player) == 0, "Removing a character cancels decay and resets fear")
	Service:SetFear(Player, 90)
	Player.CharacterAdded:Fire({})
	Check(Service:GetFear(Player) == 0, "Respawning starts without fear")
	Service:SetFear(Player, 90)
	Players.PlayerRemoving:Fire(Player)
	Count = #Updates
	Advance(3)
	Check(Service:GetFear(Player) == 0 and #Updates == Count, "Leaving removes state and cancels timers")
	Players.PlayerAdded:Fire(Player)

	Knit.GetService = function(): any
		return Service
	end
	local Command = Load(Sources.Command, Environment)
	Command({ Executor = Player }, 95)
	Check(Service:GetFear(Player) == 95, "Admin command defaults to the executor")
	Command({ Executor = Player }, 25, { Player })
	Check(Service:GetFear(Player) == 25, "Admin command supports selected players")
	for _, Invalid in { -1, 101, math.huge, 0 / 0 } do
		Command({ Executor = Player }, Invalid)
		Check(Service:GetFear(Player) == 25, "Invalid command levels do not mutate state")
	end

	local CameraChanged = Signal()
	local Workspace = {
		CurrentCamera = {},
		GetPropertyChangedSignal = function(): any return CameraChanged end,
	}
	local Shake = 0
	Knit.GetController = function(): any
		return { SetFearShake = function(_Self: any, Strength: number)
			Shake = Strength
		end }
	end
	local Corrections = {}
	local Pulses = {}
	local TweenService = {
		Create = function(_Self: any, Target: any, Info: any, Goals: any): any
			local Tween = {
				Completed = Signal(),
				Cancel = function(Self: any)
					Self.Cancelled = true
				end,
				Play = function(Self: any)
					Check(not Target.Destroyed, "Transitions only target living effects")
					for Property, Value in Goals do
						Target[Property] = Value
					end
					if Info.RepeatCount ~= -1 then
						Self.Completed:Fire("Completed")
					end
				end,
			}
			if Info.RepeatCount == -1 then
				table.insert(Pulses, Tween)
				Check(Info.Time == 0.2 and Info.Reverses, "Brightness smoothly reverses every 0.2 seconds")
			end

			return Tween
		end,
	}
	Environment.game = { GetService = function(_Self: any, Name: string): any
		return if Name == "Players" then Players elseif Name == "TweenService" then TweenService else ReplicatedStorage
	end }
	Environment.workspace = Workspace
	Environment.Instance = { new = function(): any
		local Correction = { Destroy = function(Self: any)
			Self.Destroyed = true
		end }
		table.insert(Corrections, Correction)
		return Correction
	end }
	Environment.TweenInfo = { new = function(Time: number, _Style: any, _Direction: any, RepeatCount: number?, Reverses: boolean?): any
		return { Time = Time, RepeatCount = RepeatCount, Reverses = Reverses }
	end }
	Environment.Enum = {
		EasingStyle = { Sine = {} },
		EasingDirection = { InOut = {} },
		PlaybackState = { Completed = "Completed" },
	}
	-- The client proxy omits the target player from server-to-client signal arguments.
	local Remote = Signal()
	Knit.GetService = function(): any
		return { FearChanged = Remote }
	end
	local Controller = Load(Sources.Controller, Environment)
	Controller.KnitInit()
	Controller.KnitStart()
	local Correction = Corrections[#Corrections]
	Check(Correction.Brightness < 0 and Correction.Parent == Workspace.CurrentCamera, "Client hydrates existing fear")
	Remote:Fire(0)
	Check(Correction.Brightness == 0 and Correction.Saturation == 0 and Shake == 0, "No effects at zero")
	Remote:Fire(1)
	Check(Correction.Brightness < -0.01 and Shake == 0, "Darkening is noticeable even at low fear")
	local InitialDarkness = Correction.Brightness
	Remote:Fire(25)
	Check(Correction.Brightness < -0.12 and Correction.Brightness > -0.2 and Shake == 0,
		"Early darkening is stronger while shaking remains inactive at 25")
	Remote:Fire(26)
	Check(Shake > 0 and Shake < 0.1, "Slight shaking above 25")
	Remote:Fire(50)
	Check(Correction.Brightness < InitialDarkness and Shake == 0.5, "Maximum darkness and half shaking at 50")
	local MaximumDarkness = Correction.Brightness
	Remote:Fire(75)
	Check(Shake == 1 and Correction.Saturation == 0 and Correction.Brightness == MaximumDarkness,
		"Shaking reaches maximum at 75 while darkness stays capped")
	Remote:Fire(79)
	Check(Correction.Saturation == 0 and #Pulses == 0, "Saturation is preserved below 80")
	Remote:Fire(80)
	Check(Correction.Saturation == -1 and #Pulses == 0 and Correction.Brightness == MaximumDarkness,
		"Desaturation begins at 80 without brightness oscillation")
	Remote:Fire(90)
	Check(Correction.Saturation == -1 and #Pulses == 0, "Desaturation stays active without brightness oscillation at 90")
	Remote:Fire(91)
	Check(Correction.Saturation == -1, "Saturation stays at minus one above 90")
	Check(#Pulses == 1 and Correction.Brightness == 0.1, "Fear above 90 starts a brightness pulse")
	Remote:Fire(95)
	Check(#Pulses == 1 and not Pulses[1].Cancelled, "Fear updates preserve the running pulse")
	Correction:Destroy()
	Workspace.CurrentCamera = {}
	CameraChanged:Fire()
	Check(Corrections[#Corrections] ~= Correction and Corrections[#Corrections].Saturation == -1,
		"Camera replacement recreates the effect and preserves fear")
	Check(Pulses[1].Cancelled and #Pulses == 2, "Camera replacement cancels the old pulse and starts a new one")
	Remote:Fire(90)
	Check(Pulses[2].Cancelled and Corrections[#Corrections].Brightness == MaximumDarkness
		and Corrections[#Corrections].Saturation == -1,
		"Dropping to 90 stops brightness oscillation while keeping desaturation")
	Remote:Fire(0)
	Correction = Corrections[#Corrections]
	Check(Correction.Brightness == 0 and Correction.Saturation == 0 and Shake == 0, "All effects clear at zero")

	return string.format("Fear: %d checks passed", Checks)
end
