local Knit = require(game.ReplicatedStorage.Packages.Knit)

local EquipmentController = Knit.CreateController({
	Name = "EquipmentController",
})

local Items = require(game.ReplicatedStorage.Shared.Index.Items)
local Equipables = game.ReplicatedStorage.Assets.Equipables

local EquipmentTypes = {
	"Head",
	"Face",
	"Torso",
	"Legs",
	"Back",
	"Eyes",
	"Waist",
	"Prosthetic",
	"Artifact",
}

local CharacterConnections = {}

local function GetEquipmentModel(EquipmentName: string)
	return Equipables:FindFirstChild(EquipmentName, true)
end

local function GetOrCreateEquipmentFolder(Character: Model, Type: string)
	local Assets = Character:WaitForChild("Assets", 5)
	if not Assets then
		return
	end

	local EquipablesFolder = Assets:FindFirstChild("Equipables")
	if not EquipablesFolder then
		EquipablesFolder = Instance.new("Folder")
		EquipablesFolder.Name = "Equipables"
		EquipablesFolder.Parent = Assets
	end

	local TypeFolder = EquipablesFolder:FindFirstChild(Type)
	if not TypeFolder then
		TypeFolder = Instance.new("Folder")
		TypeFolder.Name = Type
		TypeFolder.Parent = EquipablesFolder
	end

	return TypeFolder
end

local function SetHairTransparency(Character: Model, Transparency: number)
	for _, Hair in Character:GetChildren() do
		if Hair.Name ~= "Hair" then
			continue
		end

		for _, Part in Hair:GetDescendants() do
			if Part:IsA("BasePart") then
				Part.Transparency = Transparency
			end
		end
	end
end

function EquipmentController:UnloadEquipment(Character: Model, Type: string)
	local TypeFolder = GetOrCreateEquipmentFolder(Character, Type)
	if not TypeFolder then
		return
	end

	for _, Model in TypeFolder:GetChildren() do
		if Model:GetAttribute("HidePart0") then
			local CharacterPart = Character:FindFirstChild(Model.Name)
			if CharacterPart and CharacterPart:IsA("BasePart") then
				CharacterPart.Transparency = 0
			end
		end

		for _, Asset in Model:GetDescendants() do
			Asset:RemoveTag("SmartBone")
		end
	end

	if Type == "Head" then
		SetHairTransparency(Character, 0)
	end

	TypeFolder:ClearAllChildren()
end

function EquipmentController:ApplyFlag(Character: Model)
	if Character:GetAttribute("Back") ~= "Flag" then
		return
	end

	local TypeFolder = GetOrCreateEquipmentFolder(Character, "Back")
	if not TypeFolder then
		return
	end

	local Color = Character:GetAttribute("FlagColor")
	for _, Part in TypeFolder:GetDescendants() do
		if Part:IsA("BasePart") and Part.Name == "Flag" then
			Part.Color = Color3.fromHex(Color or "ffffff")
		end
	end

	local ImagePart = TypeFolder:FindFirstChild("ImagePart", true)
	if not ImagePart then
		return
	end

	local Image = Character:GetAttribute("FlagImage")
	for _, Decal in ImagePart:GetDescendants() do
		if Decal:IsA("Decal") then
			Decal.Texture = if Image then "rbxassetid://" .. tostring(Image) else ""
		end
	end
end

function EquipmentController:LoadEquipment(Character: Model, Type: string)
	self:UnloadEquipment(Character, Type)

	local EquipmentName = Character:GetAttribute(Type)
	if not EquipmentName then
		return
	end

	local ItemData = Items[EquipmentName]
	if ItemData and ItemData.HideHair and Type == "Head" then
		SetHairTransparency(Character, 1)
	end

	local EquipmentModel = GetEquipmentModel(EquipmentName)
	if not EquipmentModel then
		return
	end

	local TypeFolder = GetOrCreateEquipmentFolder(Character, Type)
	if not TypeFolder then
		return
	end

	for _, Part in EquipmentModel:GetChildren() do
		if Part.Name == "Parts" then
			continue
		end

		local CharacterPart = Character:FindFirstChild(Part.Name)
		if not CharacterPart or not CharacterPart:IsA("BasePart") then
			continue
		end

		local PartClone = Part:Clone()

		for _, Descendant in PartClone:GetDescendants() do
			if Descendant:IsA("BasePart") then
				Descendant.CanCollide = false
				Descendant.Anchored = false
				Descendant.Massless = true
			end
		end

		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = CharacterPart

		if PartClone:IsA("Model") then
			if not PartClone.PrimaryPart then
				PartClone:Destroy()
				Weld:Destroy()
				continue
			end

			Weld.Part1 = PartClone.PrimaryPart
			Weld.Parent = PartClone.PrimaryPart
		else
			Weld.Part1 = PartClone
			Weld.Parent = PartClone
		end

		if PartClone:GetAttribute("HidePart0") then
			CharacterPart.Transparency = 1
		end

		PartClone:PivotTo(CharacterPart:GetPivot())
		PartClone.Parent = TypeFolder
	end

	if EquipmentName == "Flag" then
		self:ApplyFlag(Character)
	end
end

function EquipmentController:LoadEquipments(Character: Model)
	for _, Type in EquipmentTypes do
		self:LoadEquipment(Character, Type)
	end
end

function EquipmentController:BindCharacter(Character: Model)
	if CharacterConnections[Character] then
		return
	end

	local Connections = {}
	CharacterConnections[Character] = Connections

	local Assets = Character:WaitForChild("Assets", 5)
	if not Assets then
		CharacterConnections[Character] = nil
		return
	end

	if not Assets:FindFirstChild("Equipables") then
		local EquipablesFolder = Instance.new("Folder")
		EquipablesFolder.Name = "Equipables"
		EquipablesFolder.Parent = Assets
	end

	self:LoadEquipments(Character)

	for _, Type in EquipmentTypes do
		table.insert(Connections, Character:GetAttributeChangedSignal(Type):Connect(function()
			self:LoadEquipment(Character, Type)
		end))
	end

	table.insert(Connections, Character:GetAttributeChangedSignal("FlagColor"):Connect(function()
		self:ApplyFlag(Character)
	end))

	table.insert(Connections, Character:GetAttributeChangedSignal("FlagImage"):Connect(function()
		self:ApplyFlag(Character)
	end))

	table.insert(Connections, Character.Destroying:Connect(function()
		for _, Connection in Connections do
			Connection:Disconnect()
		end
		CharacterConnections[Character] = nil
	end))
end

function EquipmentController.KnitStart()
	local Entity = workspace:WaitForChild("Entity")

	for _, Character in Entity:GetChildren() do
		if Character:IsA("Model") then
			task.spawn(function()
				EquipmentController:BindCharacter(Character)
			end)
		end
	end

	Entity.ChildAdded:Connect(function(Character)
		if Character:IsA("Model") then
			EquipmentController:BindCharacter(Character)
		end
	end)
end

return EquipmentController
