local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ResourceVFX = {}

local RenderController = Knit.GetController("RenderController")
local ActiveShakes = setmetatable({}, { __mode = "k" })

local Assets = game.ReplicatedStorage.Assets.VFX.Misc
function ResourceVFX.Pick(RenderData)
	local ResourceCFrame = RenderData.ResourceCFrame

	local VFX = Assets.Pick:Clone()
	VFX:PivotTo(ResourceCFrame)
	VFX.Parent = workspace.VFX

	Debris:AddItem(VFX, 3)
	RenderController:EmitParticles(VFX)
end

function ResourceVFX.Shake(RenderData)
	local Resource = RenderData.Resource
	if
		not Resource
		or not Resource:IsA("Model")
		or not Resource:IsDescendantOf(workspace)
		or ActiveShakes[Resource]
	then
		return
	end

	ActiveShakes[Resource] = true

	local OriginalPivot = Resource:GetPivot()
	local _, Size = Resource:GetBoundingBox()
	local Magnitude = math.clamp(Size.Y * 0.03, 0.15, 0.4)
	local Duration = 0.2
	local Frequency = 30
	local Elapsed = 0
	local Connection

	local function Cleanup(RestorePivot: boolean)
		if Connection then
			Connection:Disconnect()
			Connection = nil
		end

		ActiveShakes[Resource] = nil

		if RestorePivot and Resource:IsDescendantOf(workspace) and not Resource:GetAttribute("Broken") then
			Resource:PivotTo(OriginalPivot)
		end
	end

	Connection = RunService.RenderStepped:Connect(function(DeltaTime)
		if not Resource:IsDescendantOf(workspace) or Resource:GetAttribute("Broken") then
			Cleanup(false)
			return
		end

		Elapsed += DeltaTime
		if Elapsed >= Duration then
			Cleanup(true)
			return
		end

		local Time = Elapsed * Frequency
		local Offset = Vector3.new(
			math.sin(Time * 13) * Magnitude,
			0,
			math.cos(Time * 11) * Magnitude
		)

		Resource:PivotTo(OriginalPivot * CFrame.new(Offset))
	end)
end

return ResourceVFX
