local Knit = require(game.ReplicatedStorage.Packages.Knit)

local WisdomWorldController = Knit.CreateController({
	Name = "WisdomWorldController",
})

local AlertController
local AnimationController
local MenuController
local WisdomWorldService

local CharacterShared = require(game.ReplicatedStorage.Shared.CharacterShared)
local TileTransition =
	require(game.ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Libraries"):WaitForChild("TileTransition"))

local Player = game.Players.LocalPlayer
local Debounce = false
local WisdomWorldHud
local WisdomText
local WaveText
local Timer
local TimerText

local ROMAN_NUMERALS = {
	{ Value = 1000, Numeral = "M" },
	{ Value = 900, Numeral = "CM" },
	{ Value = 500, Numeral = "D" },
	{ Value = 400, Numeral = "CD" },
	{ Value = 100, Numeral = "C" },
	{ Value = 90, Numeral = "XC" },
	{ Value = 50, Numeral = "L" },
	{ Value = 40, Numeral = "XL" },
	{ Value = 10, Numeral = "X" },
	{ Value = 9, Numeral = "IX" },
	{ Value = 5, Numeral = "V" },
	{ Value = 4, Numeral = "IV" },
	{ Value = 1, Numeral = "I" },
}

local function StopMeditating(Character: Model)
	CharacterShared:UpdateBoth(Character)
	AnimationController:StopAnimationFind(Character, "Meditate")
	MenuController:CloseAllMenus()
end

local function GetTextObject(Object: Instance?): TextLabel | TextButton | TextBox | nil
	if not Object then
		return
	end

	if Object:IsA("TextLabel") or Object:IsA("TextButton") or Object:IsA("TextBox") then
		return Object
	end

	for _, Descendant in Object:GetDescendants() do
		if Descendant:IsA("TextLabel") or Descendant:IsA("TextButton") or Descendant:IsA("TextBox") then
			return Descendant
		end
	end
end

local function ToRoman(Number)
	Number = math.max(1, math.floor(tonumber(Number) or 1))

	local Result = ""
	for _, RomanNumeral in ROMAN_NUMERALS do
		while Number >= RomanNumeral.Value do
			Result ..= RomanNumeral.Numeral
			Number -= RomanNumeral.Value
		end
	end

	return Result
end

local function FormatWisdom(Wisdom: number)
	local Formatted = string.format("%.2f", Wisdom)
	Formatted = Formatted:gsub("0+$", ""):gsub("%.$", "")

	return Formatted
end

function WisdomWorldController:UpdateHud()
	if not WisdomWorldHud then
		return
	end

	local InWisdomWorld = Player:GetAttribute("InWisdomWorld") == true
	WisdomWorldHud.Enabled = InWisdomWorld

	if not InWisdomWorld then
		return
	end

	local Wisdom = tonumber(Player:GetAttribute("WisdomWorldWisdom") or Player:GetAttribute("Wisdom")) or 0
	local Wave = Player:GetAttribute("WisdomWorldWave") or 1
	local Countdown = tonumber(Player:GetAttribute("WisdomWorldWaveCountdown")) or 0
	local EnemiesLeft = tonumber(Player:GetAttribute("WisdomWorldEnemiesLeft")) or 0

	WisdomText.Text = FormatWisdom(Wisdom) .. " WISDOM"
	WaveText.Text = "WAVE " .. ToRoman(Wave)

	local ShowTimer = Countdown > 0 or EnemiesLeft > 0
	if Timer and Timer:IsA("GuiObject") then
		Timer.Visible = ShowTimer
	end

	if TimerText then
		TimerText.Visible = ShowTimer
		if Countdown > 0 then
			TimerText.Text = tostring(math.ceil(Countdown))
		else
			local EnemyLabel = if EnemiesLeft == 1 then " Enemy" else " Enemies"
			TimerText.Text = tostring(math.floor(EnemiesLeft)) .. EnemyLabel
		end
	end
end

function WisdomWorldController:Enter()
	local Character = Player.Character
	if not Character then
		return
	end

	if Player:GetAttribute("InCombat") or Character:GetAttribute("InCombat") then
		AlertController:Alert("Can't enter Wisdom World while in combat", "Error")
		return
	end

	if not Character:GetAttribute("Meditating") then
		AlertController:Alert("Meditate first", "Error")
		return
	end

	if Debounce then
		return
	end

	Debounce = true
	Character:SetAttribute("RealmTeleporting", true)

	TileTransition.CreateTiles()
	TileTransition.In()

	local Success, Message = WisdomWorldService:Enter()

	if Success then
		StopMeditating(Character)
	elseif Message then
		AlertController:Alert(Message, "Error")
	end

	TileTransition.Out()
	Character:SetAttribute("RealmTeleporting", false)

	task.delay(2, function()
		Debounce = false
	end)
end

function WisdomWorldController.KnitInit()
	AlertController = Knit.GetController("AlertController")
	AnimationController = Knit.GetController("AnimationController")
	MenuController = Knit.GetController("MenuController")
	WisdomWorldService = Knit.GetService("WisdomWorldService")
end

function WisdomWorldController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Menu = PlayerGui:WaitForChild("Menu")
	local Hud = PlayerGui:WaitForChild("Hud")
	local Meditate = Menu:WaitForChild("Meditate")
	local WisdomWorldButton = Meditate:WaitForChild("WisdomWorld")

	WisdomWorldHud = Hud:WaitForChild("WisdomWorld")
	WisdomText = WisdomWorldHud:WaitForChild("Wisdom")
	WaveText = WisdomWorldHud:WaitForChild("Wave")
	Timer = WisdomWorldHud:FindFirstChild("Timer", true)
	TimerText = GetTextObject(Timer)

	for _, AttributeName in {
		"InWisdomWorld",
		"WisdomWorldWisdom",
		"WisdomWorldWave",
		"WisdomWorldWaveCountdown",
		"WisdomWorldEnemiesLeft",
		"Wisdom",
	} do
		Player:GetAttributeChangedSignal(AttributeName):Connect(function()
			WisdomWorldController:UpdateHud()
		end)
	end

	WisdomWorldController:UpdateHud()

	WisdomWorldButton.Activated:Connect(function()
		WisdomWorldController:Enter()
	end)
end

return WisdomWorldController
