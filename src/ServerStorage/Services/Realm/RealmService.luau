local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local TeleportCharacter = require(ReplicatedStorage.Shared.Utils.TeleportCharacter)
local TerrainRegionService = require(ServerStorage.Services.Services.Realm.TerrainRegionService)

local RealmService = Knit.CreateService({ Name = "RealmService", Client = {} })
local AlertService, DataService, StatService, RealmBuildingService
local RealmsFolder: Folder
local Realms, Busy, Plots = {}, {}, {}
local PLOT_SPACE = 4096
local REALM_HEIGHT = 48 -- Altura do realm em studs (eixo Y).

local function GetTerrainPreset(Template: Instance): TerrainRegion
	local Library = ServerStorage:FindFirstChild("TerrainLibrary")
	local Name = Template:GetAttribute("TerrainPreset")
	if Name == nil then
		local Embedded = Template:FindFirstChild("MentalRealm") or Template:FindFirstChildWhichIsA("TerrainRegion")
		if Embedded and Embedded:IsA("TerrainRegion") then
			return Embedded
		end
		Name = "Ilha Mental"
	end
	assert(typeof(Name) == "string", "RealmTemplate.TerrainPreset must be a preset name")

	local Preset = Template:FindFirstChild(Name) or (Library and Library:FindFirstChild(Name))
	assert(Preset and Preset:IsA("TerrainRegion"), "Missing Mental Realm TerrainRegion: " .. Name)

	return Preset :: TerrainRegion
end

function RealmService:GetRealm(Player: Player): Model?
	return Realms[Player.UserId]
end

function RealmService:GetAvailablePositionForRealm(_Player: Player): Vector3?
	for Index = 1, 20 do
		if not Plots[Index] then
			Plots[Index] = true
			return Vector3.new(Index * PLOT_SPACE, REALM_HEIGHT, Index * PLOT_SPACE)
		end
	end

	return nil
end

function RealmService:BreakResource(Player: Player, Resource: Model)
	if not self:HasOwnership(Player, Resource) then
		return
	end
	local Id = Resource:GetAttribute("ResourceId")
	local Data = DataService:GetData(Player)
	if Id and Data then
		Data.Realm.Removable[Id] = true
	end
end

function RealmService:LoadRemovable(Player: Player)
	local Realm = self:GetRealm(Player)
	local Data = DataService:GetData(Player)
	if not Realm or not Data then
		return
	end
	for _, Folder in Realm.Removable:GetChildren() do
		for _, Model in Folder:GetChildren() do
			local Id = Model:GetAttribute("ResourceId")
			if not Id then
				continue
			end
			if Data.Realm.Removable[Id] then
				Model:Destroy()
			else
				Model:SetAttribute("RealmId", Player.UserId)
			end
		end
	end
end

function RealmService:DestroyRealmByPlayer(Player: Player)
	local Realm = self:GetRealm(Player)
	if not Realm or Realm:GetAttribute("Unloading") then
		return
	end
	Realm:SetAttribute("Unloading", true)
	Realm:SetAttribute("Loaded", false)

	local Success, Error = TerrainRegionService.Unload(Realm)
	if not Success then
		Realm:SetAttribute("Unloading", false)
		warn("[Realm] Terrain restoration failed; retaining plot", Player.UserId, Error)
		return
	end

	Plots[Realm:GetAttribute("PlotOffset")] = nil
	Realms[Player.UserId] = nil
	Realm:Destroy()
end

