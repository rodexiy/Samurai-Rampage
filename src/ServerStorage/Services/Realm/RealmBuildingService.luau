local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Building = require(ReplicatedStorage.Shared.RealmBuilding)
local Resources = require(ReplicatedStorage.Shared.RealmResources)
local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)

local RealmBuildingService = Knit.CreateService({
	Name = "RealmBuildingService",
	Client = {
		Editing = Knit.CreateSignal(),
		Place = Knit.CreateSignal(),
		PlacementResult = Knit.CreateSignal(),
		Move = Knit.CreateSignal(),
		MovementResult = Knit.CreateSignal(),
		Delete = Knit.CreateSignal(),
		DeletionResult = Knit.CreateSignal(),
		HistoryAction = Knit.CreateSignal(),
		HistoryResult = Knit.CreateSignal(),
		HistoryChanged = Knit.CreateSignal(),
	},
})

local RealmService, DataService, HistoryService, ResourceService
local Sessions: { [Player]: Model } = {}
local LastRequest: { [Player]: number } = {}

local function FindRecord(Data: any, Id: string): any
	for _, Record in Data.Realm.PlacedObjects do
		if Record.Id == Id then
			return Record
		end
	end

	return nil
end

local function CommitMove(Realm: Model, Object: PVInstance, Record: any, Frame: CFrame, Angle: number?)
	Object:PivotTo(Frame)
	Object:SetAttribute("PlacementAngle", Angle)
	Record.Transform = { Realm:GetPivot():ToObjectSpace(Frame):GetComponents() }
	Record.Angle = Angle
end

local function GetOwnedObject(Realm: Model, Player: Player, Id: string): PVInstance?
	local Objects = Realm:FindFirstChild("PlacedObjects")
	if Objects then
		for _, Object in Objects:GetChildren() do
			if (Object:IsA("Model") or Object:IsA("BasePart")) and Object:GetAttribute("PlacementId") == Id
				and Object:GetAttribute("RealmId") == Player.UserId then
				return Object
			end
		end
	end

	return nil
end

function RealmBuildingService:PublishHistory(Player: Player)
	local Realm = RealmService:GetRealm(Player)
	if Realm then
		local UndoCount, RedoCount = HistoryService:GetCounts(Player, Realm)
		self.Client.HistoryChanged:Fire(Player, UndoCount, RedoCount)
	end
end

function RealmBuildingService:Load(Player: Player, Realm: Model)
	local Data = DataService:GetData(Player)
	if not Data then
		return
	end
	ResourceService:FlushPending(Player)

	local Objects = Realm:FindFirstChild("PlacedObjects")
	if not Objects then
		Objects = Instance.new("Folder")
		Objects.Name = "PlacedObjects"
		Objects.Parent = Realm
	end
	for Index, Record in Data.Realm.PlacedObjects do
		if typeof(Index) ~= "number" or Index > Building.MaxObjects or typeof(Record) ~= "table"
			or typeof(Record.Transform) ~= "table" or #Record.Transform ~= 12 then
			continue
		end
		local Valid = true
		for _, Component in Record.Transform do
			if typeof(Component) ~= "number" or not Building.IsFinite(Component) then
				Valid = false
				break
			end
		end
		local Asset = Building.Resolve(Record.Asset)
		if not Valid or not Asset then
			continue
		end

		local Frame = Realm:GetPivot() * CFrame.new(table.unpack(Record.Transform))
		local Bounds = Building.GetBounds(Asset)
		if not Building.IsInside(Realm, Frame * Bounds.Offset, Bounds.Size) then
			continue
		end
		local Object, RestoreTags = Building.Clone(Asset)
		Building.Prepare(Object, false)
		Object:SetAttribute("PlacementId", Record.Id)
		Object:SetAttribute("RealmId", Player.UserId)
		Object:SetAttribute("PlacementAngle", Record.Angle)
		Object:PivotTo(Frame)
		Object.Parent = Objects
		RestoreTags()
	end
end

