local Teams = game:GetService("Teams")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local PartyController = Knit.CreateController({
	Name = "PartyController",
})

local Player = game.Players.LocalPlayer
local PlayerGui
local Hud
local Menu
local PartyHud
local PartyMenu

local PartyService

local PartyData = nil

function PartyController:RemovePlayer(PlayerName: string)
	local Template = PartyHud.content:FindFirstChild(PlayerName)
	if Template then
		Template:Destroy()
	end

	local Player = game.Players:FindFirstChild(PlayerName)
	if Player then
		self:RemovePartyBillboard(Player)
	end
end

local Collector = require(game.ReplicatedStorage.Shared.Collector)

local Billboards = {}
local Connections = {}

function PartyController:RemovePartyBillboard(Player: Player)
	local _Billboard = Billboards[Player.Name]
	if _Billboard then
		_Billboard:Destroy()
	end

	Connections[Player.Name]:Destroy()
	Connections[Player.Name] = nil
end

function PartyController:AddPartyBillboard(Player: Player)
	local _Billboard = Billboards[Player.Name]
	if _Billboard then
		if _Billboard.Parent == nil or _Billboard.Parent.Parent == nil then
			_Billboard:Destroy()
			Billboards[Player.Name] = nil
		end
	end

	if not Connections[Player.Name] then
		local PlayerName = Player.Name
		Connections[PlayerName] = Collector.new()
		Connections[PlayerName]:Add(Player.CharacterAdded:Connect(function()
			self:AddPartyBillboard(Player)
		end))

		Connections[PlayerName]:Add(Player.Destroying:Connect(function()
			if Billboards[PlayerName] then
				Billboards[PlayerName]:Destroy()
			end
			Connections[PlayerName]:Destroy()
			Connections[PlayerName] = nil
		end))
	end

	local Billboard: BillboardGui = game.ReplicatedStorage.Assets.Billboards.Party:Clone()
	Billboard.Adornee = Player.Character:WaitForChild("HumanoidRootPart")
	Billboard.PlayerToHideFrom = Player
	Billboard.Icon.ImageColor3 = Player:GetAttribute("PartyColor") or Color3.fromRGB(255, 255, 255)
	Billboard.Parent = Player.Character

	Billboards[Player.Name] = Billboard
end

function PartyController:LoadParty()
	if not PartyData then
		return
	end

	for _, Template in PartyHud.content:GetChildren() do
		if Template:IsA("Frame") then
			local found = false
			for _, Member in PartyData.Members do
				if Member.Name == Template.Name then
					found = true
					break
				end
			end

			if not found then
				PartyController:RemovePlayer(Template.Name)
			end
		end
	end

	for _, Member in PartyData.Members do
		if PartyHud.content:FindFirstChild(Member.Name) then
			continue
		end

		PartyController:AddPartyBillboard(Member)
		local Template = PartyHud.Template:Clone()
		Template.Name = Member.Name
		Template.PlayerName.TextColor3 = Member:GetAttribute("PartyColor") or Color3.fromRGB(255, 255, 255)
		Template.PlayerName.Text = Member.Name
		Template.Icon.ImageColor3 = Member:GetAttribute("PartyColor") or Color3.fromRGB(255, 255, 255)
		if Member.Name == PartyData.Leader.Name then
			Template.Icon.Leader.Visible = true
		end
		Template.Visible = true
		Template.Parent = PartyHud.content
	end
end

function PartyController:CreateParty()
	PartyData = PartyService:CreateParty()
	if PartyData then
		PartyMenu.InviteBG.Visible = true
		PartyMenu.CreateParty.Visible = false
		PartyMenu.LeaveParty.Visible = true
		PartyMenu.LeaveParty.Active = true
		PartyMenu.Invite.Visible = true
	end

	PartyController:LoadParty()
end

function PartyController:LeftParty()
	PartyData = nil
	PartyMenu.CreateParty.Visible = true
	PartyMenu.CreateParty.Active = true

	PartyMenu.LeaveParty.Visible = false
	PartyMenu.InviteBG.Visible = false

	PartyMenu.CreateParty.Active = true
	PartyMenu.LeaveParty.Active = false
	PartyMenu.InvitePlaceholder.Text = ""
	PartyMenu.Invite.Visible = false
	for _, Template in PartyHud.content:GetChildren() do
		if Template:IsA("ImageLabel") then
			PartyController:RemovePlayer(Template.Name)
		end
	end
end

local InviteFrom
function PartyController:ReceivedInvite(Leader)
	InviteFrom = Leader
	PartyHud.Request.Message.Text = Leader.Name .. " Invited you to a party!"

	PartyHud.Request.Visible = true
end

function PartyController:PartyAccept()
	PartyHud.Request.Visible = false

	PartyService:JoinParty(InviteFrom)
	InviteFrom = nil
end
function PartyController:PartyDecline()
	PartyHud.Request.Visible = false

	PartyService:DeclineInvite(InviteFrom)
	InviteFrom = nil
end

function PartyController:Joined()
	PartyMenu.CreateParty.Visible = false
	PartyMenu.CreateParty.Active = false
	PartyMenu.LeaveParty.Visible = true
	PartyMenu.LeaveParty.Active = true
end

function PartyController.KnitInit()
	PartyService = Knit.GetService("PartyService")
end

function autofill(text)
	if text == "" then
		return ""
	end
	for _, v in game.Players:GetPlayers() do
		if v == Player then
			continue
		end
		if string.find(v.Name, text) then
			return v.Name
		end
	end
	return ""
end

function PartyController:BindInviteBox()
	local Invite: TextBox = PartyMenu.Invite

	local PlayerNameToInvite = ""
	Invite:GetPropertyChangedSignal("Text"):Connect(function()
		PlayerNameToInvite = autofill(Invite.Text)
		PartyMenu.InvitePlaceholder.Text = PlayerNameToInvite
	end)

	Invite.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			PartyService:InvitePlayer(game.Players:FindFirstChild(PlayerNameToInvite))
			PlayerNameToInvite = ""
			PartyMenu.Invite.Text = PlayerNameToInvite
			PartyMenu.InvitePlaceholder.Text = PlayerNameToInvite
		end
	end)
end

function PartyController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Hud = PlayerGui:WaitForChild("Hud")
	Menu = PlayerGui:WaitForChild("Menu")
	PartyHud = Hud:WaitForChild("Party")
	PartyMenu = Menu:WaitForChild("Meditate")

	PartyService.Update:Connect(function(Party)
		PartyData = Party
		PartyController:LoadParty()
	end)
	PartyService.LeftParty:Connect(function()
		PartyController:LeftParty()
	end)
	PartyService.Invited:Connect(function(Leader)
		PartyController:ReceivedInvite(Leader)
	end)
	PartyService.Joined:Connect(function()
		PartyController:Joined()
	end)
	PartyController:BindInviteBox()
end

return PartyController
