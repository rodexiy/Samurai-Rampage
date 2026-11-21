local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CombatMusicController = Knit.CreateController({ Name = "CombatMusicController" })

local Group: SoundGroup
local FadeTween: Tween?

local function RegisterSound(Instance: Instance)
	if Instance:IsA("Sound") and Instance:GetAttribute("CombatMusic") then
		Instance.SoundGroup = Group
	end
end

function CombatMusicController:FadeOut(Duration: number)
	if FadeTween then
		FadeTween:Cancel()
	end

	local Tween = TweenService:Create(Group, TweenInfo.new(Duration), { Volume = 0 })
	FadeTween = Tween
	Tween.Completed:Once(function(State: Enum.PlaybackState)
		if State ~= Enum.PlaybackState.Completed or FadeTween ~= Tween then
			return
		end

		for _, Instance in SoundService:GetChildren() do
			if Instance:IsA("Sound") and Instance.SoundGroup == Group then
				Instance:Stop()
			end
		end
	end)
	Tween:Play()
end

function CombatMusicController:Restore()
	if FadeTween then
		FadeTween:Cancel()
		FadeTween = nil
	end
	Group.Volume = 1
end

function CombatMusicController.KnitInit()
	Group = Instance.new("SoundGroup")
	Group.Name = "CombatMusic"
	Group.Parent = SoundService
	SoundService.ChildAdded:Connect(RegisterSound)
	for _, Instance in SoundService:GetChildren() do
		RegisterSound(Instance)
	end
end

return CombatMusicController
