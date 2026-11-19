local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RealmPointerController = Knit.CreateController({ Name = "RealmPointerController" })
local Player = Players.LocalPlayer
local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude
local Character: Model? = nil
local BaseFilter: { Instance } = {}
local ResetFilter = false

function RealmPointerController:IsTouch(): boolean
	return UserInputService.PreferredInput == Enum.PreferredInput.Touch
end

function RealmPointerController:GetRay(Position: Vector2?, Centered: boolean?): Ray?
	local Camera = workspace.CurrentCamera
	local Point = Position or UserInputService:GetMouseLocation()
	if Camera and Centered then
		Point = Camera.ViewportSize / 2
	end

	return if Camera then Camera:ViewportPointToRay(Point.X, Point.Y) else nil
end

function RealmPointerController:IsOverUI(Position: Vector2?): boolean
	local Mouse = (Position or UserInputService:GetMouseLocation()) - GuiService:GetGuiInset()
	for _, Gui in Player.PlayerGui:GetGuiObjectsAtPosition(Mouse.X, Mouse.Y) do
		if Gui.Visible and Gui.Active then
			return true
		end
	end

	return false
end

function RealmPointerController:GetTarget(Realm: Model, Position: Vector2?): PVInstance?
	if self:IsOverUI(Position) then
		return nil
	end
	local Objects = Realm:FindFirstChild("PlacedObjects")
	local Ray = self:GetRay(Position)
	if not Objects or not Ray then
		return nil
	end
	if Character ~= Player.Character then
		Character = Player.Character
		BaseFilter = if Character then { Character } else {}
		ResetFilter = true
	end
	if ResetFilter then
		Params.FilterDescendantsInstances = BaseFilter
		ResetFilter = false
	end

	for _ = 1, 16 do
		local Hit = workspace:Raycast(Ray.Origin, Ray.Direction * 2048, Params)
		local Object: Instance? = Hit and Hit.Instance
		while Object and Object.Parent ~= Objects do
			Object = Object.Parent
		end
		if not Hit or not Object or not (Object:IsA("Model") or Object:IsA("BasePart"))
			or typeof(Object:GetAttribute("PlacementId")) ~= "string" or Object:GetAttribute("RealmId") ~= Player.UserId then
			return nil
		end

		local Areas = Object:FindFirstChild("BuildingAreas")
		if Hit.Instance:IsA("BasePart") and (Hit.Instance.Transparency >= 1 or (Areas and Hit.Instance:IsDescendantOf(Areas))) then
			Params:AddToFilter(Hit.Instance)
			ResetFilter = true
		else
			return Object
		end
	end

	return nil
end

return RealmPointerController