function RealmBuildingService:CanEdit(Player: Player): boolean
	local Realm = RealmService:GetRealm(Player)
	local Character = Player.Character
	local Humanoid = Character and Character:FindFirstChildWhichIsA("Humanoid")
	if not Realm or Realm:GetAttribute("OwnerId") ~= Player.UserId or not Realm:GetAttribute("Loaded")
		or Realm:GetAttribute("Unloading") or not Character or not Character.PrimaryPart
		or not Humanoid or Humanoid.Health <= 0 or not Character:GetAttribute("InRealm")
		or not Character:IsDescendantOf(Realm) or Player:GetAttribute("InCombat") then
		return false
	end

	for _, Attribute in Building.BlockedStates do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end

	return true
end

function RealmBuildingService:GetPlacementFrame(Player: Player, Realm: Model, Request: any, Asset: PVInstance,
	Ignore: PVInstance?): (CFrame?, string?)
	if typeof(Request) ~= "table" or not Building.IsVector(Request.Position) or not Building.IsVector(Request.Normal)
		or typeof(Request.Angle) ~= "number" or not Building.IsFinite(Request.Angle)
		or Request.Angle % Building.RotationStep ~= 0 or math.abs(Request.Normal.Magnitude - 1) > 0.01 then
		return nil, "Invalid placement."
	end
	local Bounds = Building.GetBounds(Asset)
	if not Building.IsInside(Realm, CFrame.new(Request.Position), Vector3.zero) then
		return nil, "Place the object inside your realm."
	end

	local Exclude: { Instance } = {}
	if Player.Character then
		table.insert(Exclude, Player.Character)
	end
	if Ignore then
		table.insert(Exclude, Ignore)
	end
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = Exclude
	Params.RespectCanCollide = true
	local Hit = workspace:Raycast(Request.Position + Request.Normal * 0.5, -Request.Normal * 1, Params)
	if not Hit or (Hit.Position - Request.Position).Magnitude > 0.15 or Hit.Normal:Dot(Request.Normal) < 0.98
		or not Building.CanUseSurface(Realm, Hit, Asset) then
		return nil, "This object needs a suitable surface."
	end

	local Frame = Building.GetPlacement(Asset, Bounds, Hit, Request.Angle % 360, Realm:GetPivot().Position)
	if not Building.IsClear(Realm, Bounds, Frame, Exclude) then
		return nil, "This space is blocked or outside your realm."
	end

	return Frame
end

