-- Run the production controller against an isolated world and foliage tags.
return function(Controller: any, Context: any): string
	local World = Context.World
	local Tags = Context.Tags
	local Checks = 0
	local LeafColor = Color3.fromRGB(80, 130, 60)
	local SurfaceColor = Color3.fromRGB(110, 170, 90)
	local WinterColors = {
		Color3.fromRGB(105, 124, 132), Color3.fromRGB(122, 140, 147),
		Color3.fromRGB(140, 156, 162), Color3.fromRGB(158, 171, 176),
	}

	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end

	local function Appearance(Parent: MeshPart): SurfaceAppearance
		local Surface = Instance.new("SurfaceAppearance")
		Surface.Color = SurfaceColor
		Surface.Parent = Parent
		return Surface
	end

	local function Leaf(Parent: Instance, Tag: string?): MeshPart
		local Part = Instance.new("MeshPart")
		Part.Name = "Canopy"
		Part.Material = Enum.Material.Ground
		Part.Color = LeafColor
		if Tag then
			Part:AddTag(Tag)
		end
		Part.Parent = Parent
		return Part
	end

	local Tree = Instance.new("Model")
	Tree.Name = "Tree_11"
	Tree.Parent = World
	local Initial = Leaf(Tree, Tags.WindShake)
	local InitialSurface = Appearance(Initial)
	local Trunk = Instance.new("Part")
	Trunk.Name = "Trunk"
	Trunk.Material = Enum.Material.Wood
	Trunk.Color = Color3.fromRGB(90, 60, 30)
	Trunk.Parent = Tree
	local TrunkColor = Trunk.Color

	Controller.KnitStart()
	Check(Initial.Color == LeafColor and Initial.Material == Enum.Material.Ground, "Startup must wait for the season attribute without polling")

	local DuringScan: MeshPart?
	Context.OnScan = function()
		DuringScan = Leaf(World, Tags.Grass)
	end
	World:SetAttribute("Season", "Winter")
	task.wait(0.05)
	Check(Initial.Material == Enum.Material.Snow, "Initial foliage must receive winter materials")
	Check(table.find(WinterColors, InitialSurface.Color) ~= nil, "Initial leaf surfaces must receive the winter palette")
	Check(Initial:GetAttribute("DefaultMaterial") == "Ground", "The original material must be saved before seasonal changes")
	Check(Initial:GetAttribute("SummerColor") == LeafColor and InitialSurface:GetAttribute("SummerColor") == SurfaceColor, "Part and surface summer colors must be saved independently")
	Check(DuringScan ~= nil and DuringScan.Material == Enum.Material.Snow, "Tags added during the initial scan must not be missed")
	Check(Trunk.Material == Enum.Material.Wood and Trunk.Color == TrunkColor, "Untagged tree trunks must remain unchanged")

	local LateSurfaceLeaf = Leaf(World, Tags.Leaves)
	task.wait(0.05)
	local LateSurface = Appearance(LateSurfaceLeaf)
	task.wait(0.05)
	Check(table.find(WinterColors, LateSurface.Color) ~= nil, "A SurfaceAppearance arriving after the leaf must receive the current season")
	Check(LateSurface:GetAttribute("SummerColor") == SurfaceColor, "Late surfaces must preserve their authored summer color")

	local Streamed = Instance.new("Model")
	Streamed.Name = "StreamedTree"
	Streamed:AddTag(Tags.Leaves)
	local StreamedLeaf = Leaf(Streamed)
	local StreamedSurface = Appearance(StreamedLeaf)
	Streamed.Parent = World
	task.wait(0.05)
	Check(StreamedLeaf.Material == Enum.Material.Snow and table.find(WinterColors, StreamedSurface.Color) ~= nil, "A pre-tagged tree entering the world must update all foliage descendants")

	local Model = Instance.new("Model")
	Model.Parent = World
	local ModelLeaf = Leaf(Model)
	local ModelSurface = Appearance(ModelLeaf)
	Model:AddTag(Tags.WindShake)
	task.wait(0.05)
	Check(ModelLeaf.Material == Enum.Material.Snow and table.find(WinterColors, ModelSurface.Color) ~= nil, "Tags applied to an existing model must update child parts and surfaces")

	World:SetAttribute("Season", "Spring")
	task.wait(0.05)
	Check(Initial.Color == Color3.fromRGB(153, 23, 23) and InitialSurface.Color == Initial.Color, "Tree-specific spring colors must remain supported")
	local SpringColor = Model:GetAttribute("SpringColor")
	Check(typeof(SpringColor) == "Color3", "Spring models must retain a shared base color")
	local SpringSurface = Appearance(Leaf(Model))
	task.wait(0.05)
	Check(Model:GetAttribute("SpringColor") == SpringColor, "Late spring leaves must reuse their model's spring color")
	Check(SpringSurface.Color ~= SurfaceColor, "Late spring surfaces must receive the active foliage color")

	World:SetAttribute("Season", "Summer")
	task.wait(0.05)
	Check(Initial.Material == Enum.Material.Ground and Initial.Color == LeafColor, "Summer must restore the authored part material and color")
	Check(InitialSurface.Color == SurfaceColor and LateSurface.Color == SurfaceColor, "Summer must restore both initial and late surface colors")
	Check(StreamedLeaf.Material == Enum.Material.Ground and ModelLeaf.Material == Enum.Material.Ground, "Summer must restore foliage tagged through a parent model")

	World:SetAttribute("Season", "Autumn")
	World:SetAttribute("Season", "Winter")
	Streamed.Parent = nil
	Streamed.Parent = World
	task.wait(0.05)
	Check(StreamedLeaf.Material == Enum.Material.Snow and table.find(WinterColors, StreamedSurface.Color) ~= nil, "Streamed-in foliage must use the latest season after rapid changes")
	Check(StreamedLeaf:GetAttribute("SummerColor") == LeafColor, "Streaming must not replace saved summer colors with seasonal colors")

	World:SetAttribute("Season", "Summer")
	task.wait(0.05)
	Check(StreamedLeaf.Color == LeafColor and StreamedSurface.Color == SurfaceColor, "Repeated season cycles must restore original streamed foliage")

	World:SetAttribute("Season", "Winter")
	task.wait(0.05)
	local Outside = Instance.new("Model")
	local OutsideLeaf = Leaf(Outside, Tags.WindShake)
	local OutsideSurface = Appearance(OutsideLeaf)
	task.wait(0.05)
	Check(OutsideLeaf.Color == LeafColor and OutsideSurface.Color == SurfaceColor, "Foliage outside the world must not be modified")
	Outside:Destroy()

	local Destroyed = Leaf(World, Tags.Leaves)
	Destroyed:Destroy()
	task.wait(0.05)
	Check(Trunk.Material == Enum.Material.Wood and Trunk.Color == TrunkColor, "Streaming and season changes must preserve non-foliage parts")

	return tostring(Checks) .. " seasonal foliage loading checks passed"
end
