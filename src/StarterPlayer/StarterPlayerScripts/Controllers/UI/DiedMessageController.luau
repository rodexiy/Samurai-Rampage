local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DiedMessageController = Knit.CreateController({
	Name = "DiedMessageController",
})
local CharacterService
local MenuController

local TweenService = game:GetService("TweenService")
local Player = game.Players.LocalPlayer
local PlayerGui
local Temporary

local DeathBlur = game.Lighting:FindFirstChild("DeathBlur")
if not DeathBlur then
	DeathBlur = Instance.new("BlurEffect")
	DeathBlur.Name = "DeathBlur"
	DeathBlur.Size = 0
	DeathBlur.Parent = game.Lighting
end

function DiedMessageController:DiedMessage(playerData)
	local info = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local DeathScreen = Temporary.DeathScreen
	local background = DeathScreen.background

	DeathScreen.Enabled = true
	DeathBlur.Enabled = true
	-- MenuController:DisableHud()
	-- MenuController:DisableMenu()

	DeathBlur.Size = 0
	TweenService:Create(DeathBlur, info, { Size = 36 }):Play()

	-- for i, v: ScreenGui in ipairs(PlayerGui:GetDescendants()) do
	-- 	if v:IsA("ScreenGui") then
	-- 		if v.ResetOnSpawn == true then
	-- 			v.Enabled = false
	-- 		end
	-- 	end
	-- end

	background.BackgroundTransparency = 1
	TweenService:Create(background, info, { BackgroundTransparency = 0.35 }):Play()
	for i, v in ipairs(DeathScreen.background:GetChildren()) do
		if v:IsA("ImageLabel") then
			TweenService:Create(v, info, { ImageTransparency = 0 }):Play()
		elseif v:IsA("TextLabel") then
			TweenService:Create(v, info, { TextTransparency = 0 }):Play()
		end
	end

	task.wait(1.5)

	local rMessage = require(DeathScreen.DiedMessages):GetRandom()
	local RandomText = background.RandomTextFrame.RandomText
	RandomText.Text = tostring(rMessage)

	TweenService:Create(RandomText, info, { Position = UDim2.fromScale(0.5, 0) }):Play()

	task.wait(5)
	TweenService:Create(RandomText, info, { Position = UDim2.fromScale(0.5, -1) }):Play()

	task.wait(1.5)

	for i, v in ipairs(DeathScreen.background:GetChildren()) do
		if v:IsA("ImageLabel") then
			TweenService:Create(v, info, { ImageTransparency = 1 }):Play()
		elseif v:IsA("TextLabel") then
			TweenService:Create(v, info, { TextTransparency = 1 }):Play()
		end
	end

	TweenService:Create(background, info, { BackgroundTransparency = 0 }):Play()
	task.wait(1)
	DeathBlur.Size = 0

	task.wait(1)
	TweenService:Create(background, info, { BackgroundTransparency = 1 }):Play()
end

function DiedMessageController.KnitInit()
	CharacterService = Knit.GetService("CharacterService")
	MenuController = Knit.GetController("MenuController")
end

function DiedMessageController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Temporary = PlayerGui:WaitForChild("Temporary", math.huge)

	CharacterService.Died:Connect(function()
		DiedMessageController:DiedMessage()
	end)
end

return DiedMessageController
