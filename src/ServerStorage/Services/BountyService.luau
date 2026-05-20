local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local BountyService = Knit.CreateService({
	Name = "BountyService",
	Client = {},
})

local DataService
local PlaceService

local BountyPanel

function BountyService:UpdatePanel()
	for _, Target in BountyPanel.Targets:GetChildren() do
		local Player = Players:FindFirstChild(Target.Name)
		if not Player then
			Target:Destroy()
			continue
		end

		local PlayerData = DataService:GetData(Player)

		local Bounty = PlayerData.Bounty
		if Bounty <= 100 then
			Target:Destroy()
		end
	end

	for _, Player in Players:GetPlayers() do
		local PlayerData = DataService:GetData(Player)

		local Bounty = PlayerData.Bounty
		if BountyPanel.Targets:FindFirstChild(Player.Name) then
			continue
		end

		if Bounty >= 0 then
			local Template = BountyPanel.Template:Clone()
			Template.Name = Player.Name

			local Size = BountyPanel.Size
			local SizeX = Size.X / 2
			local SizeY = Size.Y / 2
			Template:PivotTo(
				BountyPanel:GetPivot()
					* CFrame.new(math.random(-SizeX, SizeX), math.random(-SizeY, SizeY), 0.1)
					* CFrame.Angles(0, math.rad(180), 0)
			)

			Player:GetAttributeChangedSignal("Bounty"):Connect(function()
				Template.SurfaceGui.Bounty.Text = Player:GetAttribute("Bounty")
			end)

			Template.SurfaceGui.Bounty.Text = Bounty

			Template.Parent = BountyPanel.Targets
			Template.SurfaceGui.ImageLabel.Image = Players:GetUserThumbnailAsync(
				Player.UserId,
				Enum.ThumbnailType.AvatarBust,
				Enum.ThumbnailSize.Size180x180
			)
		end
	end
end

function BountyService:AddBounty(Player: Player, Amount: number)
	local PlayerData = DataService:GetData(Player)
	PlayerData.Bounty += Amount
	Player:SetAttribute("Bounty", PlayerData.Bounty)
end

function BountyService.KnitInit()
	PlaceService = Knit.GetService("PlaceService")
	if workspace:FindFirstChild("Map") then
		if workspace.Map:FindFirstChild("Important") then
			if workspace.Map.Important:FindFirstChild("BountyPanel") then
				BountyPanel = workspace.Map.Important.BountyPanel
			end
		end
	 end
end


function BountyService.KnitStart()
	if not PlaceService:IsSHURA() then
		return
	end
	Players.PlayerAdded:Connect(function(player)
		repeat
			task.wait()
		until player:GetAttribute("Loaded")

		BountyService:UpdatePanel()
	end)

	Players.PlayerRemoving:Connect(function(player)
		BountyService:UpdatePanel()
	end)

	DataService = Knit.GetService("DataService")
end

return BountyService
