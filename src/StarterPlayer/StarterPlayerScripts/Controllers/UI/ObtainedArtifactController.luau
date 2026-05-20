local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ObtainedArtifactController = Knit.CreateController({
	Name = "ObtainedArtifactController",
})

local ArtifactService
local SoundEffectController

local Player = game.Players.LocalPlayer
local PlayerGui
local Temporary
local ArtifactDrop
local Canvas
local background
local FrameTemplate

local FramesIds = {
	"rbxassetid://108191523579227",
	"rbxassetid://122966493726705",
	"rbxassetid://111351335793347",
	"rbxassetid://103695902586136",
	"rbxassetid://93307801899608",
	"rbxassetid://76267770726900",
	"rbxassetid://110488168662913",
	"rbxassetid://117286001371837",
	"rbxassetid://97340353982894",
	"rbxassetid://75793788568729",
	"rbxassetid://138507994897812",
	"rbxassetid://136150720598724",
	"rbxassetid://132135189589784",
	"rbxassetid://133931600978492",
	"rbxassetid://76259189012790",
	"rbxassetid://104093369597190",
	"rbxassetid://92478617887537",
	"rbxassetid://135477493631114",
	"rbxassetid://108084521668171",
	"rbxassetid://117144264064915",
	"rbxassetid://94392761706863",
	"rbxassetid://99959874062354",
	"rbxassetid://81967910925604",
	"rbxassetid://84143213363420", -- 24
	"rbxassetid://123934642786182",
	"rbxassetid://123934642786182",
	"rbxassetid://119156668720029",
	"rbxassetid://103622715062929",
	"rbxassetid://102391471824914",
	"rbxassetid://93505487507105", -- 32
	"rbxassetid://74213387279913",
	"rbxassetid://84188111118736",
	"rbxassetid://82276650429772",
	"rbxassetid://135456032889971",
	"rbxassetid://96162356060225",
	"rbxassetid://101676703654744",
	"rbxassetid://109717690659599",
	"rbxassetid://91214155382668",
	"rbxassetid://99269311204982",
}

local Frames = {}

function ObtainedArtifactController:PlayAnimation()
	task.spawn(function()
		for _, Frame in Frames do
			Frame.Visible = false
		end
		local FrameNumber = 1

		while FrameNumber <= #Frames do
			local OldFrame = Frames[FrameNumber]
			OldFrame.Visible = true
			task.wait(1 / 24)

			FrameNumber += 1

			if OldFrame and FrameNumber ~= #Frames then
				OldFrame.Visible = false
			end
		end
	end)
end

function ObtainedArtifactController:ObtainArtifact()
	if ArtifactDrop.Enabled then
		return
	end
	ArtifactDrop.Enabled = true
	TweenService:Create(Canvas, TweenInfo.new(0.35), { GroupTransparency = 0 }):Play()
	ObtainedArtifactController:PlayAnimation()
	SoundEffectController:PlaySoundEffect("ObtainedArtifact")

	task.wait(3.5)
	TweenService:Create(Canvas, TweenInfo.new(1), { GroupTransparency = 1 }):Play()
	task.wait(0.5)
	ArtifactDrop.Enabled = false
end

function ObtainedArtifactController.KnitInit()
	ArtifactService = Knit.GetService("ArtifactService")
	SoundEffectController = Knit.GetController("SoundEffectController")

	ArtifactService.Obtained:Connect(function()
		print("Botained")
		ObtainedArtifactController:ObtainArtifact()
	end)
end

function ObtainedArtifactController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Temporary = PlayerGui:WaitForChild("Temporary", math.huge)
	ArtifactDrop = Temporary:WaitForChild("ArtifactDrop")
	Canvas = ArtifactDrop:WaitForChild("CanvasGroup")
	background = Canvas:WaitForChild("background")
	FrameTemplate = background:WaitForChild("FrameTemplate")

	ArtifactDrop.Enabled = true
	for _, FrameId in FramesIds do
		local Frame = FrameTemplate:Clone()
		Frame.Image = FrameId
		Frame.Size = UDim2.new(0, 0, 0, 0)
		Frame.Parent = background
		Frame.Name = _
		Frame.Visible = true

		table.insert(Frames, Frame)
	end

	ContentProvider:PreloadAsync(Frames, function(obj, status)
		-- if status == Enum.AssetFetchStatus.Success then
		-- 	warn("Preloaded all frames")
		-- end
	end)

	task.wait(1)
	ArtifactDrop.Enabled = false
	for _, Frame in Frames do
		Frame.Size = FrameTemplate.Size
	end
end

return ObtainedArtifactController
