local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.TreeCuttingConfig)
local TreeCuttingMath = {}
local Up = Vector3.yAxis

export type Plane = { Normal: Vector3, Distance: number }
export type Cut = {
	Center: Vector3,
	Direction: Vector3,
	Radius: number,
	Core: number,
	Depth: number,
	Width: number,
	Height: number,
	Felling: boolean?,
}

function TreeCuttingMath.GetMaxHits(Diameter: number): number
	local Alpha = math.clamp((Diameter - Config.ThinDiameter) / (Config.ThickDiameter - Config.ThinDiameter), 0, 1)
	return math.round(Config.MinHits + Alpha * (Config.MaxHits - Config.MinHits))
end

function TreeCuttingMath.GetDirectionIndex(Direction: Vector3): number
	local Angle = math.atan2(Direction.Z, Direction.X)
	return math.round(Angle * Config.DirectionCount / (math.pi * 2)) % Config.DirectionCount + 1
end

function TreeCuttingMath.GetDirection(Index: number): Vector3
	local Angle = (Index - 1) * math.pi * 2 / Config.DirectionCount
	return Vector3.new(math.cos(Angle), 0, math.sin(Angle))
end

function TreeCuttingMath.GetDepth(Radius: number, Core: number, Hits: number, MaxHits: number): number
	local Progress = math.clamp((Hits - 1) / math.max(1, MaxHits - 2), 0, 1)
	return (Radius - Core) * (Config.FirstCutFraction + (1 - Config.FirstCutFraction) * Progress)
end

function TreeCuttingMath.GetOpening(Radius: number, Hits: number, MaxHits: number): (number, number)
	local Progress = math.clamp((Hits - 1) / math.max(1, MaxHits - 2), 0, 1)
	local Height = math.clamp(Radius * Config.NotchHeightRatio, Config.MinNotchHeight, Config.MaxNotchHeight)
	return Height * (0.6 + 0.4 * Progress), Radius * Config.NotchWidthRatio * (0.7 + 0.3 * Progress)
end

function TreeCuttingMath.GetCutPlanes(Cut: Cut): { Plane }
	local Direction = Cut.Direction
	local Tangent = Up:Cross(Direction)
	local Inner = math.max(Cut.Core, Cut.Radius - Cut.Depth)
	local Slope = Cut.Height * 0.5 / math.max(Cut.Depth, 0.01)
	local Top = Vector3.yAxis - Direction * Slope
	local Bottom = -Vector3.yAxis - Direction * Slope

	return {
		{ Normal = Top, Distance = Top:Dot(Cut.Center) - Slope * Inner },
		{ Normal = Bottom, Distance = Bottom:Dot(Cut.Center) - Slope * Inner },
		{ Normal = Tangent, Distance = Tangent:Dot(Cut.Center) + Cut.Width * 0.5 },
		{ Normal = -Tangent, Distance = -Tangent:Dot(Cut.Center) + Cut.Width * 0.5 },
		{ Normal = Direction, Distance = Direction:Dot(Cut.Center) + Cut.Radius + 1 },
	}
end

function TreeCuttingMath.ToMeshPlane(Plane: Plane, Frame: CFrame, Scale: Vector3): Plane
	local Normal = Frame:VectorToObjectSpace(Plane.Normal) * Scale
	local Length = Normal.Magnitude

	return { Normal = Normal / Length, Distance = (Plane.Distance - Plane.Normal:Dot(Frame.Position)) / Length }
end

function TreeCuttingMath.GetFallPivot(
	Origin: CFrame,
	Point: Vector3,
	Axis: Vector3,
	Angle: number,
	Alpha: number
): CFrame
	local Progress = math.clamp(Alpha, 0, 1) ^ 2
	return CFrame.new(Point) * CFrame.fromAxisAngle(Axis, Angle * Progress) * CFrame.new(-Point) * Origin
end

return TreeCuttingMath
