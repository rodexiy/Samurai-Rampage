local MobileControlLayout = {}

export type Position = { X: number, Y: number }
export type Layout = { [string]: Position }

local MAX_BUTTONS = 64
local MAX_NAME_LENGTH = 64

function MobileControlLayout.Validate(Value: any): Layout?
	if typeof(Value) ~= "table" then
		return nil
	end

	local Layout: Layout = {}
	local Count = 0
	for Name, Position in Value do
		Count += 1
		if Count > MAX_BUTTONS or typeof(Name) ~= "string" or #Name > MAX_NAME_LENGTH
			or not Name:match("^[%w_]+$") or typeof(Position) ~= "table" then
			return nil
		end

		local X, Y = Position.X, Position.Y
		if typeof(X) ~= "number" or typeof(Y) ~= "number" or X ~= X or Y ~= Y
			or X < 0 or X > 1 or Y < 0 or Y > 1 then
			return nil
		end

		Layout[Name] = { X = X, Y = Y }
	end

	return Layout
end

function MobileControlLayout.ClampPosition(
	Position: Vector2,
	ButtonSize: Vector2,
	ContainerSize: Vector2,
	AnchorPoint: Vector2
): Vector2
	local Size = Vector2.new(math.max(ContainerSize.X, 1), math.max(ContainerSize.Y, 1))
	local Minimum = ButtonSize * AnchorPoint / Size
	local Maximum = Vector2.one - ButtonSize * (Vector2.one - AnchorPoint) / Size

	return Vector2.new(
		if Minimum.X > Maximum.X then 0.5 else math.clamp(Position.X, Minimum.X, Maximum.X),
		if Minimum.Y > Maximum.Y then 0.5 else math.clamp(Position.Y, Minimum.Y, Maximum.Y)
	)
end

return MobileControlLayout
