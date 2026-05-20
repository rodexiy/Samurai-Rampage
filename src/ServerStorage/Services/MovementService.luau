local Knit = require(game.ReplicatedStorage.Packages.Knit)

local MovementService = Knit.CreateService({
	Name = "MovementService",
	Client = {},
})

local DebounceService
local StaminaService
local DamageService
local RenderService
local AnimationService
local SoundEffectService
local BuffService

local Validate = require(game.ReplicatedStorage.Shared.Validate)
function MovementService:Run(Character: Model, State: boolean)
	if State then
		Character:SetAttribute("Running", Validate:CanRun(Character))
	else
		Character:SetAttribute("Running", false)
	end
end
function MovementService.Client:Run(Player: Player, State: boolean)
	local Character = Player.Character
	if Character then
		self.Server:Run(Character, State)
	end
end

function MovementService:Roll(Character: Model, Direction: string, StartCFrame: CFrame)
	if not Character:GetAttribute("IsAI") then
		if not Validate:CanRoll(Character) then
			Character:SetAttribute("Rolling", false)
			return
		end
	end

	BuffService:RemoveBuffsByType(Character, "Burn")

	--SoundEffectService:PlaySoundEffect("Roll", true, Character)
	AnimationService:StopAttackAnimations(Character)
	Character:SetAttribute("RollDirection", Direction)
	StaminaService:RemoveStamina(Character, 5)
	local RollingDuration = 0.5
	if Character:GetAttribute("Race") == "Raijin" then
		RollingDuration = 0.3
	end
	DebounceService:AddDebounce(Character, "Rolling", RollingDuration)
	if not Character:GetAttribute("Blocking") then
		DebounceService:AddDebounce(Character, "RollIFrame", 0.25)
	end
	DebounceService:AddDebounce(Character, "RollDebounce", 1.65)

	RenderService:RenderForAllPlayers(
		"Combat",
		"Roll",
		{ Character = Character, Direction = Direction, StartCFrame = StartCFrame }
	)

	task.delay(0.5, function()
		Character:SetAttribute("RollDirection", nil)
	end)
end

function MovementService:Climb(Character: Model, State: boolean)
	Character:SetAttribute("Climbing", State)
end
function MovementService.Client:Climb(Player: Player, State: boolean)
	local Character = Player.Character
	if Character then
		self.Server:Climb(Character, State)
	end
end

function MovementService.Client:Roll(Player: Player, Direction: string, StartCFrame: CFrame)
	local Character = Player.Character
	if Character then
		self.Server:Roll(Character, Direction, StartCFrame)
	end
end

function MovementService.KnitInit()
	DebounceService = Knit.GetService("DebounceService")
	StaminaService = Knit.GetService("StaminaService")
	DamageService = Knit.GetService("DamageService")
	RenderService = Knit.GetService("RenderService")
	AnimationService = Knit.GetService("AnimationService")
	SoundEffectService = Knit.GetService("SoundEffectService")
	BuffService = Knit.GetService("BuffService")
end

function MovementService.KnitStart() end

return MovementService
