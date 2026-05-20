local Knit = require(game.ReplicatedStorage.Packages.Knit)

local PartyService = Knit.CreateService({
	Name = "PartyService",
	Client = {
		Invited = Knit.CreateSignal(),
		Update = Knit.CreateSignal(),
		LeftParty = Knit.CreateSignal(),
		Joined = Knit.CreateSignal(),
	},
})

local AlertService

type PartyData = {
	Leader: Player,
	Members: { Player },
	Invited: { Player },
}

function PartyService:UpdateParty(Party: PartyData)
	for _, Player in Party.Members do
		self.Client.Update:Fire(Player, Party)
	end
end

local Parties = {}
function PartyService:GetPlayerParty(Player: Player)
	if not Player then
		return
	end
	for _, Party in Parties do
		for _, Member in Party.Members do
			if Member == Player then
				return Party
			end
		end
	end
end

function PartyService:GetLeaderParty(Player: Player)
	local Party = self:GetPlayerParty(Player)
	if not Party then
		return
	end

	if Party.Leader == Player then
		return Party
	end
end

function PartyService:CreateParty(Leader: Player)
	if self:GetPlayerParty(Leader) then
		return
	end

	local Party = {
		Leader = Leader,
		Members = {},
		Invited = {},
	}
	Leader:SetAttribute("PartyColor", Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255)))
	table.insert(Party.Members, Leader)
	table.insert(Parties, Party)
	return Party
end
function PartyService.Client:CreateParty(Leader: Player)
	return self.Server:CreateParty(Leader)
end

function PartyService:InvitePlayer(Leader: Player, Invited: Player)
	if not Invited then
		return
	end

	local Party = self:GetLeaderParty(Leader)
	if not Party then
		return false
	end

	if self:GetPlayerParty(Invited) then
		return false
	end

	if table.find(Party.Invited, Invited) then
		return false
	end

	AlertService:AlertPlayer(Leader, "Invited " .. Invited.Name .. " to a party!", "Success")
	table.insert(Party.Invited, Invited)

	self.Client.Invited:Fire(Invited, Leader)
end
function PartyService.Client:InvitePlayer(Leader: Player, Invited: Player)
	return self.Server:InvitePlayer(Leader, Invited)
end

function PartyService:DeclineInvite(Player: Player, Leader: Player)
	local Party = self:GetLeaderParty(Leader)
	if not Party then
		return
	end

	local InvitedIndex = table.find(Party.Invited, Player)
	if InvitedIndex then
		table.remove(Party.Invited, InvitedIndex)
	end
end
function PartyService.Client:DeclineInvite(Player: Player, Leader: Player)
	return self.Server:DeclineInvite(Player, Leader)
end

function PartyService:JoinParty(Player: Player, Leader: Player)
	local Party = self:GetLeaderParty(Leader)
	if not Party then
		return
	end

	local InvitedIndex = table.find(Party.Invited, Player)
	if InvitedIndex then
		table.remove(Party.Invited, InvitedIndex)
	end

	table.insert(Party.Members, Player)
	Player:SetAttribute("PartyColor", Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255)))

	self:UpdateParty(Party)

	self.Client.Joined:Fire(Player)
end
function PartyService.Client:JoinParty(Player: Player, Leader: Player)
	return self.Server:JoinParty(Player, Leader)
end

function PartyService:LeaveParty(Player: Player)
	local Party = self:GetPlayerParty(Player)
	if not Party then
		return
	end

	local LeaderLeft = false
	if Party.Leader == Player then
		LeaderLeft = true
		for _, Member in Party.Members do
			if Member ~= Player then
				AlertService:AlertPlayer(Member, "Leader left the party!", "Warn")
			end
		end

		table.remove(Parties, table.find(Parties, Party))
	end

	if LeaderLeft then
		local Members = Party.Members

		Party.Members = {}

		for _, Member in Members do
			self.Client.LeftParty:Fire(Member)
		end
	else
		table.remove(Party.Members, table.find(Party.Members, Player))
		self:UpdateParty(Party)
	end
end
function PartyService.Client:LeaveParty(Player: Player)
	return self.Server:LeaveParty(Player)
end

function PartyService.KnitInit()
	AlertService = Knit.GetService("AlertService")
end

return PartyService
