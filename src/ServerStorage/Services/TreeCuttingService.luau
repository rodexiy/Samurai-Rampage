local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.TreeCuttingConfig)
local Math = require(ReplicatedStorage.Shared.Utils.TreeCuttingMath)

local TreeCuttingService = Knit.CreateService({
	Name = "TreeCuttingService",
	Client = { Cut = Knit.CreateSignal(), Felled = Knit.CreateSignal(), Prepare = Knit.CreateSignal() },
})

type Profile = { Center: Vector3, Radii: { number }, Core: number, Radius: number }
type State = { Profile: Profile, Hits: number, MaxHits: number, Sides: { number }, Weights: { number } }

local States: { [Model]: State } = {}
local Cooldowns: { [Player]: number } = {}
local ResourceService, RealmService, SoundEffectService, TreePhysicsService

local function IsTrunk(Part: BasePart): boolean
	return string.find(Part.Name, "Trunk", 1, true) ~= nil
end

local function GetTree(Part: BasePart): Model?
	local Ancestor = Part.Parent
	while Ancestor and Ancestor ~= workspace do
		if Ancestor:IsA("Model") then
			local Parent = Ancestor.Parent
			if Ancestor:HasTag("Tree") or (Parent and Parent.Name == "Trees") then
				return Ancestor
			end
		end

		Ancestor = Ancestor.Parent
	end

	return nil
end

local function GetTrunks(Tree: Model): { BasePart }
	local Parts = {}
	for _, Part in Tree:QueryDescendants("BasePart") :: { BasePart } do
		if IsTrunk(Part) then
			table.insert(Parts, Part)
		end
	end

	return Parts
end

local function GetBounds(Parts: { BasePart }): (Vector3, Vector3)
	local Min = Vector3.new(math.huge, math.huge, math.huge)
	local Max = -Min
	for _, Part in Parts do
		for X = -1, 1, 2 do
			for Y = -1, 1, 2 do
				for Z = -1, 1, 2 do
					local Point = Part.CFrame:PointToWorldSpace(Part.Size * Vector3.new(X, Y, Z) * 0.5)
					Min, Max = Min:Min(Point), Max:Max(Point)
				end
			end
		end
	end

	return Min, Max
end

local function GetProfile(Trunk: BasePart, Position: Vector3): Profile?
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Trunk }
	local Extent = Trunk.Size.Magnitude + 1
	local Center = Position

	for _, Direction in { Vector3.xAxis, Vector3.zAxis } do
		local A = workspace:Raycast(Center + Direction * Extent, -Direction * Extent * 2, Params)
		local B = workspace:Raycast(Center - Direction * Extent, Direction * Extent * 2, Params)
		if not A or not B then
			return nil
		end
		Center += Direction * (((A.Position + B.Position) * 0.5 - Center):Dot(Direction))
	end

	local Radii = {}
	local Radius = math.huge
	for Index = 1, Config.DirectionCount do
		local Direction = Math.GetDirection(Index)
		local Hit = workspace:Raycast(Center + Direction * Extent, -Direction * Extent * 2, Params)
		if not Hit then
			return nil
		end
		local Length = (Hit.Position - Center):Dot(Direction)
		if Length <= 0.05 then
			return nil
		end
		Radii[Index] = Length
		Radius = math.min(Radius, Length)
	end

	return { Center = Center, Radii = Radii, Radius = Radius, Core = Radius * Config.CoreRatio }
end

local function GetFallDirection(State: State, LastDirection: Vector3): Vector3
	local Sum = Vector3.zero
	local Strongest, StrongestWeight = LastDirection, 0
	for Index, Weight in State.Weights do
		local Direction = Math.GetDirection(Index)
		Sum += Direction * Weight
		if Weight > StrongestWeight then
			Strongest, StrongestWeight = Direction, Weight
		end
	end

	return if Sum.Magnitude > 0.01 then Sum.Unit else Strongest
end

function TreeCuttingService:Fell(Player: Player, Tree: Model, State: State, Direction: Vector3)
	local Template = Tree:Clone()
	local Origin = Tree:GetPivot()
	local Point = State.Profile.Center
	Tree:SetAttribute("Broken", true)

	local PreparedBody = Tree:FindFirstChild("TreePhysicsBody")
	for _, Part in Tree:QueryDescendants("BasePart") :: { BasePart } do
		if PreparedBody and Part:IsDescendantOf(PreparedBody) then
			continue
		end
		Part.Anchored = true
		Part.CanCollide = false
		Part.CanTouch = false
		Part:RemoveTag("WindShake")
	end

	-- The server collider is a clean upper trunk. Private notches stay on each client.
	local Body = TreePhysicsService:CreateBody(Tree, Point, State.Profile.Radius)
	local Started = workspace:GetServerTimeNow()
	Tree.WorldPivot = Origin
	Tree:SetAttribute("TreeFallOrigin", Origin)
	Tree:SetAttribute("TreeFallPoint", Point)
	Tree:SetAttribute("TreeFallStarted", Started)
	CollectionService:AddTag(Tree, "FelledTree")

	self.Client.Felled:FireAll(Tree, { Origin = Origin, Point = Point, Body = Body, Started = Started })
	TreePhysicsService:Release(Body, Direction)
	SoundEffectService:PlayRandomFromFolder("FallTree", true, Tree)
	task.spawn(function()
		ResourceService:BreakResource(Player, Tree, { Animate = false, RespawnTemplate = Template })
	end)

	task.delay(Config.FallDuration + Config.CanopyLifetimeAfterFall, function()
		for _, Part in Tree:QueryDescendants("BasePart") :: { BasePart } do
			if string.find(Part.Name, "Canopy", 1, true) then
				Part:Destroy()
			end
		end
	end)
	task.delay(Config.FallDuration + Config.TrunkLifetimeAfterFall, function()
		Tree:Destroy()
	end)
