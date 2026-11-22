-- Executes the production service with a deterministic clock and isolated characters.
return function(ProductionSource: string): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Signal(): any
		local Listeners = {}
		local Event = {}
		function Event:Connect(Callback: (...any) -> ()): any
			local Connection = { Connected = true, Callback = Callback }
			function Connection.Disconnect(Current: any)
				Current.Connected = false
			end

			table.insert(Listeners, Connection)
			return Connection
		end

		function Event:Fire(...: any)
			for _, Connection in table.clone(Listeners) do
				if Connection.Connected then
					Connection.Callback(...)
				end
			end
		end

		return Event
	end

	local function Object(): any
		local Attributes = {}
		local Signals = {}
		local Result = { Destroying = Signal(), AncestryChanged = Signal(), InWorkspace = true }
		function Result:GetAttribute(Name: string): any
			return Attributes[Name]
		end

		function Result:SetAttribute(Name: string, Value: any)
			if Attributes[Name] == Value then
				return
			end

			Attributes[Name] = Value
			if Signals[Name] then
				Signals[Name]:Fire()
			end
		end

		function Result:GetAttributeChangedSignal(Name: string): any
			Signals[Name] = Signals[Name] or Signal()
			return Signals[Name]
		end

		function Result:IsDescendantOf(_Ancestor: any): boolean
			return self.InWorkspace
		end

		function Result:FindFirstChildWhichIsA(_ClassName: string): any
			return self.Humanoid
		end

		return Result
	end

	local function Fixture(): any
		local Now = 0
		local Jobs = {}
		local Owners = {}
		local Knit = { CreateService = function(Service: any): any
			return Service
		end }
		local Players = {
			GetPlayerFromCharacter = function(_Self: any, Character: any): any
				return Owners[Character]
			end,
		}
		local Environment = setmetatable({
			game = { GetService = function(_Self: any, Name: string): any
				return if Name == "Players" then Players else { Packages = { Knit = Knit } }
			end },
			require = function(Module: any): any return Module end,
			workspace = { GetServerTimeNow = function(): number return Now end },
			task = { delay = function(Seconds: number, Callback: () -> ())
				table.insert(Jobs, { At = Now + Seconds, Callback = Callback })
			end },
		}, { __index = getfenv() })
		local Load = assert(loadstring(ProductionSource))
		setfenv(Load, Environment)

		local Result = { Service = Load() }
		function Result:Character(Owner: any?): any
			local Character = Object()
			Character.Humanoid = { Died = Signal() }
			if Owner then
				Owners[Character] = Owner
				Owner.Character = Character
			end

			return Character
		end

		function Result:Advance(Seconds: number)
			local Target = Now + Seconds
			while true do
				table.sort(Jobs, function(A: any, B: any): boolean
					return A.At < B.At
				end)
				if not Jobs[1] or Jobs[1].At > Target then
					break
				end

				local Job = table.remove(Jobs, 1)
				Now = Job.At
				Job.Callback()
			end

			Now = Target
		end

		Result.Player = Object()
		Result.Player.CharacterRemoving = Signal()
		Result.Victim = Result:Character(Result.Player)
		Result.Attacker = Result:Character()
		return Result
	end

	local function CheckCleared(F: any)
		Check(F.Player:GetAttribute("InCombat") == false, "Player must leave combat")
		Check(F.Victim:GetAttribute("InCombat") == false, "Character must leave combat")
		Check(F.Player:GetAttribute("InCombatEndTick") == nil, "Deadline must be cleared")
		Check(F.Service:GetInCombatWith(F.Victim) == nil, "Opponents must be cleared")
	end

	local F = Fixture()
	F.Service:SetInCombat(F.Victim, true, F.Attacker)
	Check(F.Player:GetAttribute("InCombat") == true, "Hit must enter combat")
	Check(F.Player:GetAttribute("InCombatEndTick") == 45, "Hit must set a 45-second deadline")
	F:Advance(44)
	Check(F.Player:GetAttribute("InCombat") == true, "Combat must persist before deadline")
	F:Advance(1)
	CheckCleared(F)

	F = Fixture()
	F.Service:SetInCombat(F.Victim, true, F.Attacker)
	F:Advance(30)
	F.Service:SetInCombat(F.Victim, true, F.Attacker)
	Check(F.Player:GetAttribute("InCombatEndTick") == 75, "A new hit must extend the deadline")
	F:Advance(15)
	Check(F.Player:GetAttribute("InCombat") == true, "Old deadline must not end renewed combat")
	F:Advance(30)
	CheckCleared(F)

	for _, Event in { "DiedAttribute", "HumanoidDied", "Destroyed", "Removed", "ExplicitReset", "CharacterRemoving" } do
		F = Fixture()
		F.Service:SetInCombat(F.Victim, true, F.Attacker)
		if Event == "DiedAttribute" then
			F.Victim:SetAttribute("Died", true)
		elseif Event == "HumanoidDied" then
			F.Victim.Humanoid.Died:Fire()
		elseif Event == "Destroyed" then
			F.Victim.Destroying:Fire()
		elseif Event == "Removed" then
			F.Victim.InWorkspace = false
			F.Victim.AncestryChanged:Fire()
		elseif Event == "ExplicitReset" then
			F.Service:SetInCombat(F.Victim, false)
		else
			F.Player.CharacterRemoving:Fire(F.Victim)
		end

		CheckCleared(F)
	end

	for _, Event in { "DiedAttribute", "HumanoidDied", "Destroyed", "Removed" } do
		F = Fixture()
		F.Service:SetInCombat(F.Victim, true, F.Attacker)
		if Event == "DiedAttribute" then
			F.Attacker:SetAttribute("Died", true)
		elseif Event == "HumanoidDied" then
			F.Attacker.Humanoid.Died:Fire()
		elseif Event == "Destroyed" then
			F.Attacker.Destroying:Fire()
		else
			F.Attacker.InWorkspace = false
			F.Attacker.AncestryChanged:Fire()
		end

		CheckCleared(F)
	end

	F = Fixture()
	local OtherAttacker = F:Character()
	F.Service:SetInCombat(F.Victim, true, F.Attacker)
	F.Service:SetInCombat(F.Victim, true, OtherAttacker)
	F.Attacker:SetAttribute("Died", true)
	Check(F.Player:GetAttribute("InCombat") == true, "One remaining opponent must retain combat")
	F.Service:SetInCombat(F.Victim, false, OtherAttacker)
	CheckCleared(F)

	F = Fixture()
	F.Service:SetInCombat(F.Victim, true, F.Attacker)
	F:Advance(10)
	F.Service:SetInCombat(F.Victim, false)
	local OldCharacter = F.Victim
	F.Victim = F:Character(F.Player)
	F.Service:SetInCombat(F.Victim, true, OtherAttacker)
	OldCharacter.Destroying:Fire()
	F.Attacker.Destroying:Fire()
	F.Player.CharacterRemoving:Fire(OldCharacter)
	F:Advance(35)
	Check(F.Player:GetAttribute("InCombat") == true, "Old timers and callbacks must not clear respawned combat")
	F:Advance(10)
	CheckCleared(F)

	F = Fixture()
	F.Service:SetInCombat(F.Victim, true, F.Attacker)
	F.Victim:SetAttribute("Died", false)
	F.Attacker:SetAttribute("Died", false)
	Check(F.Player:GetAttribute("InCombat") == true, "Resetting Died to false must not end combat")
	F.Service:SetInCombat(F.Victim, false)
	F.Service:SetInCombat(F.Victim, true, F.Attacker)
	F.Victim:SetAttribute("Died", true)
	CheckCleared(F)

	F = Fixture()
	F.Service:SetInCombat(F.Victim, true)
	F:Advance(45)
	CheckCleared(F)

	F = Fixture()
	F.Attacker.Humanoid = nil
	F.Service:SetInCombat(F.Victim, true, F.Attacker)
	F.Attacker.Destroying:Fire()
	CheckCleared(F)

	F = Fixture()
	local OtherPlayer = Object()
	OtherPlayer.CharacterRemoving = Signal()
	OtherAttacker = F:Character(OtherPlayer)
	F.Service:SetInCombat(F.Victim, true, OtherAttacker)
	Check(F.Service:IsInCombatWithPlayer(F.Victim), "Victim must detect PvP")
	Check(F.Service:IsInCombatWithPlayer(OtherAttacker), "Attacker must detect PvP through victim")
	F:Advance(45)
	Check(not F.Service:IsInCombatWithPlayer(F.Victim), "Expired opponents must not count as PvP")
	Check(not F.Service:IsInCombatWithPlayer(OtherAttacker), "Reverse PvP lookup must expire")

	F = Fixture()
	F.Service:SetInCombat(F.Victim, true, F.Attacker)
	F.Victim:SetAttribute("IntroWakeUp", true)
	F.Service:SetInCombat(F.Victim, false)
	F.Service:SetInCombat(F.Victim, true, F.Attacker)
	CheckCleared(F)
	F.Victim:SetAttribute("IntroWakeUp", false)
	F.Service:SetInCombat(F.Victim, true, F.Attacker)
	Check(F.Player:GetAttribute("InCombat") == true, "Combat resumes normally after wake-up protection ends")

	return `InCombatService: {Checks} checks passed`
end