function RealmService:LoadRealm(Player: Player): Model?
	if Player.Parent ~= Players then
		return nil
	end

	local Existing = self:GetRealm(Player)
	if Existing then
		return if Existing:GetAttribute("Loaded") and not Existing:GetAttribute("Unloading") then Existing else nil
	end
	local Position = self:GetAvailablePositionForRealm(Player)
	assert(Position, "All twenty realm plots are occupied")
	local Realm = Instance.new("Model")
	Realm.Name = tostring(Player.UserId)
	Realm:SetAttribute("OwnerId", Player.UserId)
	Realm:SetAttribute("PlotOffset", Position.X / PLOT_SPACE)
	Realm:SetAttribute("Loaded", false)
	Realms[Player.UserId] = Realm

	local Success, Error = pcall(function()
		local Template = ServerStorage.ServerAssets:FindFirstChild("RealmTemplate")
		assert(Template and (Template:IsA("Folder") or Template:IsA("Model")), "Missing RealmTemplate folder or model")
		local Preset = GetTerrainPreset(Template)
		local Offset = Template:GetAttribute("TerrainOffset") or Vector3.zero
		assert(typeof(Offset) == "Vector3", "RealmTemplate.TerrainOffset must be a Vector3")

		for _, Child in Template:GetChildren() do
			if not Child:IsA("TerrainRegion") then
				Child:Clone().Parent = Realm
			end
		end

		local Foundation = Realm:FindFirstChild("Foundation")
		local Baseplate = Foundation and Foundation:FindFirstChild("Baseplate") :: BasePart?
		assert(not Baseplate or Baseplate:IsA("BasePart"), "Foundation.Baseplate must be a BasePart")
		if Baseplate then
			Realm.PrimaryPart = Baseplate
		else
			local SourceCenter = Preset:GetAttribute("SourceCenter") or Vector3.zero
			assert(typeof(SourceCenter) == "Vector3", "Terrain preset SourceCenter must be a Vector3")
			Realm.WorldPivot = CFrame.new(SourceCenter)
		end
		Realm:PivotTo(CFrame.new(Position))
		Realm.Parent = RealmsFolder

		local Origin = Foundation and Foundation:FindFirstChild("TerrainOrigin") :: BasePart?
		assert(not Origin or Origin:IsA("BasePart"), "TerrainOrigin must be a BasePart")
		local Center = if Origin then Origin.Position else Realm:GetPivot():PointToWorldSpace(Offset)
		local TerrainLoaded, TerrainError = TerrainRegionService.Load(Realm, Preset, Center)
		assert(TerrainLoaded, TerrainError)

		-- Odd voxel dimensions can shift the grid center by two studs; keep structures aligned.
		local TerrainCenter = Realm:GetAttribute("TerrainCenter") :: Vector3
		Realm:PivotTo(Realm:GetPivot() + (TerrainCenter - Center))
		self:LoadRemovable(Player)
		RealmBuildingService:Load(Player, Realm)
	end)
	if not Success or Player.Parent ~= Players or Realms[Player.UserId] ~= Realm or Realm:GetAttribute("Unloading") then
		self:DestroyRealmByPlayer(Player)
		if not Success then
			warn("[Realm] Load failed", Player.UserId, Error)
		end
		return nil
	end

	Realm:SetAttribute("Loaded", true)
	Realm.Players.ChildRemoved:Connect(function()
		task.defer(function()
			if Realm.Parent and #Realm.Players:GetChildren() == 0 then
				self:DestroyRealmByPlayer(Player)
			end
		end)
	end)

	return Realm
end

function RealmService:TeleportPlayer(Player: Player)
	if Busy[Player] or Player:GetAttribute("InCombat") then
		return
	end
	Busy[Player] = true
	local Success, Error = pcall(function()
		local Character = Player.Character
		if not Character or not Character.PrimaryPart then
			return
		end
		local ReturnPose = Character:GetAttribute("RealmMeditateCFrame")
		if ReturnPose then
			StatService:SetMeditating(Player, false)
			Character:SetAttribute("InRealm", false)
			Character.Parent = workspace:FindFirstChild("Entity") or workspace
			Character:SetAttribute("RealmMeditateCFrame", nil)
			TeleportCharacter(Character, ReturnPose)
			return
		end
		local Realm = self:LoadRealm(Player)
		if not Realm or not Realm:GetAttribute("Loaded") then
			AlertService:AlertPlayer(Player, "Unable to load the Mental Realm. Please try again.", "Warn")
			return
		end
		local Destination = Realm.Structures.Spawn:GetPivot() * CFrame.new(0, -2, -5)
		if workspace.StreamingEnabled then
			Player:RequestStreamAroundAsync(Destination.Position, 10)
		end
		if Player.Character ~= Character or not Character.Parent or not Realm.Parent or Player:GetAttribute("InCombat") then
			if Realm.Parent and #Realm.Players:GetChildren() == 0 then
				self:DestroyRealmByPlayer(Player)
			end
			return
		end
		StatService:SetMeditating(Player, false)
		Character:SetAttribute("RealmMeditateCFrame", Character:GetPivot())
		Character.Parent = Realm.Players
		Character:SetAttribute("InRealm", true)
		TeleportCharacter(Character, Destination)
	end)
	Busy[Player] = nil
	if not Success then
		warn("[Realm] Teleport failed", Error)
		AlertService:AlertPlayer(Player, "Failed to access the Mental Realm.", "Warn")
	end
end

function RealmService.Client:Teleport(Player: Player)
	self.Server:TeleportPlayer(Player)
end

function RealmService:HasOwnership(Player: Player, Object: Model): boolean
	local Id = Object:GetAttribute("RealmId")

	return Id == nil or Id == Player.UserId
end

function RealmService.KnitInit()
	RealmsFolder = workspace:FindFirstChild("Realms") :: Folder?
	if not RealmsFolder then
		RealmsFolder = Instance.new("Folder")
		RealmsFolder.Name = "Realms"
		RealmsFolder.Parent = workspace
	end
	DataService = Knit.GetService("DataService")
	AlertService = Knit.GetService("AlertService")
	StatService = Knit.GetService("StatService")
	RealmBuildingService = Knit.GetService("RealmBuildingService")
end

function RealmService.KnitStart()
	Players.PlayerRemoving:Connect(function(Player: Player)
		RealmService:DestroyRealmByPlayer(Player)
		Busy[Player] = nil
	end)
end

return RealmService