end

function TreeCuttingService:Hit(Player: Player, Tree: Model, Trunk: BasePart, Position: Vector3): boolean
	if not Tree:IsDescendantOf(workspace) or not Trunk:IsDescendantOf(Tree) or not IsTrunk(Trunk) then
		return false
	end

	local Character = Player.Character
	local Root = Character and Character.PrimaryPart
	if not Root or Tree:GetAttribute("Broken") or not RealmService:HasOwnership(Player, Tree) then
		return false
	end
	if (Root.Position - Position).Magnitude > Config.AxeReach + 0.1 then
		return false
	end

	local Trunks = GetTrunks(Tree)
	local Min = GetBounds(Trunks)
	local Height = Position.Y - Min.Y
	if Height < 0 or Height > Config.MaxCutHeight then
		return false
	end

	local State = States[Tree]
	if not State then
		local Profile = GetProfile(Trunk, Position)
		if not Profile then
			return false
		end
		State = { Profile = Profile, Hits = 0, MaxHits = Math.GetMaxHits(Profile.Radius * 2), Sides = {}, Weights = {} }
		States[Tree] = State
		Tree:SetAttribute("MaxHealth", State.MaxHits)
		Tree.Destroying:Once(function()
			States[Tree] = nil
		end)
		TreePhysicsService:Prepare(Tree, Profile.Center, Profile.Radius)
		-- Only the shared cutting height is broadcast; notch geometry remains private.
		self.Client.Prepare:FireAll(Tree, Profile.Center, Player)
	end

	local Difference = Root.Position - State.Profile.Center
	local Direction = Vector3.new(Difference.X, 0, Difference.Z)
	if Direction.Magnitude <= 0.01 then
		return false
	end
	local Index = Math.GetDirectionIndex(Direction)
	local SideHits = (State.Sides[Index] or 0) + 1
	local Radius = State.Profile.Radii[Index]
	local Depth = Math.GetDepth(Radius, State.Profile.Core, SideHits, State.MaxHits)
	local Opening, Width = Math.GetOpening(State.Profile.Radius, SideHits, State.MaxHits)
	local PreviousDepth = if SideHits > 1
		then Math.GetDepth(Radius, State.Profile.Core, SideHits - 1, State.MaxHits)
		else 0
	State.Hits += 1
	State.Sides[Index] = SideHits
	State.Weights[Index] = (State.Weights[Index] or 0) + Depth * Depth - PreviousDepth * PreviousDepth
	Tree:SetAttribute("Health", State.MaxHits - State.Hits)

	-- Geometry and cut directions are deliberately sent only to the hitter.
	self.Client.Cut:Fire(Player, Tree, {
		Center = State.Profile.Center,
		Direction = Math.GetDirection(Index),
		Radius = Radius,
		Core = State.Profile.Core,
		Depth = Depth,
		Width = Width,
		Height = Opening,
		Felling = State.Hits >= State.MaxHits,
	})
	SoundEffectService:PlayRandomFromFolder("ChopTree", true, Tree)

	if State.Hits >= State.MaxHits then
		self:Fell(Player, Tree, State, GetFallDirection(State, Direction.Unit))
	end
	return true
end

function TreeCuttingService:Swing(Player: Player, Character: Model)
	local Now = os.clock()
	if Now < (Cooldowns[Player] or 0) then
		return
	end
	Cooldowns[Player] = Now + Config.SwingCooldown
	local Filter: { Instance } = CollectionService:GetTagged("Tree")
	local Map = workspace:FindFirstChild("Map")
	local Vegetation = Map and Map:FindFirstChild("Vegetation")
	local Trees = Vegetation and Vegetation:FindFirstChild("Trees")
	if Trees then
		table.insert(Filter, Trees)
	end
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = Filter
	local RayParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Include
	local Root = Character.PrimaryPart
	if not Root then
		return
	end
	local Seen: { [Model]: boolean } = {}

	for _, Part in workspace:GetPartBoundsInBox(Character:GetPivot() * Config.AxeBoxOffset, Config.AxeBoxSize, Params) do
		if not IsTrunk(Part) then
			continue
		end
		local Tree = GetTree(Part)
		if not Tree or Seen[Tree] then
			continue
		end
		RayParams.FilterDescendantsInstances = GetTrunks(Tree)
		local Target = Vector3.new(Part.Position.X, Root.Position.Y, Part.Position.Z)
		local Offset = Target - Root.Position
		if Offset.Magnitude < 0.01 then
			continue
		end
		local Hit = workspace:Raycast(Root.Position, Offset.Unit * Config.AxeReach, RayParams)
		if Hit and self:Hit(Player, Tree, Hit.Instance, Hit.Position) then
			Seen[Tree] = true
		end
	end
end

function TreeCuttingService.KnitInit()
	ResourceService = Knit.GetService("ResourceService")
	RealmService = Knit.GetService("RealmService")
	SoundEffectService = Knit.GetService("SoundEffectService")
	TreePhysicsService = Knit.GetService("TreePhysicsService")
end

function TreeCuttingService.KnitStart()
	Players.PlayerRemoving:Connect(function(Player: Player)
		Cooldowns[Player] = nil
	end)
end

return TreeCuttingService
