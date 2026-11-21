return function(Source: string): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Signal(): any
		local S = { Listeners = {} }
		function S:Connect(Callback: (...any) -> ()): any
			local C = { Connected = true }
			function C.Disconnect(Current: any)
				Current.Connected = false
			end
			table.insert(self.Listeners, { Callback, C })
			return C
		end
		function S:Fire(...: any)
			for _, L in self.Listeners do
				if L[2].Connected then
					L[1](...)
				end
			end
		end
		return S
	end
	local function Object(Class: string, Children: { any }?): any
		local O = { Class = Class, Parent = true, Children = Children or {}, DescendantAdded = Signal() }
		function O:IsA(Name: string): boolean
			return self.Class == Name
		end
		function O:FindFirstChild(Name: string): any
			return self[Name]
		end
		function O:FindFirstChildWhichIsA(Name: string): any
			return self[Name]
		end
		function O:QueryDescendants(Name: string): { any }
			local R = {}
			for _, Child in self.Children do
				if Child:IsA(Name) then
					table.insert(R, Child)
				end
			end
			return R
		end
		return O
	end
	local Flame, Rain, OtherParticle = Object("ParticleEmitter"), Object("ParticleEmitter"), Object("ParticleEmitter")
	Flame.TimeScale, Rain.TimeScale, OtherParticle.TimeScale = 0.35, 1, 1
	local Ship = Object("Model", { Flame, Rain })
	local Track = { Speed = 1.5, IsPlaying = true }
	function Track:AdjustSpeed(Speed: number)
		self.Speed = Speed
	end
	local AlreadyStopped = { Speed = 0, IsPlaying = true, AdjustSpeed = Track.AdjustSpeed }
	local Animator = {
		AnimationPlayed = Signal(),
		GetPlayingAnimationTracks = function()
			return { Track, AlreadyStopped }
		end,
	}
	local Actor = Object("Model")
	Actor.Humanoid = Object("Humanoid")
	Actor.Humanoid.Animator = Animator
	local FireSound, Thunder, RainSound, CombatGroup, OtherSound =
		Object("Sound"), Object("Sound"), Object("Sound"), Object("SoundGroup"), Object("Sound")
	FireSound.Volume, Thunder.Volume, RainSound.Volume, CombatGroup.Volume, OtherSound.Volume = 0.15, 0.4, 0.6, 0.8, 0.9
	local Sounds = Object("SoundService")
	Sounds.IntroShipAmbience = Object("Folder", { FireSound })
	Sounds.IntroCutsceneThunder = Object("Folder", { Thunder })
	Sounds.CombatMusic = CombatGroup
	Sounds.SoundServicePackage = Object("Folder")
	Sounds.SoundServicePackage.Misc = Object("Folder")
	Sounds.SoundServicePackage.Misc.RainSound = RainSound
	local State = {}
	local Controllers = {
		IntroCutsceneController = {
			SetSwayPaused = function(_: any, Paused: boolean)
				State.SwayPaused = Paused
			end,
		},
		LightningController = {
			SetStormPaused = function(_: any, Name: string, Paused: boolean)
				assert(Name == "IntroCutscene", "Only the owner's intro storm can pause")
				State.LightningPaused = Paused
			end,
		},
	}
	local Knit = {
		CreateController = function(Definition: any): any
			return Definition
		end,
		GetController = function(Name: string): any
			return Controllers[Name]
		end,
	}
	local Tweens = {
		Create = function(_: any, Target: any, _: any, Goals: any): any
			return {
				Play = function()
					for Name, Value in Goals do
						Target[Name] = Value
					end
				end,
				Cancel = function() end,
			}
		end,
	}
	local Env = setmetatable({
		game = {
			GetService = function(_: any, Name: string): any
				if Name == "SoundService" then
					return Sounds
				elseif Name == "TweenService" then
					return Tweens
				end
				return { Packages = { Knit = "Knit" }, Shared = { IntroCutsceneConfig = "Config" } }
			end,
		},
		require = function(Name: string): any
			return if Name == "Knit" then Knit else { CombatTutorial = { AmbienceVolume = 0.2 } }
		end,
		TweenInfo = {
			new = function()
				return {}
			end,
		},
	}, { __index = getfenv() })
	local Chunk = assert(loadstring(Source))
	setfenv(Chunk, Env)
	local Controller = Chunk()
	Controller.KnitInit()
	Controller:Pause(Ship, { Actor })
	Check(Flame.TimeScale == 0 and Rain.TimeScale == 0 and OtherParticle.TimeScale == 1, "Only scene particles freeze")
	Check(Track.Speed == 0 and AlreadyStopped.Speed == 0, "Active animations freeze without unfreezing stopped tracks")
	Check(State.SwayPaused and State.LightningPaused, "Boat sway and new local lightning pause")
	Check(
		math.abs(FireSound.Volume - 0.03) < 0.0001 and math.abs(CombatGroup.Volume - 0.16) < 0.0001,
		"Owned ambience and combat audio lower"
	)
	Check(OtherSound.Volume == 0.9, "Unrelated sound is untouched")
	local NewEmitter, NewTrack =
		Object("ParticleEmitter"), { Speed = 2.25, IsPlaying = true, AdjustSpeed = Track.AdjustSpeed }
	NewEmitter.TimeScale = 0.7
	Ship.DescendantAdded:Fire(NewEmitter)
	Animator.AnimationPlayed:Fire(NewTrack)
	Check(NewEmitter.TimeScale == 0 and NewTrack.Speed == 0, "Effects and tracks created during the pause also freeze")
	Controller:Resume()
	Check(
		Flame.TimeScale == 0.35 and Rain.TimeScale == 1 and NewEmitter.TimeScale == 0.7,
		"Emitter speeds restore exactly"
	)
	Check(
		Track.Speed == 1.5 and AlreadyStopped.Speed == 0 and NewTrack.Speed == 2.25,
		"Animation speeds restore exactly"
	)
	Check(
		FireSound.Volume == 0.15 and Thunder.Volume == 0.4 and RainSound.Volume == 0.6 and CombatGroup.Volume == 0.8,
		"Audio volumes restore exactly"
	)
	Check(not State.SwayPaused and not State.LightningPaused, "Sway and lightning resume")
	local After = Object("ParticleEmitter")
	After.TimeScale = 1
	Ship.DescendantAdded:Fire(After)
	Check(After.TimeScale == 1, "Pause listeners disconnect after resume")
	Controller:Pause(Ship, { Actor })
	Controller:Pause(Ship, { Actor })
	Controller:Resume()
	Check(
		Flame.TimeScale == 0.35 and Track.Speed == 1.5 and CombatGroup.Volume == 0.8,
		"Repeated pause restores the original values"
	)
	Controller:Pause(Ship, { Actor })
	Flame.Parent = nil
	Track.IsPlaying = false
	Controller:Resume()
	Check(Rain.TimeScale == 1 and not State.SwayPaused, "Destroyed effects and stopped tracks do not block cleanup")
	return string.format("IntroScenePause: %d checks passed", Checks)
end
