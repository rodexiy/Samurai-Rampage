local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local InCombatService = Knit.CreateService({
	Name = "InCombatService",
	Client = {},
})

type Connections = { RBXScriptConnection }
type CombatState = {
	Character: Model,
	Attackers: { [Model]: Connections },
	Connections: Connections,
	EndsAt: number,
}

local InCombatDuration = 45
local CombatStates: { [Player]: CombatState } = {}

local function DisconnectAll(List: Connections)
	for _, Connection in List do
		Connection:Disconnect()
	end
end

local function ClearCombat(Player: Player, State: CombatState)
	if CombatStates[Player] ~= State then
		return
	end

	CombatStates[Player] = nil
	DisconnectAll(State.Connections)
	for _, List in State.Attackers do
		DisconnectAll(List)
	end

	Player:SetAttribute("InCombat", false)
	Player:SetAttribute("InCombatEndTick", nil)
	State.Character:SetAttribute("InCombat", false)
end

local function WatchCharacter(Character: Model, Cleanup: () -> ()): Connections
	local List = {
		Character:GetAttributeChangedSignal("Died"):Connect(function()
			if Character:GetAttribute("Died") then
				Cleanup()
			end
		end),
		Character.Destroying:Connect(Cleanup),
		Character.AncestryChanged:Connect(function()
			if not Character:IsDescendantOf(workspace) then
				Cleanup()
			end
		end),
	}

	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if Humanoid then
		table.insert(List, Humanoid.Died:Connect(Cleanup))
	end

	return List
end

local function ScheduleExpiration(Player: Player, State: CombatState)
	task.delay(math.max(0, State.EndsAt - workspace:GetServerTimeNow()), function()
		if CombatStates[Player] ~= State then
			return
		end

		-- Hits extend the same deadline without creating one timer per hit.
		if workspace:GetServerTimeNow() < State.EndsAt then
			ScheduleExpiration(Player, State)
		else
			ClearCombat(Player, State)
		end
	end)
end

local function TrackAttacker(Player: Player, State: CombatState, Attacker: Model)
	if State.Attackers[Attacker] then
		return
	end

	State.Attackers[Attacker] = WatchCharacter(Attacker, function()
		if CombatStates[Player] ~= State then
			return
		end

		local List = State.Attackers[Attacker]
		if not List then
			return
		end

		State.Attackers[Attacker] = nil
		DisconnectAll(List)
		if next(State.Attackers) == nil then
			ClearCombat(Player, State)
		end
	end)
end

function InCombatService:SetInCombat(Character: Model, SetInCombat: boolean, Attacker: Model?)
	if Character:GetAttribute("IsAI") then
		Character:SetAttribute("InCombat", SetInCombat)
		return
	end

	local Player = Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end

	local State = CombatStates[Player]
	if not SetInCombat then
		if State then
			if Attacker then
				local List = State.Attackers[Attacker]
				if List then
					State.Attackers[Attacker] = nil
					DisconnectAll(List)
				end

				if next(State.Attackers) ~= nil then
					return
				end
			end

			ClearCombat(Player, State)
		end

		Player:SetAttribute("InCombat", false)
		Player:SetAttribute("InCombatEndTick", nil)
		Character:SetAttribute("InCombat", false)
		return
	end

	if Character:GetAttribute("Died") or Character:GetAttribute("IntroWakeUp") or not Character:IsDescendantOf(workspace) then
		return
	end

	if State and State.Character ~= Character then
		ClearCombat(Player, State)
		State = nil
	end

	local EndsAt = workspace:GetServerTimeNow() + InCombatDuration
	if not State then
		local NewState: CombatState = {
			Character = Character,
			Attackers = {},
			Connections = {},
			EndsAt = EndsAt,
		}
		CombatStates[Player] = NewState
		State = NewState
		NewState.Connections = WatchCharacter(Character, function()
			ClearCombat(Player, NewState)
		end)
		table.insert(NewState.Connections, Player.CharacterRemoving:Connect(function(RemovedCharacter: Model)
			if RemovedCharacter == Character then
				ClearCombat(Player, NewState)
			end
		end))
		ScheduleExpiration(Player, NewState)
	end

	State.EndsAt = EndsAt
	Player:SetAttribute("InCombat", true)
	Character:SetAttribute("InCombat", true)
	Player:SetAttribute("InCombatEndTick", EndsAt)

	if Attacker and not Attacker:GetAttribute("Died") and Attacker:IsDescendantOf(workspace) then
		TrackAttacker(Player, State, Attacker)
	end
end

function InCombatService:GetInCombatWith(Character: Model): { [Model]: Connections }?
	local Player = Players:GetPlayerFromCharacter(Character)
	local State = Player and CombatStates[Player]
	return if State then State.Attackers else nil
end

function InCombatService:IsInCombatWithPlayer(Character: Model): boolean
	local Player = Players:GetPlayerFromCharacter(Character)
	if not Player then
		return false
	end

	local State = CombatStates[Player]
	if State then
		for OpponentCharacter in State.Attackers do
			if Players:GetPlayerFromCharacter(OpponentCharacter) then
				return true
			end
		end
	end

	for OtherPlayer, OtherState in CombatStates do
		if OtherPlayer ~= Player and OtherState.Attackers[Character] then
			return true
		end
	end

	return false
end

return InCombatService