function RealmBuildingService:Place(Player: Player, Request: any): (boolean, string?)
	if not self:CanEdit(Player) or Sessions[Player] ~= RealmService:GetRealm(Player) then
		return false, "Realm editor is no longer available."
	end
	local Realm = Sessions[Player]
	local Data = DataService:GetData(Player)
	local Asset = typeof(Request) == "table" and Building.Resolve(Request.Asset)
	if not Data or not Asset or #Building.GetParts(Asset) == 0 then
		return false, "Object is unavailable."
	end
	local Frame, Reason = self:GetPlacementFrame(Player, Realm, Request, Asset, nil)
	if not Frame then
		return false, Reason
	end

	local Objects = Realm:FindFirstChild("PlacedObjects")
	if not Objects then
		Objects = Instance.new("Folder")
		Objects.Name = "PlacedObjects"
		Objects.Parent = Realm
	end
	if #Objects:GetChildren() >= Building.MaxObjects or #Data.Realm.PlacedObjects >= Building.MaxObjects then
		return false, "Your realm has reached its object limit."
	end

	local Object, RestoreTags = Building.Clone(Asset)
	Building.Prepare(Object, false)
	local Id = HttpService:GenerateGUID(false)
	Object:SetAttribute("PlacementId", Id)
	Object:SetAttribute("RealmId", Player.UserId)
	Object:SetAttribute("PlacementAngle", Request.Angle % 360)
	Object:PivotTo(Frame)
	local Cost = Resources.GetCost(Asset)
	if not Cost then
		Object:Destroy()
		return false, "This object has an invalid resource cost."
	end
	local Paid, PaymentReason = ResourceService:Spend(Player, Cost, false)
	if not Paid then
		Object:Destroy()
		return false, PaymentReason
	end
	Object.Parent = Objects
	RestoreTags()
	local Record = {
		Id = Id,
		Asset = { Tab = Request.Asset.Tab, Category = Request.Asset.Category, Name = Request.Asset.Name },
		Transform = { Realm:GetPivot():ToObjectSpace(Frame):GetComponents() },
		ResourcesSpent = Cost,
		Angle = Request.Angle % 360,
	}
	table.insert(Data.Realm.PlacedObjects, Record)
	HistoryService:Record(Player, Realm, { Kind = "Place", Record = Record, Index = #Data.Realm.PlacedObjects, Refund = {} })
	self:PublishHistory(Player)

	return true
end

function RealmBuildingService:Move(Player: Player, Request: any): (boolean, string?)
	if not self:CanEdit(Player) or Sessions[Player] ~= RealmService:GetRealm(Player) then
		return false, "Realm editor is no longer available."
	end
	if typeof(Request) ~= "table" or typeof(Request.PlacementId) ~= "string" or #Request.PlacementId > 64 then
		return false, "Invalid object."
	end
	local Realm = Sessions[Player]
	local Data = DataService:GetData(Player)
	local Object = GetOwnedObject(Realm, Player, Request.PlacementId)
	local Record = Data and FindRecord(Data, Request.PlacementId)
	if not Object or not Record then
		return false, "Object is unavailable."
	end
	local Frame, Reason = self:GetPlacementFrame(Player, Realm, Request, Object, Object)
	if not Frame then
		return false, Reason
	end
	local Previous = Object:GetPivot()
	if (Frame.Position - Previous.Position).Magnitude < 0.001 and Frame.LookVector:Dot(Previous.LookVector) > 0.999999
		and Frame.UpVector:Dot(Previous.UpVector) > 0.999999 then
		return true
	end
	local Before = DeepCopy(Record.Transform)
	local BeforeAngle = Record.Angle
	CommitMove(Realm, Object, Record, Frame, Request.Angle % 360)
	HistoryService:Record(Player, Realm, {
		Kind = "Move", Record = { Id = Record.Id }, Refund = {},
		Before = Before, After = Record.Transform, BeforeAngle = BeforeAngle, AfterAngle = Record.Angle,
	})
	self:PublishHistory(Player)

	return true
end

function RealmBuildingService:GetDeletionRefund(ResourcesSpent: any): { [string]: number }
	local Refund = {}
	if typeof(ResourcesSpent) ~= "table" then
		return Refund
	end

	for Resource, Amount in ResourcesSpent do
		if typeof(Resource) == "string" and typeof(Amount) == "number" and Building.IsFinite(Amount)
			and Amount > 0 and Amount % 1 == 0 and Resources.IsValid({ [Resource] = Amount }) then
			local Returned = math.floor(Amount * 7 / 10)
			if Returned > 0 then
				Refund[Resource] = Returned
			end
		end
	end

	return Refund
end

function RealmBuildingService:Delete(Player: Player, PlacementId: any): (boolean, string?, { [string]: number }?)
	if not self:CanEdit(Player) or Sessions[Player] ~= RealmService:GetRealm(Player) then
		return false, "Realm editor is no longer available."
	end
	if typeof(PlacementId) ~= "string" or #PlacementId > 64 then
		return false, "Invalid object."
	end

	local Realm = Sessions[Player]
	local Data = DataService:GetData(Player)
	local Objects = Realm:FindFirstChild("PlacedObjects")
	if not Data or not Objects then
		return false, "Object is unavailable."
	end
	local Object = GetOwnedObject(Realm, Player, PlacementId)
	if not Object then
		return false, "Object is unavailable."
	end

	for Index, Record in Data.Realm.PlacedObjects do
		if Record.Id ~= PlacementId then
			continue
		end

		local Refund = self:GetDeletionRefund(Record.ResourcesSpent)
		HistoryService:Record(Player, Realm, { Kind = "Delete", Record = Record, Index = Index, Refund = Refund })
		table.remove(Data.Realm.PlacedObjects, Index)
		Object:Destroy()
		ResourceService:Credit(Player, Refund)
		self:PublishHistory(Player)

		return true, nil, Refund
	end

	return false, "Object has no saved placement."
end

function RealmBuildingService:RestoreRecord(Player: Player, Realm: Model, Record: any, Index: number): (boolean, string?)
	local Data = DataService:GetData(Player)
	local Objects = Realm:FindFirstChild("PlacedObjects")
	local Asset = Building.Resolve(Record.Asset)
	if not Data or not Objects or not Asset then
		return false, "The original object is unavailable."
	end
	if #Data.Realm.PlacedObjects >= Building.MaxObjects or #Objects:GetChildren() >= Building.MaxObjects then
		return false, "Your realm has reached its object limit."
	end
	if GetOwnedObject(Realm, Player, Record.Id) then
		return false, "The object already exists."
	end
	for _, Existing in Data.Realm.PlacedObjects do
		if Existing.Id == Record.Id then
			return false, "The object already exists."
		end
	end

	local Frame = Realm:GetPivot() * CFrame.new(table.unpack(Record.Transform))
	local Exclude: { Instance } = if Player.Character then { Player.Character } else {}
	if not Building.IsClear(Realm, Building.GetBounds(Asset), Frame, Exclude) then
		return false, "The original position is blocked or outside your realm."
	end
	local Object, RestoreTags = Building.Clone(Asset)
	Building.Prepare(Object, false)
	Object:SetAttribute("PlacementId", Record.Id)
	Object:SetAttribute("RealmId", Player.UserId)
	Object:SetAttribute("PlacementAngle", Record.Angle)
	Object:PivotTo(Frame)
	Object.Parent = Objects
	RestoreTags()
	table.insert(Data.Realm.PlacedObjects, math.clamp(Index, 1, #Data.Realm.PlacedObjects + 1), DeepCopy(Record))

	return true
end

function RealmBuildingService:Replay(Player: Player, Realm: Model, Action: any, Undo: boolean): (boolean, string?)
	local Data = DataService:GetData(Player)
	if not Data then
		return false, "Your realm data is unavailable."
	end
	if Action.Kind == "Move" then
		local Object = GetOwnedObject(Realm, Player, Action.Record.Id)
		local Record = FindRecord(Data, Action.Record.Id)
		if not Object or not Record then
			return false, "Object is unavailable."
		end
		local Transform = if Undo then Action.Before else Action.After
		local Frame = Realm:GetPivot() * CFrame.new(table.unpack(Transform))
		local Exclude: { Instance } = { Object }
		if Player.Character then
			table.insert(Exclude, Player.Character)
		end
		if not Building.IsClear(Realm, Building.GetBounds(Object), Frame, Exclude) then
			return false, "The original position is blocked or outside your realm."
		end
		local Angle = if Undo then Action.BeforeAngle else Action.AfterAngle
		CommitMove(Realm, Object, Record, Frame, Angle)

		return true
	end
	local Restore = (Action.Kind == "Delete" and Undo) or (Action.Kind == "Place" and not Undo)
	local Cost = if Action.Kind == "Place" then (Action.Record.ResourcesSpent or {}) else Action.Refund
	if Restore then
		local Available, Reason = ResourceService:CanSpend(Player, Cost, true)
		if not Available then
			return false, Reason
		end
	end
	if Restore then
		local Success, Reason = self:RestoreRecord(Player, Realm, Action.Record, Action.Index)
		if not Success then
			return false, Reason
		end
		ResourceService:Spend(Player, Cost, true)
	else
		local Object = GetOwnedObject(Realm, Player, Action.Record.Id)
		if not Object then
			return false, "The object is no longer available."
		end
		local Found: number? = nil
		for Index, Record in Data.Realm.PlacedObjects do
			if Record.Id == Action.Record.Id then
				Found = Index
				break
			end
		end
		if not Found then
			return false, "Object has no saved placement."
		end
		table.remove(Data.Realm.PlacedObjects, Found)
		Object:Destroy()
		ResourceService:Credit(Player, Cost)
	end

	return true
end

function RealmBuildingService:ChangeHistory(Player: Player, Direction: string): (boolean, string?)
	if not self:CanEdit(Player) or Sessions[Player] ~= RealmService:GetRealm(Player) then
		return false, "Realm editor is no longer available."
	end

	local Realm = Sessions[Player]
	local Success, Reason = HistoryService:Apply(Player, Realm, Direction, function(Action: any, Undo: boolean): (boolean, string?)
		return self:Replay(Player, Realm, Action, Undo)
	end)
	self:PublishHistory(Player)

	return Success, Reason
end

function RealmBuildingService.KnitInit()
	RealmService = Knit.GetService("RealmService")
	DataService = Knit.GetService("DataService")
	HistoryService = Knit.GetService("RealmHistoryService")
	ResourceService = Knit.GetService("RealmResourceService")
end

function RealmBuildingService.KnitStart()
	RealmBuildingService.Client.Editing:Connect(function(Player: Player, Active: any)
		Sessions[Player] = if Active == true and RealmBuildingService:CanEdit(Player) then RealmService:GetRealm(Player) else nil
		if Sessions[Player] then
			RealmBuildingService:PublishHistory(Player)
		end
	end)
	RealmBuildingService.Client.Place:Connect(function(Player: Player, Request: any)
		if typeof(Request) ~= "table" or typeof(Request.Id) ~= "number" or not Building.IsFinite(Request.Id) then
			return
		end
		local Now = os.clock()
		if LastRequest[Player] and Now - LastRequest[Player] < 0.15 then
			RealmBuildingService.Client.PlacementResult:Fire(Player, Request.Id, false, "Please wait before placing another object.")
			return
		end
		LastRequest[Player] = Now

		local Success, Reason = RealmBuildingService:Place(Player, Request)
		RealmBuildingService.Client.PlacementResult:Fire(Player, Request.Id, Success, Reason)
	end)
	RealmBuildingService.Client.Delete:Connect(function(Player: Player, Request: any)
		if typeof(Request) ~= "table" or typeof(Request.Id) ~= "number" or not Building.IsFinite(Request.Id) then
			return
		end
		local Now = os.clock()
		if LastRequest[Player] and Now - LastRequest[Player] < 0.15 then
			RealmBuildingService.Client.DeletionResult:Fire(Player, Request.Id, false, "Please wait before deleting another object.")
			return
		end
		LastRequest[Player] = Now

		local Success, Reason, Refund = RealmBuildingService:Delete(Player, Request.PlacementId)
		RealmBuildingService.Client.DeletionResult:Fire(Player, Request.Id, Success, Reason, Refund)
	end)
	RealmBuildingService.Client.Move:Connect(function(Player: Player, Request: any)
		if typeof(Request) ~= "table" or typeof(Request.Id) ~= "number" or not Building.IsFinite(Request.Id) then
			return
		end
		local Now = os.clock()
		if LastRequest[Player] and Now - LastRequest[Player] < 0.15 then
			RealmBuildingService.Client.MovementResult:Fire(Player, Request.Id, false, "Please wait before moving another object.")
			return
		end
		LastRequest[Player] = Now

		local Success, Reason = RealmBuildingService:Move(Player, Request)
		RealmBuildingService.Client.MovementResult:Fire(Player, Request.Id, Success, Reason)
	end)
	RealmBuildingService.Client.HistoryAction:Connect(function(Player: Player, Request: any)
		if typeof(Request) ~= "table" or typeof(Request.Id) ~= "number" or not Building.IsFinite(Request.Id)
			or (Request.Direction ~= "Undo" and Request.Direction ~= "Redo") then
			return
		end
		local Now = os.clock()
		if LastRequest[Player] and Now - LastRequest[Player] < 0.15 then
			RealmBuildingService.Client.HistoryResult:Fire(Player, Request.Id, false, "Please wait before changing history again.")
			return
		end
		LastRequest[Player] = Now

		local Success, Reason = RealmBuildingService:ChangeHistory(Player, Request.Direction)
		RealmBuildingService.Client.HistoryResult:Fire(Player, Request.Id, Success, Reason)
	end)
	Players.PlayerRemoving:Connect(function(Player: Player)
		Sessions[Player] = nil
		LastRequest[Player] = nil
	end)
end

return RealmBuildingService
