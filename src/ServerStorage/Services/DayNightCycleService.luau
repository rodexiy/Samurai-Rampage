local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DayNightCycleService = Knit.CreateService({
	Name = "DayNightCycleService",
	Client = {},
})

--time changer
local mam --minutes after midnight
local timeShift = 0.155 --how many minutes you shift every "tick"
local waitTime = 0.25 --legnth of the tick in seconds

local LightsOn = true

function DayNightCycleService:ToggleLights(boolean)
	if boolean == LightsOn then
		return
	end

	LightsOn = boolean

	for _, Neon in CollectionService:GetTagged("StreetLight") do
		if not Neon:GetAttribute("DefaultColor") then
			Neon:SetAttribute("DefaultColor", Neon.Color)
		end

		if LightsOn then
			Neon.Color = Neon:GetAttribute("DefaultColor")
		else
			Neon.Color = Color3.fromRGB(0, 0, 0)
		end

		for _, Part in Neon.Parent:GetChildren() do
			if
				Part:IsA("BasePart") and Part.Color == Color3.fromRGB(248, 248, 248)
				or Part:GetAttribute("HasForceFieldMaterial")
			then
				Part:SetAttribute("HasForceFieldMaterial", true)
				if LightsOn then
					Part.Color = Color3.fromRGB(248, 248, 248)
				else
					Part.Color = Color3.fromRGB(0, 0, 0)
				end
			end
		end

		local PointLight = Neon:FindFirstChildWhichIsA("PointLight")
		if PointLight then
			PointLight.Enabled = LightsOn
		end
	end
end

function DayNightCycleService:StartCycle()
	game.Lighting.ClockTime = math.random(4, 18)
	while true do
		mam = game.Lighting:GetMinutesAfterMidnight() + timeShift
		game.Lighting:SetMinutesAfterMidnight(mam)
		mam = mam / 60

		local ToD = tonumber(Lighting.ClockTime)
		self:ToggleLights(ToD <= 6.5 or ToD >= 17.5)

		task.wait(waitTime)
	end
end

function DayNightCycleService.KnitInit() end

function DayNightCycleService.KnitStart()
	DayNightCycleService:StartCycle()
end

return DayNightCycleService
