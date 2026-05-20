local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RaceController = Knit.CreateController({
	Name = "RaceController",
})

local RaceAssets = game.ReplicatedStorage.Assets.Races

local CharacterConnections = {}
local OriginalBodyColors = {}

local RaceFunctionsAdd = {
	Oni = function(Character: Model)
		for _, Hair in Character:GetChildren() do
			if not Hair:IsA("Accessory") then
				continue
			end

			local SpecialMesh: SpecialMesh = Hair:FindFirstChild("SpecialMesh", true)
			if SpecialMesh then
				if SpecialMesh:GetAttribute("OriginalTextureId") == nil then
					SpecialMesh:SetAttribute("OriginalTextureId", SpecialMesh.TextureId)
				end
				if SpecialMesh.Parent:GetAttribute("OriginalColor") == nil then
					SpecialMesh.Parent:SetAttribute("OriginalColor", SpecialMesh.Parent.Color)
				end

				SpecialMesh.TextureId = ""
				SpecialMesh.Parent.Color = Color3.fromRGB(222, 222, 222)
			end
		end
	end,
}

local RaceFunctionsRem = {
	Oni = function(Character: Model)
		for _, Hair in Character:GetChildren() do
			if not Hair:IsA("Accessory") then
				continue
			end

			local SpecialMesh: SpecialMesh = Hair:FindFirstChild("SpecialMesh", true)
			if SpecialMesh then
				local OriginalTextureId = SpecialMesh:GetAttribute("OriginalTextureId")
				local OriginalColor = SpecialMesh.Parent:GetAttribute("OriginalColor")

				if OriginalTextureId ~= nil then
					SpecialMesh.TextureId = OriginalTextureId
				end
				if OriginalColor ~= nil then
					SpecialMesh.Parent.Color = OriginalColor
				end
			end
		end
	end,
}

local function GetOrCreateRaceFolder(Character: Model)
	local Assets = Character:WaitForChild("Assets", 5)
	if not Assets then
		return
	end

	local RaceFolder = Assets:FindFirstChild("Race")
	if not RaceFolder then
		RaceFolder = Instance.new("Folder")
		RaceFolder.Name = "Race"
		RaceFolder.Parent = Assets
	end

	return RaceFolder
end

local function GetRaceModel(Character: Model)
	local RaceName = Character:GetAttribute("Race")
	local RaceVariant = Character:GetAttribute("RaceVariant")
	if not RaceName or not RaceVariant then
		return
	end

	local Race = RaceAssets:FindFirstChild(RaceName)
	if not Race then
		return
	end

	return Race:FindFirstChild(RaceVariant)
end

local function CacheOriginalBodyColors(Character: Model)
	if OriginalBodyColors[Character] then
		return
	end

	local BodyColors = Character:FindFirstChildWhichIsA("BodyColors")
	if BodyColors then
		OriginalBodyColors[Character] = BodyColors:Clone()
	end
end

local function RestoreOriginalBodyColors(Character: Model)
	local BodyColors = Character:FindFirstChildWhichIsA("BodyColors")
	if BodyColors and BodyColors:GetAttribute("ClientRaceBodyColors") then
		BodyColors:Destroy()
	end

	if not Character:FindFirstChildWhichIsA("BodyColors") and OriginalBodyColors[Character] then
		local RestoredBodyColors = OriginalBodyColors[Character]:Clone()
		RestoredBodyColors.Parent = Character
	end
end

function RaceController:UnloadRace(Character: Model)
	for _, Remove in RaceFunctionsRem do
		Remove(Character)
	end

	local RaceFolder = GetOrCreateRaceFolder(Character)
	if not RaceFolder then
		return
	end

	for _, Model in RaceFolder:GetChildren() do
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

	RaceFolder:ClearAllChildren()
	RestoreOriginalBodyColors(Character)
end

function RaceController:UpdatePupilColor(Character: Model)
	local RaceFolder = GetOrCreateRaceFolder(Character)
	if not RaceFolder then
		return
	end

	local Pupil = RaceFolder:FindFirstChild("Pupil", true)
	if Pupil and Pupil:IsA("BasePart") then
		local EyesColor = Character:GetAttribute("EyesColor")
		if typeof(EyesColor) == "Color3" then
			Pupil.Color = EyesColor
		end
	end
end

function RaceController:LoadRace(Character: Model)
	CacheOriginalBodyColors(Character)
	self:UnloadRace(Character)

	local RaceModel = GetRaceModel(Character)
	if not RaceModel then
		return
	end

	local Race = Character:GetAttribute("Race")
	if RaceFunctionsAdd[Race] then
		RaceFunctionsAdd[Race](Character)
	end

	local RaceBodyColors = RaceModel:FindFirstChildWhichIsA("BodyColors")
	if RaceBodyColors then
		local BodyColors = Character:FindFirstChildWhichIsA("BodyColors")
		if BodyColors then
			BodyColors:Destroy()
		end

		local BodyColorsClone = RaceBodyColors:Clone()
		BodyColorsClone:SetAttribute("ClientRaceBodyColors", true)
		BodyColorsClone.Parent = Character
	end

	local RaceFolder = GetOrCreateRaceFolder(Character)
	if not RaceFolder then
		return
	end

	for _, Part in RaceModel:GetChildren() do
		if Part:IsA("BodyColors") or Part.Name == "Parts" then
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
		PartClone.Parent = RaceFolder
	end

	self:UpdatePupilColor(Character)
end

function RaceController:BindCharacter(Character: Model)
	if CharacterConnections[Character] then
		return
	end

	local Connections = {}
	CharacterConnections[Character] = Connections

	if not Character:WaitForChild("Assets", 5) then
		CharacterConnections[Character] = nil
		return
	end

	self:LoadRace(Character)

	table.insert(Connections, Character:GetAttributeChangedSignal("Race"):Connect(function()
		self:LoadRace(Character)
	end))

	table.insert(Connections, Character:GetAttributeChangedSignal("RaceVariant"):Connect(function()
		self:LoadRace(Character)
	end))

	table.insert(Connections, Character:GetAttributeChangedSignal("EyesColor"):Connect(function()
		self:UpdatePupilColor(Character)
	end))

	table.insert(Connections, Character.Destroying:Connect(function()
		for _, Connection in Connections do
			Connection:Disconnect()
		end
		CharacterConnections[Character] = nil
		OriginalBodyColors[Character] = nil
	end))
end

function RaceController.KnitStart()
	local Entity = workspace:WaitForChild("Entity")

	for _, Character in Entity:GetChildren() do
		if Character:IsA("Model") then
			task.spawn(function()
				RaceController:BindCharacter(Character)
			end)
		end
	end

	Entity.ChildAdded:Connect(function(Character)
		if Character:IsA("Model") then
			RaceController:BindCharacter(Character)
		end
	end)
end

return RaceController
