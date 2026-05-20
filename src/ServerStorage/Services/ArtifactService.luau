local LocalizationService = game:GetService("LocalizationService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ArtifactService = Knit.CreateService({
	Name = "ArtifactService",
	Client = {
		Obtained = Knit.CreateSignal(),
	},
})

local InventoryService
local AlertService
local ItemService
local SkillService
local SkillTreeService
local DialogService
local RenderService
local DataService
local SoundEffectService
local EquipmentService

local ArtifactsWorkspace = Instance.new("Folder")
ArtifactsWorkspace.Name = "Artifacts"
ArtifactsWorkspace.Parent = workspace

local Tools = game.ReplicatedStorage.Assets.Tools

function ArtifactService:GenerateRandomArtifact() end

function ArtifactService:ResetArtifact(Player: Player)
	local PlayerData = DataService:GetData(Player)

	SkillTreeService:ResetSpecificSkillTree(Player, PlayerData.Artifact:gsub(" ", ""))
	PlayerData.Artifact = nil

	local Character = Player.Character
	if Character then
		Character:SetAttribute("Artifact", nil)
	end

	EquipmentService:UnloadEquipment(Character, "Artifact")

	SkillService:LoadSkills(Player)
end

function ArtifactService:UseArtifact(Player: Player, ArtifactName: string)
	local Artifact = Player.Character:FindFirstChild(ArtifactName)
	if not Artifact then
		return
	end

	if Artifact:GetAttribute("Class") ~= "Artifact" then
		return
	end

	local PlayerData = DataService:GetData(Player)
	if PlayerData.Artifact ~= nil then
		AlertService:AlertPlayer(Player, "You already have an artifact!", "Error")
		return
	end

	PlayerData.Artifact = Artifact.Name

	if Player.Character then
		Player.Character:SetAttribute("Artifact", Artifact.Name)
	end

	SoundEffectService:PlaySoundEffect(ArtifactName .. "Use", true, Player.Character.HumanoidRootPart)
	SkillService:LoadSkills(Player)

	Artifact:Destroy()

	EquipmentService:LoadEquipment(Player.Character, "Artifact", ArtifactName)
	InventoryService:UpdateUI(Player, true)
	RenderService:RenderForAllPlayers("Artifacts", ArtifactName, { Character = Player.Character })
end

function ArtifactService:PromptArtifact(Player: Player, Artifact: Tool)
	DialogService:StartDialog(Player, Artifact.Name)
end

function ArtifactService:GetArtifactData(ArtifactName: string)
	return ItemService:GetItemData(ArtifactName)
end

function ArtifactService:DropArtifact(Player: Player, Tool: Tool)
	local Character = Player.Character
	local Artifact = Tool or Character:FindFirstChildWhichIsA("Tool")

	if not Artifact or Artifact:GetAttribute("Class") ~= "Artifact" then
		print("Artifact not found")
		return
	end

	local ArtifactName = Artifact.Name
	local Model = Instance.new("Model")
	for _, Part in Artifact:GetChildren() do
		Part:Clone().Parent = Model
	end
	Artifact:Destroy()
	Artifact = Model

	Artifact.Name = ArtifactName
	Artifact:PivotTo(Character.PrimaryPart.CFrame * CFrame.new(0, 0, -2))

	Artifact.PrimaryPart = Artifact:FindFirstChild("Handle") or Artifact:FindFirstChildWhichIsA("BasePart", true)
	for _, Part in Artifact:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.CanCollide = true
			Part.Massless = false
		end
	end

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.ObjectText = ArtifactName
	Prompt.ActionText = "Pick up"
	Prompt.HoldDuration = 1
	Prompt.RequiresLineOfSight = false
	Prompt.Parent = Artifact.PrimaryPart

	Prompt.Triggered:Connect(function(Player: Player)
		self:PickArtifact(Player, Artifact)
	end)

	Artifact.Parent = ArtifactsWorkspace
	InventoryService:UpdateUI(Player, true)
end
function ArtifactService.Client:DropArtifact(Player: Player)
	self.Server:DropArtifact(Player)
end

function ArtifactService:PickArtifact(Player: Player, Artifact: Model, DroppedFromBoss: boolean)
	local ArtifactName = Artifact
	if not DroppedFromBoss then
		ArtifactName = Artifact.Name
		Artifact:Destroy()
	end

	if not InventoryService:GetPlayerItemByName(Player, ArtifactName) then
		InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem(ArtifactName, 1))
		return
	end

	if DroppedFromBoss then
		self.Client.Obtained:Fire(Player, ArtifactName)
	end

	local Index = InventoryService:GetAvailableHotbarIndex(Player)
	local Tool = Tools:FindFirstChild(ArtifactName)

	Tool = Tool:Clone()
	Tool:SetAttribute("HotbarIndex", Index)
	Tool:SetAttribute("Name", ArtifactName)
	Tool:SetAttribute("Class", "Artifact")
	Tool:SetAttribute("Type", "Artifact")

	if Index then
		Tool.Parent = Player.Backpack

		return
	end

	self:DropArtifact(Player, Tool:Clone())
end

function ArtifactService.KnitInit()
	SoundEffectService = Knit.GetService("SoundEffectService")
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	AlertService = Knit.GetService("AlertService")
	ItemService = Knit.GetService("ItemService")
	SkillService = Knit.GetService("SkillService")
	SkillTreeService = Knit.GetService("SkillTreeService")
	DialogService = Knit.GetService("DialogService")
	RenderService = Knit.GetService("RenderService")
	EquipmentService = Knit.GetService("EquipmentService")
end

function ArtifactService.KnitStart() end

return ArtifactService
