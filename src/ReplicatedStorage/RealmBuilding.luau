local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local RealmBuilding = {
	GridEnabled = false,
	GridSize = 1,
	RotationStep = 15,
	MaxObjects = 1000,
	BlockedStates = {
		"Died", "Downed", "Ragdoll", "InCombat", "RealmTeleporting", "InWisdomWorld",
		"Mounted", "InHorse", "Climbing", "WallRunning", "Vaulting", "Meditating",
		"Attack", "Attacking", "Blocking", "BowDrawing", "SkillLockMovement",
	},
}

export type AssetKey = { Tab: string, Category: string, Name: string }
export type Bounds = { Offset: CFrame, Size: Vector3 }

local DecorationAliases = {
	["Utility/Workstations/Drying Rack"] = true,
	["Utility/Workstations/Drying Rack 2"] = true,
	["Utility/Workstations/Drying Rack 3"] = true,
	["Utility/Water/Well"] = true,
	["Utility/Storage/Wood Crate"] = true,
}

function RealmBuilding.Clone(Object: PVInstance): (PVInstance, () -> ())
	local Marker = "RealmClone_" .. string.gsub(HttpService:GenerateGUID(false), "-", "")
	local Tagged: { { Object: Instance, Tags: { string } } } = {}
	local Instances = Object:QueryDescendants("Instance")
	table.insert(Instances, Object)
	for _, Instance in Instances do
		local Tags = {}
		for _, Tag in { "WindShake", "SmartBone" } do
			if CollectionService:HasTag(Instance, Tag) then
				table.insert(Tags, Tag)
				CollectionService:RemoveTag(Instance, Tag)
			end
		end
		if #Tags > 0 then
			table.insert(Tagged, { Object = Instance, Tags = Tags })
			Instance:SetAttribute(Marker, #Tagged)
		end
	end

	local Success, Copy = pcall(function(): PVInstance?
		return Object:Clone()
	end)
	for _, Entry in Tagged do
		Entry.Object:SetAttribute(Marker, nil)
		for _, Tag in Entry.Tags do
			CollectionService:AddTag(Entry.Object, Tag)
		end
	end
	assert(Success and Copy, "Unable to clone realm asset: " .. Object.Name)

	local Restore: { { Object: Instance, Tags: { string } } } = {}
	local ClonedInstances = Copy:QueryDescendants("Instance")
	table.insert(ClonedInstances, Copy)
	for _, Instance in ClonedInstances do
		local Id = Instance:GetAttribute(Marker)
		if Id then
			Instance:SetAttribute(Marker, nil)
			table.insert(Restore, { Object = Instance, Tags = Tagged[Id].Tags })
		end
	end
	local Restored = false
	local function RestoreTags()
		if Restored then
			return
		end
		Restored = true
		for _, Entry in Restore do
			if Entry.Object == Copy or Entry.Object:IsDescendantOf(Copy) then
				for _, Tag in Entry.Tags do
					CollectionService:AddTag(Entry.Object, Tag)
				end
			end
		end
	end

	return Copy, RestoreTags
end

function RealmBuilding.GetRoot(): Folder?
	return ReplicatedStorage.Assets:FindFirstChild("RealmAssets") :: Folder?
end

function RealmBuilding.Resolve(Key: AssetKey): PVInstance?
	if typeof(Key) ~= "table" or (Key.Tab ~= "Decorations" and Key.Tab ~= "Utility")
		or typeof(Key.Category) ~= "string" or typeof(Key.Name) ~= "string" then
		return nil
	end

	local Root = RealmBuilding.GetRoot()
	local Tab = Root and Root:FindFirstChild(Key.Tab)
	local Category = Tab and Tab:FindFirstChild(Key.Category)
	local Asset = Category and Category:FindFirstChild(Key.Name)
	-- Keep previously saved placements valid after moving these props into Decorations.
	if not Asset and Root and DecorationAliases[Key.Tab .. "/" .. Key.Category .. "/" .. Key.Name] then
		local Decorations = Root:FindFirstChild("Decorations")
		local Props = Decorations and Decorations:FindFirstChild("Props")
		Asset = Props and Props:FindFirstChild(Key.Name)
	end

	return if Asset and (Asset:IsA("Model") or Asset:IsA("BasePart")) then Asset else nil
end

function RealmBuilding.GetParts(Object: PVInstance): { BasePart }
	local Parts = Object:QueryDescendants("BasePart") :: { BasePart }
	if Object:IsA("BasePart") then
		table.insert(Parts, Object)
	end

	return Parts
end

function RealmBuilding.GetBounds(Object: PVInstance): Bounds
	local Parts = RealmBuilding.GetParts(Object)
	local Visible = {}
	for _, Part in Parts do
		if Part.Transparency < 1 or Part.CanCollide then
			table.insert(Visible, Part)
		end
	end
	if #Visible > 0 and #Visible < #Parts then
		local Pivot = Object:GetPivot()
		local Low, High = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, Part in Visible do
			local Local = Pivot:ToObjectSpace(Part.CFrame)
			local Half = Part.Size / 2
			for X = -1, 1, 2 do
				for Y = -1, 1, 2 do
					for Z = -1, 1, 2 do
						local Point = Local:PointToWorldSpace(Half * Vector3.new(X, Y, Z))
						Low, High = Low:Min(Point), High:Max(Point)
					end
				end
			end
		end

		return { Offset = CFrame.new((Low + High) / 2), Size = High - Low }
	end

	local Frame, Size
	if Object:IsA("Model") then
		Frame, Size = Object:GetBoundingBox()
	else
		local Part = Object :: BasePart
		Frame, Size = Part.CFrame, Part.Size
	end

	return { Offset = Object:GetPivot():ToObjectSpace(Frame), Size = Size }
end

function RealmBuilding.IsFinite(Value: number): boolean
	return Value == Value and math.abs(Value) < 10000000
end

function RealmBuilding.IsVector(Value: any): boolean
	return typeof(Value) == "Vector3" and RealmBuilding.IsFinite(Value.X)
		and RealmBuilding.IsFinite(Value.Y) and RealmBuilding.IsFinite(Value.Z)
end

function RealmBuilding.IsInside(Realm: Model, Frame: CFrame, Size: Vector3): boolean
	local Center, Extent = Realm:GetAttribute("TerrainCenter"), Realm:GetAttribute("TerrainSize")
	if typeof(Center) ~= "Vector3" or typeof(Extent) ~= "Vector3" then
		return false
	end

	for X = -1, 1, 2 do
		for Y = -1, 1, 2 do
			for Z = -1, 1, 2 do
				local Point = Frame:PointToWorldSpace(Size * Vector3.new(X, Y, Z) / 2) - Center
				if math.abs(Point.X) > Extent.X / 2 or math.abs(Point.Z) > Extent.Z / 2
					or math.abs(Point.Y) > Extent.Y / 2 + 128 then
					return false
				end
			end
		end
	end

	return true
end

function RealmBuilding.CanUseSurface(Realm: Model, Hit: RaycastResult, Asset: PVInstance): boolean
	local Wall = Asset:GetAttribute("PlacementType") == "Wall"
	if (Wall and math.abs(Hit.Normal.Y) > 0.2) or (not Wall and Hit.Normal.Y < 0.7) then
		return false
	end

	if Hit.Instance == workspace.Terrain then
		return not Wall and Hit.Material ~= Enum.Material.Water
	end
	if not Hit.Instance:IsDescendantOf(Realm) then
		return false
	end

	local Players = Realm:FindFirstChild("Players")
	if Players and Hit.Instance:IsDescendantOf(Players) then
		return false
	end

	local Objects = Realm:FindFirstChild("PlacedObjects")
	local Current: Instance? = Hit.Instance
	while Current and Current ~= Realm do
		if Current:GetAttribute("PlacementSurface") == (if Wall then "Wall" else "Floor") then
			return true
		end
		if Objects and Current.Parent == Objects then
			return Current:GetAttribute(if Wall then "SupportsWallPlacement" else "SupportsPlacement") == true
		end
		Current = Current.Parent
	end

	return true
end

function RealmBuilding.GetPlacement(Asset: PVInstance, Bounds: Bounds, Hit: RaycastResult, Angle: number, Origin: Vector3): CFrame
	local Wall = Asset:GetAttribute("PlacementType") == "Wall"
	local Normal = if Wall then Hit.Normal else Vector3.yAxis
	local Rotation = if Wall then CFrame.lookAt(Vector3.zero, Normal) * CFrame.Angles(0, 0, -math.rad(Angle))
		else CFrame.Angles(0, -math.rad(Angle), 0)
	local Point = Hit.Position
	if RealmBuilding.GridEnabled then
		local PlaneOrigin = Origin + Normal * (Point - Origin):Dot(Normal)
		local Surface = if Wall then CFrame.lookAt(PlaneOrigin, PlaneOrigin + Normal) else CFrame.new(Origin)
		local Local = Surface:PointToObjectSpace(Point)
		local Step = RealmBuilding.GridSize
		Local = if Wall then Vector3.new(math.round(Local.X / Step) * Step, math.round(Local.Y / Step) * Step, Local.Z)
			else Vector3.new(math.round(Local.X / Step) * Step, Local.Y, math.round(Local.Z / Step) * Step)
		Point = Surface:PointToWorldSpace(Local)
	end

	local BoxRotation = Rotation * Bounds.Offset.Rotation
	local Half = Bounds.Size / 2
	local Radius = math.abs(Normal:Dot(BoxRotation.RightVector)) * Half.X
		+ math.abs(Normal:Dot(BoxRotation.UpVector)) * Half.Y
		+ math.abs(Normal:Dot(BoxRotation.LookVector)) * Half.Z
	local Center = Point + Normal * (Radius + 0.025)

	return CFrame.new(Center - Rotation:VectorToWorldSpace(Bounds.Offset.Position)) * Rotation
end

function RealmBuilding.IsClear(Realm: Model, Bounds: Bounds, Frame: CFrame, Exclude: { Instance }): boolean
	if not RealmBuilding.IsInside(Realm, Frame * Bounds.Offset, Bounds.Size) then
		return false
	end

	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = Exclude
	Params.RespectCanCollide = false
	local Size = (Bounds.Size - Vector3.one * 0.08):Max(Vector3.one * 0.01)
	local Objects = Realm:FindFirstChild("PlacedObjects")
	for _, Part in workspace:GetPartBoundsInBox(Frame * Bounds.Offset, Size, Params) do
		if Part.CanCollide or (Objects and Part:IsDescendantOf(Objects) and Part.Transparency < 1) then
			return false
		end
	end

	return true
end

function RealmBuilding.Prepare(Object: PVInstance, Preview: boolean)
	for _, Script in Object:QueryDescendants("LuaSourceContainer") do
		Script:Destroy()
	end
	for _, Part in RealmBuilding.GetParts(Object) do
		Part.Anchored = true
		if Preview then
			Part.Transparency = 1 - (1 - Part.Transparency) * 0.5
			Part.CanCollide = false
			Part.CanTouch = false
			Part.CanQuery = false
			Part.CastShadow = false
		else
			Part.CanQuery = true
		end
	end
end

return RealmBuilding
