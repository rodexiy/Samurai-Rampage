local TweenService = game:GetService("TweenService")
local Grapple = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RenderController = Knit.GetController("RenderController")

local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)

local function Curve(t, P0, P1, P2)
	local A = P0:Lerp(P1, t)
	local B = P1:Lerp(P2, t)
	return A:Lerp(B, t)
end

local Player = game.Players.LocalPlayer

local Camera = workspace.CurrentCamera
function Grapple.Grapple(RenderData: { any })
	local CharacterToRender = RenderData.Character
	local GrappleCFrame = RenderData.GrappleCFrame

	local P0 = CharacterToRender:GetPivot().Position
	local P2 = GrappleCFrame.Position + Vector3.new(0, 3, 0)
	local Distance = (P0 - P2).Magnitude

	local P1 = P0:Lerp(P2, 0.65) + Vector3.new(0, Distance / 2, 0)

	local Hook = game.ReplicatedStorage.Assets.Models.Hook:Clone()
	Hook.Anchored = true
	Hook.Parent = workspace
	Hook.Rope.Attachment0 = CharacterToRender["Left Arm"].LeftGripAttachment
	Hook:PivotTo(CharacterToRender["Left Arm"].LeftGripAttachment.CFrame)
	local i = 0

	RenderController:ExecuteForCharacter(CharacterToRender, function()
		if not Player:GetAttribute("FovEffects") then
			return
		end
		TweenService:Create(
			Camera,
			TweenInfo.new(Distance / 200, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ FieldOfView = 60 }
		):Play()
	end)

	while i < 1 do
		local dt = task.wait()

		local P1 = P0:Lerp(P2, 0.95) + Vector3.new(0, Distance / 4, 0)

		local t = 200 * dt / Distance
		local Pos = Curve(i, P0, P1, P2)
		Hook.CFrame = CFrame.new(Pos, Curve(i + (t * 2), P0, P1, P2)) * CFrame.Angles(math.rad(90), 0, 0)
		i += t
	end

	RenderController:ExecuteForCharacter(CharacterToRender, function()
		task.spawn(function()
			local AlignPosition = Instance.new("AlignPosition")
			AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
			AlignPosition.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			AlignPosition.Attachment0 = CharacterToRender.HumanoidRootPart.RootAttachment
			AlignPosition.MaxAxesForce = Vector3.new(1000, 1000, 1000) * GetModelMass(CharacterToRender)
			AlignPosition.Position = CharacterToRender.Torso.Position
			AlignPosition.Responsiveness = 100
			AlignPosition.Parent = CharacterToRender.PrimaryPart

			if Player:GetAttribute("FovEffects") then
				TweenService:Create(
					Camera,
					TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
					{ FieldOfView = 85 }
				):Play()
			end

			local i = 0
			while i < 1 do
				local dt = task.wait()

				local t = 100 * dt / Distance
				AlignPosition.Position = Curve(i, P0, P1, P2)
				i += t
			end

			TweenService
				:Create(
					Camera,
					TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
					{ FieldOfView = 75 }
				)
				:Play()

			AlignPosition:Destroy()
		end)
	end)

	local i = 0
	while i < 1 do
		local dt = task.wait()

		local t = 100 * dt / Distance
		i += t
	end

	Hook:Destroy()
end

return Grapple
