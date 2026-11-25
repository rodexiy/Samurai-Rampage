local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local KickConfig = require(ReplicatedStorage.Shared.KickConfig)
local Validate = require(ReplicatedStorage.Shared.Validate)

local EnemyReactionService = Knit.CreateService({
	Name = "EnemyReactionService",
	Client = { Dodged = Knit.CreateSignal() },
})

local MovementService
local KnockbackService
local PostureService

type ReactionConfig = {
	ActionChance: number?,
	DeflectChance: number?,
	RollChance: number?,
	Actions: { string }?,
}

local function CanReact(Character: Model, Attacker: Model): boolean
	if not Character:IsDescendantOf(workspace) or not Attacker:IsDescendantOf(workspace)
		or not Character.PrimaryPart or not Attacker.PrimaryPart
		or not Attacker:GetAttribute("Kicking") or Character:GetAttribute("IntroTutorialActive") then
		return false
	end

	for _, Attribute in { "Died", "Downed", "Ragdoll", "BeenHitted", "PostureBreak", "BeenDeflected", "UsingSkillCantAttack" } do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end

	local Offset = Attacker.PrimaryPart.Position - Character.PrimaryPart.Position
	return Offset.Magnitude <= KickConfig.HitboxSize.Magnitude
		and Character:GetPivot().LookVector:Dot(Offset) > 0
end

function EnemyReactionService:Dodge(Character: Model)
	local Root = Character.PrimaryPart
	if not Root or not Validate:CanRoll(Character) then
		return
	end

	local Direction = if math.random(1, 2) == 1 then "Left" else "Right"
	local Offset = Root.CFrame.RightVector * (if Direction == "Left" then -1 else 1) * 5
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Character }
	Params.RespectCanCollide = true
	if workspace:Raycast(Root.Position, Offset, Params) then
		return
	end

	MovementService:Roll(Character, Direction, Root.CFrame)
	KnockbackService:Push(Character, Offset / 0.2, 0.2)
	self.Client.Dodged:FireAll(Character, Direction)
end

function EnemyReactionService:ReactToKick(Character: Model, Attacker: Model, Config: ReactionConfig, TimeUntilHit: number)
	if not CanReact(Character, Attacker) or math.random(1, 100) > (Config.ActionChance or 0) then
		return
	end

	local ShouldDodge = table.find(Config.Actions or {}, "Roll") ~= nil
		and math.random(1, 100) <= (Config.RollChance or 0) and Validate:CanRoll(Character)
	local ShouldParry = math.random(1, 100) <= (Config.DeflectChance or 0)
	-- A late guard opens the parry window at contact; an early guard becomes a normal block.
	local Delay = if ShouldDodge or ShouldParry then math.max(0, TimeUntilHit - 0.08) else 0
	task.delay(Delay, function()
		if not CanReact(Character, Attacker) then
			return
		end

		if ShouldDodge then
			self:Dodge(Character)
			return
		end

		if not Validate:CanBlock(Character) or not PostureService:Block(Character, true) then
			return
		end

		task.delay(math.max(0, TimeUntilHit - Delay) + KickConfig.Duration, function()
			if Character.Parent then
				PostureService:Block(Character, false)
			end
		end)
	end)
end

function EnemyReactionService.KnitInit()
	MovementService = Knit.GetService("MovementService")
	KnockbackService = Knit.GetService("KnockbackService")
	PostureService = Knit.GetService("PostureService")
end

return EnemyReactionService
