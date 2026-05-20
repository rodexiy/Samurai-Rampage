local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local FlagService = Knit.CreateService({
	Name = "FlagService",
	Client = {},
})

local DataService
local AlertService

function FlagService:ChangeFlagImage(Player: Player, Image: number)
	local PlayerData = DataService:GetData(Player)

	PlayerData.FlagImage = Image

	local Character = Player.Character

	if not Character then
		return
	end

	Character:SetAttribute("FlagImage", Image)
	FlagService:LoadFlag(Character)
end
function FlagService.Client:ChangeFlagImage(Player: Player, Image: number)
	self.Server:ChangeFlagImage(Player, Image)
end

function FlagService:ChangeFlagColor(Player: Player, Color: string)
	local PlayerData = DataService:GetData(Player)

	PlayerData.FlagColor = Color

	local Character = Player.Character

	if not Character then
		return
	end

	Character:SetAttribute("FlagColor", Color)
	FlagService:LoadFlag(Character)
end
function FlagService.Client:ChangeFlagColor(Player: Player, Color: string)
	self.Server:ChangeFlagColor(Player, Color)
end

function FlagService:LoadFlag(Character: Model)
	if Character:GetAttribute("Back") ~= "Flag" then
		return
	end

	local Equipables = Character:FindFirstChild("Assets") and Character.Assets:FindFirstChild("Equipables")
	local Back = Equipables and Equipables:FindFirstChild("Back")
	if not Back then
		return
	end

	local Color = Character:GetAttribute("FlagColor")

	if not Color then
		local Player = Players:GetPlayerFromCharacter(Character)
		if Player then
			local PlayerData = DataService:GetData(Player)
			Color = PlayerData.FlagColor
		else
			return
		end
	end

	for _, Part in Back:GetDescendants() do
		if Part:IsA("BasePart") and Part.Name == "Flag" then
			Part.Color = Color3.fromHex(Color or "ffffff")
		end
	end

	local Image = Character:GetAttribute("FlagImage")
	if not Image then
		local Player = Players:GetPlayerFromCharacter(Character)
		if Player then
			local PlayerData = DataService:GetData(Player)
			Image = PlayerData.FlagImage
		else
			return
		end
	end

	local ImagePart = Back:FindFirstChild("ImagePart", true)

	if not ImagePart then
		return
	end

	for _, Decal in ImagePart:GetDescendants() do
		if Decal:IsA("Decal") then
			Decal.Texture = if Image then "rbxassetid://" .. tostring(Image) else 0
		end
	end
end

function FlagService.KnitInit()
	DataService = Knit.GetService("DataService")
	AlertService = Knit.GetService("AlertService")
end

function FlagService.KnitStart() end

return FlagService
