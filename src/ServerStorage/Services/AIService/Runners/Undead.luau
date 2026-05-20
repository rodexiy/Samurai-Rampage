local Undead = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Character: Model
local Humanoid: Humanoid
local RootPart: BasePart
local Align: AlignOrientation
local Config = {}
local Actions = {}

local FinderService
local WeaponService

local HitboxService
local RenderService
local SkillService

local TimeOffset = math.random(1, 10000)

local Target: Model = nil
local BindedTarget: Model = nil
local TargetConnections = {}

local UpdateWait = 0.5

function Undead:UnbindTarget()
	for _, Connection in TargetConnections do
		Connection:Disconnect()
		TargetConnections[_] = nil
	end

	UpdateWait = 0.5
	Character:MoveTo(RootPart.CFrame.Position)
	Align.Enabled = false
	BindedTarget = nil
end

function Undead:BindTarget()
	if Target and Target == BindedTarget then
		return
	end
	self:UnbindTarget()

	BindedTarget = Target

	table.insert(
		TargetConnections,
		Target:GetAttributeChangedSignal("Died"):Connect(function()
			Target = nil
			Undead:UnbindTarget()
		end)
	)

	Undead:LookAtTarget()

	Align.Enabled = true
	UpdateWait = 0
end

function Undead:MoveToTarget()
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
		AllyOffset = -(CFrame.new(Character:GetPivot().Position, Closest:GetPivot().Position).LookVector * 6.5)
	end

	local PositionToMove = (CFrame.new(Target:GetPivot().Position, RootPart.CFrame.Position) * CFrame.new(
		Noise * 5,
		0,
		-(Config.TargetOffset * (math.abs(Noise) * 5))
	)).Position + AllyOffset

	Humanoid:MoveTo(PositionToMove)
end

function Undead:LookAtTarget()
	Character:SetAttribute("MousePosition", Target:GetPivot().Position)
	local Pivot = Target:GetPivot()
	local PositionToLook = Vector3.new(Pivot.Position.X, RootPart.CFrame.Position.Y, Pivot.Position.Z)
	Align.LookAtPosition = PositionToLook
end

function Undead:CheckDistance()
	local Distance = (Target:GetPivot().Position - RootPart:GetPivot().Position).Magnitude

	if Distance > Config.MaintainDistance then
		self:UnbindTarget()
		Target = nil
		return true
	end
end

local AttackingDelay = false
function Undead:TryAttack()
	local Distance = (Target:GetPivot().Position - RootPart:GetPivot().Position).Magnitude

	if AttackingDelay then
		return
	end

	if Distance <= Config.AttackDistance then
		if not Target:GetAttribute("Downed") then
			if math.random(1, 5) > 1 then
				if Target:GetAttribute("PostureBreak") then
					WeaponService:WeaponInput(
						Character,
						"Attack",
						{ RootCFrame = Character:GetPivot(), Server = { AttackAdjustSpeed = 0.65 } }
					)
					return
				end

				AttackingDelay = true

				task.delay(math.random(85, 165) / 100, function()
					WeaponService:WeaponInput(
						Character,
						"Attack",
						{ RootCFrame = Character:GetPivot(), Server = { AttackAdjustSpeed = 0.65 } }
					)
					AttackingDelay = false
				end)
			else
				if Config.Skills and math.random(0, 100) <= Config.SkillChance then
					local SkillToUse = Config.Skills[math.random(1, #Config.Skills)]

					if not SkillService:UseSkill(Character, SkillToUse) then
						return
					end
				end
			end
		else
			WeaponService:WeaponInput(Character, "StrongAttack", { RootCFrame = Character:GetPivot() })
		end
	end
end

function Undead:Run()
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

	local _Target = FinderService:GetClosestTarget(Character, Config.DetectionDistance)

	if _Target then
		if not Target and _Target then
			local TargetPlayer = game.Players:GetPlayerFromCharacter(_Target)
			if TargetPlayer then
				RenderService:RenderForPlayer(TargetPlayer, "Enemy", "Detect", { Character = Character })
			end
		end

		Target = _Target
	end

	if not Target then
		self:UnbindTarget()

		Character:SetAttribute("InCombat", false)
		return
	end

	self:BindTarget()

	if self:CheckDistance() then
		return
	end

	self:LookAtTarget()
	self:MoveToTarget()
	self:TryAttack()
end

function Undead.Start(_Config)
	FinderService = Knit.GetService("FinderService")
	WeaponService = Knit.GetService("WeaponService")
	HitboxService = Knit.GetService("HitboxService")
	RenderService = Knit.GetService("RenderService")
	SkillService = Knit.GetService("SkillService")

	Character = script.Parent

	Character:SetAttribute("Stunless", true)
	Character:SetAttribute("DefaultWalkSpeed", 10)
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
	end

	Config = _Config.Lifes[tostring(Character:GetAttribute("Lifes"))]
	Character:GetAttributeChangedSignal("Lifes"):Connect(function()
		Config = _Config.Lifes[tostring(Character:GetAttribute("Lifes"))]
		Configure()
	end)

	Character:SetAttribute("MaxPosture", 30)
	Character:GetAttributeChangedSignal("MaxPosture"):Connect(function()
		Character:SetAttribute("MaxPosture", 30)
	end)

	Configure()

	Character:SetAttribute("WeaponEquipped", true)
	Character:SetAttribute("AnimationPreset", "Undead")

	Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	RootPart = Character.PrimaryPart

	Align = RootPart:FindFirstChildWhichIsA("AlignOrientation", true)

	Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		Align.Enabled = not Character:GetAttribute("Ragdoll")
	end)

	Character:SetAttribute("SpawnCFrame", Character:GetPivot())

	Character:GetAttributeChangedSignal("ComboDebounce"):Connect(function()
		Character:SetAttribute("ComboCounter", 0)
		Character:SetAttribute("ComboDebounce", false)
	end)

	script:GetAttributeChangedSignal("Enabled"):Connect(function()
		if not script:GetAttribute("Enabled") then
			Undead:Run()
			return
		end

		while script:GetAttribute("Enabled") do
			Undead:Run()
			task.wait(UpdateWait)
		end
	end)
end

return Undead
