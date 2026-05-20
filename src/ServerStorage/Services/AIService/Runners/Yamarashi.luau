local Yamarashi = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Character: Model
local Humanoid: Humanoid
local RootPart: BasePart
local Align: AlignOrientation
local Config = {}
local Actions = {}

local CombatAnimations

local FinderService
local WeaponService
local AIService
local PostureService
local AnimationService
local HitboxService
local RenderService
local SkillService

local Validate = require(game.ReplicatedStorage.Shared.Validate)

local TimeOffset = math.random(1, 10000)

local Target: Model = nil
local BindedTarget: Model = nil
local TargetConnections = {}

local UpdateWait = 0.5

function Yamarashi:UnbindTarget()
	for _, Connection in TargetConnections do
		Connection:Disconnect()
		TargetConnections[_] = nil
	end

	UpdateWait = 0.5
	if not Target then
		Character:MoveTo(RootPart.CFrame.Position)
	end
	Align.Enabled = false
	BindedTarget = nil
end

function Yamarashi:BindTarget()
	if Target and Target == BindedTarget then
		return
	end
	self:UnbindTarget()

	BindedTarget = Target

	table.insert(
		TargetConnections,
		Target:GetAttributeChangedSignal("Attack"):Connect(function()
			if not Target:GetAttribute("Attack") then
				AnimationService:StopAnimationFind(Character, "Block")
			end
		end)
	)

	table.insert(
		TargetConnections,
		Target:GetAttributeChangedSignal("Died"):Connect(function()
			Target = nil
			Yamarashi:UnbindTarget()
		end)
	)

	Yamarashi:LookAtTarget()

	Align.Enabled = true
	UpdateWait = 0
end

function Yamarashi:Block()
	if Character:GetAttribute("UsingSkillCantAttack") then
		return
	end

	if Target then
		if Character:GetAttribute("Rolling") then
			return
		end

		if not AnimationService:GetAnimationFind(Character, "Block") then
			if math.random(0, 100) < Config.ActionChance and math.random(0, 100) < Config.DeflectChance then
				AnimationService:PlayAnimation(Character, CombatAnimations.Block)
			end
		end

		if not AnimationService:GetAnimationFind(Character, "Block") then
			return
		end

		PostureService:Block(Character, true)

		task.delay(0.2, function()
			PostureService:Block(Character, false)
		end)
	end
end

function Yamarashi:MoveToTarget()
	local Noise = math.noise(os.clock() + TimeOffset)

	local CharactersIn = HitboxService:GetCharactersInCircleArea(Character:GetPivot().Position, 10)

	local AllyOffset = Vector3.zero

	local Closest = nil
	local ClosestDistance = math.huge
	for _, CharacterIn in CharactersIn do
		if CharacterIn == Target or CharacterIn == Character then
			continue
		end

		if CharacterIn:GetAttribute("IsAI") and not CharacterIn:GetAttribute("Downed") then
			local Distance = (CharacterIn:GetPivot().Position - Target:GetPivot().Position).Magnitude
			if Distance < ClosestDistance then
				Closest = CharacterIn
				ClosestDistance = Distance
			end
		end
	end

	if Closest then
		AllyOffset = -(CFrame.new(Character:GetPivot().Position, Closest:GetPivot().Position).LookVector * 10)
	end

	local PositionToMove = (CFrame.new(Target:GetPivot().Position, RootPart.CFrame.Position) * CFrame.new(
		Noise * 30,
		0,
		-(Config.TargetOffset * (math.abs(Noise) * 7.5))
	)).Position + AllyOffset

	Humanoid:MoveTo(PositionToMove)
end

function Yamarashi:LookAtTarget()
	Character:SetAttribute("MousePosition", Target:GetPivot().Position)
	local Pivot = Target:GetPivot()
	local PositionToLook = Vector3.new(Pivot.Position.X, RootPart.CFrame.Position.Y, Pivot.Position.Z)
	Align.LookAtPosition = PositionToLook
end

function Yamarashi:RunToTarget()
	if not Actions.Run then
		return
	end

	local Distance = (Target:GetPivot().Position - RootPart:GetPivot().Position).Magnitude
	if Distance >= Config.RunDistance then
		Actions.Run:Run()
	end
end

function Yamarashi:CheckDistance()
	local Distance = (Target:GetPivot().Position - RootPart:GetPivot().Position).Magnitude

	if Distance > Config.MaintainDistance then
		self:UnbindTarget()
		Target = nil
		Humanoid:MoveTo(Character:GetPivot().Position)
		return true
	end
end

local SkillDistance = {
	MoltenSmash = 50,
	Barrage = 10,
	FloatingPassage = 10,
	FireSlash = 60,
}

