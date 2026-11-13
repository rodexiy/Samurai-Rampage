local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local OutdoorLightsController = Knit.CreateController({ Name = "OutdoorLightsController" })
type Effect = PointLight | ParticleEmitter | Beam | Trail | Fire | Smoke | Sparkles
local OriginalEnabled: { [Effect]: boolean } = {}
local IsDay = Lighting.ClockTime > 6.5 and Lighting.ClockTime < 17.5
local Connections: { RBXScriptConnection } = {}

local function GetEffect(Object: Instance): Effect?
	if Object:IsA("PointLight") or Object:IsA("ParticleEmitter") or Object:IsA("Beam") or Object:IsA("Trail")
		or Object:IsA("Fire") or Object:IsA("Smoke") or Object:IsA("Sparkles") then
		return Object
	end

	return nil
end

local function Apply(Effect: Effect, Enabled: boolean)
	Effect.Enabled = Enabled
	if not Enabled then
		if Effect:IsA("ParticleEmitter") or Effect:IsA("Trail") then
			Effect:Clear()
		end
	end
end

local function Track(Object: Instance)
	local Effect = GetEffect(Object)
	if not Effect or OriginalEnabled[Effect] ~= nil then
		return
	end

	OriginalEnabled[Effect] = Effect.Enabled
	Apply(Effect, not IsDay and OriginalEnabled[Effect])
end

function OutdoorLightsController:SetClockTime(ClockTime: number)
	local Day = ClockTime > 6.5 and ClockTime < 17.5
	if Day == IsDay then
		return
	end

	IsDay = Day
	for Effect, Enabled in OriginalEnabled do
		Apply(Effect, not IsDay and Enabled)
	end
end

function OutdoorLightsController:Unbind()
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	table.clear(Connections)
	for Effect, Enabled in OriginalEnabled do
		Apply(Effect, Enabled)
	end
	table.clear(OriginalEnabled)
end

function OutdoorLightsController:Bind(Root: Instance)
	self:Unbind()
	IsDay = Lighting.ClockTime > 6.5 and Lighting.ClockTime < 17.5
	table.insert(Connections, Root.DescendantAdded:Connect(Track))
	table.insert(Connections, Root.DescendantRemoving:Connect(function(Object: Instance)
		local Effect = GetEffect(Object)
		if Effect and OriginalEnabled[Effect] ~= nil then
			Apply(Effect, OriginalEnabled[Effect])
			OriginalEnabled[Effect] = nil
		end
	end))
	for _, Object in Root:QueryDescendants("PointLight, ParticleEmitter, Beam, Trail, Fire, Smoke, Sparkles") do
		Track(Object)
	end
end

function OutdoorLightsController.KnitStart()
	local Outdoor = workspace:WaitForChild("Lights"):WaitForChild("Outdoor")
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
		OutdoorLightsController:SetClockTime(Lighting.ClockTime)
	end)
	OutdoorLightsController:Bind(Outdoor)
end

return OutdoorLightsController
