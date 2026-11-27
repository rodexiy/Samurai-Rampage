local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local FearService = Knit.CreateService({
	Name = "FearService",
	Client = { FearChanged = Knit.CreateSignal() },
})

type FearState = {
	Level: number,
	DecayTask: thread?,
}

local States: { [Player | Model]: FearState } = {}
local DECAY_PER_SECOND = 2

local function StopDecay(State: FearState)
	if State.DecayTask then
		task.cancel(State.DecayTask)
		State.DecayTask = nil
	end
end

local function ScheduleDecay(Player: Player | Model, State: FearState)
	if State.DecayTask or State.Level <= 0 then
		return
	end

	State.DecayTask = task.delay(1, function()
		State.DecayTask = nil
		if States[Player] == State then
			FearService:SetFear(Player, State.Level - DECAY_PER_SECOND)
		end
	end)
end

function FearService:GetFear(Player: Player | Model): number
	local State = States[Player]
	return if State then State.Level else 0
end

function FearService:SetFear(Player: Player | Model, Level: number): number
	assert(Level == Level and math.abs(Level) < math.huge, "Fear must be a finite number")
	local IsPlayer = Player:IsA("Player")
	if (IsPlayer and Player.Parent ~= Players) or (not IsPlayer and not Player:IsDescendantOf(workspace)) then
		local State = States[Player]
		if State then
			StopDecay(State)
			States[Player] = nil
		end
		return 0
	end

	local State = States[Player]
	if not State then
		State = { Level = 0 }
		States[Player] = State
		if not IsPlayer then
			Player.Destroying:Once(function()
				local Current = States[Player]
				if Current then
					StopDecay(Current)
					States[Player] = nil
				end
			end)
		end
	end

	local NewLevel = math.clamp(Level, 0, 100)
	local Changed = State.Level ~= NewLevel
	State.Level = NewLevel
	Player:SetAttribute("Fear", NewLevel)

	if Changed and IsPlayer then
		FearService.Client.FearChanged:Fire(Player, NewLevel)
	end

	if NewLevel > 0 then
		ScheduleDecay(Player, State)
	else
		StopDecay(State)
	end

	return NewLevel
end

function FearService:AddFear(Player: Player | Model, Amount: number): number
	return self:SetFear(Player, self:GetFear(Player) + Amount)
end

local function InitializePlayer(Player: Player)
	FearService:SetFear(Player, 0)

	Player.CharacterAdded:Connect(function(_Character: Model)
		FearService:SetFear(Player, 0)
	end)
	Player.CharacterRemoving:Connect(function(_Character: Model)
		FearService:SetFear(Player, 0)
	end)
end

function FearService.KnitStart()
	Players.PlayerAdded:Connect(InitializePlayer)
	Players.PlayerRemoving:Connect(function(Player: Player)
		local State = States[Player]
		if State then
			StopDecay(State)
			States[Player] = nil
		end
	end)

	for _, Player in Players:GetPlayers() do
		InitializePlayer(Player)
	end
end

return FearService