local GeneralSkillDebounce = 0
function Yamarashi:TryAttack()
	local Distance = (Target:GetPivot().Position - RootPart:GetPivot().Position).Magnitude

	if Config.Skills and math.random(0, 100) <= Config.SkillChance and tick() > GeneralSkillDebounce then
		local SkillToUse = Config.Skills[math.random(1, #Config.Skills)]

		if SkillDistance[SkillToUse] and Distance <= SkillDistance[SkillToUse] then
			if SkillService:UseSkill(Character, SkillToUse, { RootCFrame = Character:GetPivot() }) then
				GeneralSkillDebounce = tick() + math.random(7, 12)
			end
		end
	end

	if Distance <= Config.AttackDistance then
		if not Target:GetAttribute("Downed") then
			if math.random(1, 5) > 1 then
				if Target:GetAttribute("PostureBreak") then
					WeaponService:WeaponInput(Character, "Attack", { RootCFrame = Character:GetPivot() })
					return
				end
				task.wait(math.random(10, 40) / 100)

				WeaponService:WeaponInput(Character, "Attack", { RootCFrame = Character:GetPivot() })
			else
				WeaponService:WeaponInput(Character, "StrongAttack", { RootCFrame = Character:GetPivot() })
			end
		else
			WeaponService:WeaponInput(Character, "StrongAttack", { RootCFrame = Character:GetPivot() })
		end
	end
end

function Yamarashi:CheckDistanceFromSpawn()
	if not Character:GetAttribute("SpawnCFrame") then
		return
	end

	local Distance = (Character:GetPivot().Position - Character:GetAttribute("SpawnCFrame").Position).Magnitude

	if Distance > Config.MaxDistanceFromSpawn * 2 then
		Character:PivotTo(Character:GetAttribute("SpawnCFrame"))
		return true
	elseif Distance > Config.MaxDistanceFromSpawn then
		self:UnbindTarget()
		Target = nil
		Humanoid:MoveTo(Character:GetAttribute("SpawnCFrame").Position)
		return true
	end
end

function Yamarashi:Run()
	if Character:GetPivot().Y < 0 then
		Character:PivotTo(Character:GetAttribute("SpawnCFrame"))
		return
	end
	if Character:GetAttribute("Ragdoll") then
		return
	end

	if Character:GetAttribute("Downed") then
		return
	end

	local _Target = FinderService:GetClosestTarget(
		Character,
		Config.DetectionDistanceFromSpawn,
		false,
		Character:GetAttribute("SpawnCFrame")
	)

	if _Target then
		if not Target then
			Target = _Target

			local TargetPlayer = game.Players:GetPlayerFromCharacter(_Target)
			if TargetPlayer then
				RenderService:RenderForPlayer(TargetPlayer, "Enemy", "Detect", { Character = Character })
			end
		end
	elseif Target then
		local ClosestTargetFromAI =
			FinderService:GetClosestTarget(Character, Config.DetectionDistanceFromSpawn, false, Character:GetPivot())

		if ClosestTargetFromAI then
			_Target = ClosestTargetFromAI
		end
	end

	if not _Target and not Target or Character:GetAttribute("Ragdoll") then
		if Character:GetAttribute("WeaponEquipped") then
			Character:SetAttribute("Running", false)
			Character:SetAttribute("WeaponEquipped", false)
			task.delay(math.random(100, 500) / 100, function()
				if Target then
					return
				end

				Character:SetAttribute("InCombat", false)
				WeaponService:Equip(Character, false, 1.5)
			end)
		end
		return
	end

	self:BindTarget()

	if not Character:GetAttribute("WeaponEquipped") then
		WeaponService:Equip(Character, true)
		SkillService:UseSkill(Character, "BladeIgnition")
	end

	if not Character:GetAttribute("SwordOnFire") then
		SkillService:UseSkill(Character, "BladeIgnition")
	end

	if self:CheckDistance() then
		return
	end

	if self:CheckDistanceFromSpawn() then
		return
	end

	self:LookAtTarget()
	self:MoveToTarget()
	self:RunToTarget()
	self:TryAttack()
end

function Yamarashi.Start(_Config)
	FinderService = Knit.GetService("FinderService")
	WeaponService = Knit.GetService("WeaponService")
	PostureService = Knit.GetService("PostureService")
	AnimationService = Knit.GetService("AnimationService")
	HitboxService = Knit.GetService("HitboxService")
	RenderService = Knit.GetService("RenderService")
	SkillService = Knit.GetService("SkillService")

	Character = script.Parent

	local function Configure()
		local ActionsFolder = game.ServerStorage.ServerAssets.MobActions

		local ActionsList = Config.Actions or {}
		for actionName, instance in Actions do
			if not table.find(ActionsList, actionName) then
				Actions[actionName] = nil
				instance:Destroy()
			end
		end

		for _, action in ActionsList do
			if ActionsFolder:FindFirstChild(action) then
				if script:FindFirstChild(action) then
					continue
				end

				local Clone = ActionsFolder[action]:Clone()
				Clone.Parent = script
				Actions[action] = require(Clone)
			end
		end

		Character:SetAttribute("RunningWalkSpeed", Config.RunSpeed or 20)
	end

	Config = _Config.Lifes[tostring(Character:GetAttribute("Lifes"))]
	Character:GetAttributeChangedSignal("Lifes"):Connect(function()
		Config = _Config.Lifes[tostring(Character:GetAttribute("Lifes"))]
		Configure()
	end)

	Configure()

	Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	RootPart = Character.PrimaryPart

	Align = RootPart:FindFirstChildWhichIsA("AlignOrientation", true)
	Align.MaxAngularVelocity = 1000

	CombatAnimations = WeaponService:GetCombatAnimationFolder(Character)

	Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		Align.Enabled = not Character:GetAttribute("Ragdoll")
	end)

	local HitboxDetected: BindableEvent = Character:FindFirstChild("HitboxDetected")

	if HitboxDetected then
		HitboxDetected.Event:Connect(function(Attacker: Model)
			if not Target then
				Target = Attacker
			end
			Yamarashi:Block()
		end)
	end

	Character:SetAttribute("SpawnCFrame", Character:GetPivot())

	script:GetAttributeChangedSignal("Enabled"):Connect(function()
		if not script:GetAttribute("Enabled") then
			Yamarashi:Run()
			return
		end

		while script:GetAttribute("Enabled") do
			Yamarashi:Run()
			task.wait(UpdateWait)
		end
	end)
end

return Yamarashi
