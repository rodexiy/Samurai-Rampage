local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CrouchConfig = require(ReplicatedStorage.Shared.CrouchConfig)
local CharacterShared = require(ReplicatedStorage.Shared.CharacterShared)

local CrouchService = Knit.CreateService({
	Name = "CrouchService",
	Client = {Request = Knit.CreateSignal()},
})

type Record = {
	Humanoid: Humanoid,
	HipHeight: number,
	Health: number?,
	LastRequest: number,
	Connections: { RBXScriptConnection },
}

local Records: { [Model]: Record } = {}
local HitService

function CrouchService:SetCrouching(Character: Model, Active: boolean): boolean
	local Record = Records[Character]
	if not Record or (Active and not CrouchConfig.CanCrouch(Character)) then
		return false
	end
	if Character:GetAttribute("Crouching") == Active then
		return true
	end

	if Active then
		Character:SetAttribute("Running", false)
	end

	local Root = Character.PrimaryPart
	local Scale = if Root then Root.Size.Y / 2 else 1
	Record.Humanoid.HipHeight = Record.HipHeight - (if Active then CrouchConfig.HeightDrop * Scale else 0)
	Character:SetAttribute("Crouching", Active)
	CharacterShared:UpdateBoth(Character)

	return true
end

function CrouchService:UnbindCharacter(Character: Model)
	local Record = Records[Character]
	if not Record then
		return
	end

	self:SetCrouching(Character, false)
	for _, Connection in Record.Connections do
		Connection:Disconnect()
	end
	Records[Character] = nil
end

function CrouchService:BindCharacter(Character: Model)
	local Humanoid = Character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not Humanoid or not Humanoid:IsA("Humanoid") or not Character.Parent or Records[Character] then
		return
	end

	local Record: Record = {
		Humanoid = Humanoid, HipHeight = Humanoid.HipHeight, Health = Character:GetAttribute("Health"),
		LastRequest = -math.huge, Connections = {},
	}
	Records[Character] = Record
	Character:SetAttribute("Crouching", false)

	local function CancelIfBlocked()
		if Character:GetAttribute("Crouching") and not CrouchConfig.CanCrouch(Character) then
			CrouchService:SetCrouching(Character, false)
		end
	end

	for _, Attribute in CrouchConfig.CancelAttributes do
		table.insert(Record.Connections, Character:GetAttributeChangedSignal(Attribute):Connect(CancelIfBlocked))
	end
	table.insert(Record.Connections, Humanoid.StateChanged:Connect(CancelIfBlocked))
	table.insert(Record.Connections, Humanoid:GetPropertyChangedSignal("Sit"):Connect(CancelIfBlocked))
	table.insert(Record.Connections, Humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(CancelIfBlocked))
	table.insert(Record.Connections, Humanoid.Died:Connect(function()
		CrouchService:SetCrouching(Character, false)
	end))
	table.insert(Record.Connections, Character:GetAttributeChangedSignal("Health"):Connect(function()
		local Health = Character:GetAttribute("Health")
		if typeof(Health) == "number" then
			if Record.Health and Health < Record.Health then
				CrouchService:SetCrouching(Character, false)
			end
			Record.Health = Health
		end
	end))

	local PreviousHealth = Humanoid.Health
	table.insert(Record.Connections, Humanoid.HealthChanged:Connect(function(Health: number)
		if Health < PreviousHealth then
			CrouchService:SetCrouching(Character, false)
		end
		PreviousHealth = Health
	end))
end

function CrouchService.KnitInit()
	HitService = Knit.GetService("HitService")
end

function CrouchService.KnitStart()
	CrouchService.Client.Request:Connect(function(Player: Player, Active: any)
		local Character = Player.Character
		local Record = Character and Records[Character]
		if typeof(Active) ~= "boolean" or not Character or not Record then
			return
		end

		local Now = os.clock()
		if Now - Record.LastRequest < CrouchConfig.RequestInterval then
			return
		end
		Record.LastRequest = Now
		CrouchService:SetCrouching(Character, Active)
	end)
	HitService.HitResolved.Event:Connect(function(Target: Model, _Attacker: Model, Result: string)
		if Result == "Hit" then
			CrouchService:SetCrouching(Target, false)
		end
	end)

	local function TrackPlayer(Player: Player)
		Player.CharacterAdded:Connect(function(Character: Model)
			CrouchService:BindCharacter(Character)
		end)
		Player.CharacterRemoving:Connect(function(Character: Model)
			CrouchService:UnbindCharacter(Character)
		end)
		local Character = Player.Character
		if Character then
			task.spawn(function()
				CrouchService:BindCharacter(Character)
			end)
		end
	end

	Players.PlayerAdded:Connect(TrackPlayer)
	for _, Player in Players:GetPlayers() do
		TrackPlayer(Player)
	end
end

return CrouchService
