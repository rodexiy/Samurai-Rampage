local Knit = require(game.ReplicatedStorage.Packages.Knit)

local WeaponService = Knit.CreateService({
	Name = "WeaponService",
	Client = {},
})

local DebounceService
local AnimationService
local RagdollService
local RenderService
local BloodService
local SoundEffectService
local ItemService

local WeaponsModules = {}

local Validate = require(game.ReplicatedStorage.Shared.Validate)
local Weapons = game.ReplicatedStorage.Assets.Weapons

local function GetCharacterModelScale(Character: Model): number
	local ModelScale = Character:GetAttribute("ModelScale")
	if typeof(ModelScale) == "number" then
		return ModelScale
	end

	return Character:GetScale()
end

local function ScaleInstanceToCharacter(InstanceToScale: Instance, Character: Model)
	local ModelScale = GetCharacterModelScale(Character)
	if math.abs(ModelScale - 1) < 0.001 then
		return
	end

	if InstanceToScale:IsA("Model") then
		InstanceToScale:ScaleTo(InstanceToScale:GetScale() * ModelScale)
	elseif InstanceToScale:IsA("BasePart") then
		InstanceToScale.Size *= ModelScale

		for _, Descendant in InstanceToScale:GetDescendants() do
			if Descendant:IsA("Attachment") then
				Descendant.Position *= ModelScale
			elseif Descendant:IsA("SpecialMesh") then
				Descendant.Scale *= ModelScale
			end
		end
	end
end

function WeaponService:Equip(Character: Model, State: boolean, _UnequipDelay: number)
	if State and not Validate:CanEquipWeapon(Character) then
		return
	end

	if not State and not Character:GetAttribute("WeaponEquipped") then
		return
	end

	local UnequipDelay
	if _UnequipDelay then
		UnequipDelay = math.clamp(_UnequipDelay, 0, 1.5)
	end

	local DebounceDelay = UnequipDelay or 0
	DebounceService:AddDebounce(Character, "EquipDebounce", 1 + DebounceDelay)

	local CombatAnimations = WeaponService:GetCombatAnimationFolder(Character)

	if not State then
		SoundEffectService:PlaySoundEffect("WeaponUnequip", true, Character.PrimaryPart)
		local UnequipAnimation = AnimationService:PlayAnimation(Character, CombatAnimations.Unequip)
		UnequipAnimation.Priority = Enum.AnimationPriority.Action2
		Character:SetAttribute("Blocking", false)
		Character:SetAttribute("Running", false)
	end

	local Assets = Character.Assets
	local WeaponFolder = Assets.Weapon

	Character:SetAttribute("WeaponEquipped", State)

	if CombatAnimations and Character:GetAttribute("IsAI") then
		if State and not Character:GetAttribute("WeaponEquipped") then
			AnimationService:PlayAnimation(Character, CombatAnimations.EquipDraw)
		end
	end

	if not State and Character:GetAttribute("AttackedBeforeUnequip") then
		Character:SetAttribute("AttackedBeforeUnequip", false)

		task.delay(0.15, function()
			BloodService:RemoveBloodFromBlade(Character)
			RenderService:RenderForAllPlayers("Combat", "UnequipBlood", { Character = Character })
		end)
	end

	if State then
		SoundEffectService:PlaySoundEffect("EquipDraw", true, Character.PrimaryPart)
	end
	if not State and UnequipDelay then
		task.wait(UnequipDelay)
	end

	local Weapon = WeaponFolder:FindFirstChild("Weapon")

	if Weapon then
		Weapon.SheathWeld.Enabled = not State
		Weapon.HandWeld.Enabled = State
	end

	if State then
		Character:SetAttribute("AnimationPreset", Character:GetAttribute("Stance"))
	else
		Character:SetAttribute("SwordOnFire", false)
		Character:SetAttribute("ConfettiOnSword", false)
		Character:SetAttribute("AnimationPreset", "Default")
	end
end
function WeaponService.Client:Equip(Player: Player, State: boolean, UnequipDelay: number)
	self.Server:Equip(Player.Character, State, UnequipDelay)
end

function WeaponService:UnloadWeapon(Character: Model)
	Character.Assets.Weapon:ClearAllChildren()
	Character:SetAttribute("WeaponType", nil)
end
function WeaponService:LoadWeapon(Character: Model)
	if not Character:GetAttribute("Weapon") then
		return
	end

	local Torso = Character:WaitForChild("Torso", 3)

	local WeaponFolder = Weapons:FindFirstChild(Character:GetAttribute("Weapon"))
	if not WeaponFolder then
		return
	end

	WeaponService:UnloadWeapon(Character)

	local WeaponData = ItemService:GetItemData(Character:GetAttribute("Weapon"))
	if WeaponData then
		Character:SetAttribute("WeaponType", WeaponData.Type)
	end

	local Weapon = WeaponFolder.Weapon:Clone()
	ScaleInstanceToCharacter(Weapon, Character)

	if Weapon:FindFirstChild("Right Arm") and Weapon:FindFirstChild("Left Arm") then
		RenderService:WeldConstraint(Character["Right Arm"], Weapon["Right Arm"])
		Weapon["Right Arm"].CFrame = Character["Right Arm"].CFrame

		RenderService:WeldConstraint(Character["Left Arm"], Weapon["Left Arm"])
		Weapon["Left Arm"].CFrame = Character["Left Arm"].CFrame

		Weapon.Parent = Character.Assets.Weapon
	else
		Weapon.HandWeld.Part1 = Weapon.PrimaryPart
		Weapon.SheathWeld.Part0 = Torso
		Weapon.SheathWeld.Enabled = true
		Weapon.HandWeld.Part0 = Character.RightHand
		Weapon.HandWeld.Part1 = Weapon.PrimaryPart
		Weapon.Parent = Character.Assets.Weapon

		local Sheath = WeaponFolder:FindFirstChild("Sheath")
		if Sheath then
			local Sheath = Sheath:Clone()
			ScaleInstanceToCharacter(Sheath, Character)
			Sheath.SheathWeld.Part1 = Sheath.PrimaryPart
			Sheath.SheathWeld.Part0 = Character.SheathPart
			Sheath.SheathWeld.Enabled = true
			Sheath.Parent = Character.Assets.Weapon
		end
	end

	WeaponService:SwordTrailsEnabled(Character, false)
end

local StanceAnimations = game.ReplicatedStorage.Assets.Animations.Stances
function WeaponService:GetStanceAnimationFolder(Character: Model)
	local Stance = Character:GetAttribute("Stance") or "Beginner"
	return StanceAnimations[Stance]
end

local CombatAnimations = game.ReplicatedStorage.Assets.Animations.Combat
function WeaponService:GetCombatAnimationFolder(Character: Model)
	local WeaponType = Character:GetAttribute("WeaponType") or "Default"

	if CombatAnimations:FindFirstChild(WeaponType) == nil then
		WeaponType = "Default"
	end

	return CombatAnimations[WeaponType]
end

function WeaponService:IncreaseComboCounter(Character: Model)
	if Character:GetAttribute("ComboDebounce") then
		return
	end

	local AttackAnimations = WeaponService:GetStanceAnimationFolder(Character).M1

	Character:SetAttribute("LastAttackTick", tick())

	local ComboDebounceDuration = 0.85
	local ComboCounterReset = 2.5
	if #AttackAnimations:GetChildren() > Character:GetAttribute("ComboCounter") then
		Character:SetAttribute("ComboCounter", Character:GetAttribute("ComboCounter") + 1)
	else
		Character:SetAttribute("ComboCounter", 0)
		DebounceService:AddDebounce(Character, "ComboDebounce", ComboDebounceDuration)
	end

	task.delay(ComboCounterReset, function()
		if Character:GetAttribute("LastAttackTick") + ComboCounterReset <= tick() then
			Character:SetAttribute("ComboCounter", 0)
		end
	end)

	return Character:GetAttribute("ComboCounter")
end

function WeaponService:Fling(Character: Model, Attacker: Model)
	local Direction = CFrame.new(Attacker:GetPivot().Position, Character:GetPivot().Position).LookVector
	RagdollService:Ragdoll(Character, 1.4, Direction, 1)
end

function WeaponService:IsLastAttack(Character: Model)
	return Character:GetAttribute("ComboCounter") >= #WeaponService:GetStanceAnimationFolder(Character).M1:GetChildren()
end
function WeaponService:TryFling(Character: Model, Attacker: Model)
	if WeaponService:IsLastAttack(Attacker) then
		WeaponService:Fling(Character, Attacker)
	end
end

function WeaponService:ShowSlash(Attacker: Model, Animation: Animation)
	RenderService:RenderForAllPlayers("Combat", "AttackSlash", {
		Character = Attacker,
		SlashInstance = Animation:FindFirstChild("Slash"),
	})
end

function WeaponService:PlayM1Animation(Character: Model)
	local AttackAnimations = WeaponService:GetStanceAnimationFolder(Character).M1

	AnimationService:StopAttackAnimations(Character)

	local Track: AnimationTrack =
		AnimationService:PlayAnimation(Character, AttackAnimations["M1_" .. Character:GetAttribute("ComboCounter")])
	Track.Priority = Enum.AnimationPriority.Action2
	Track:Play()

	return Track, AttackAnimations["M1_" .. Character:GetAttribute("ComboCounter")]
end

function WeaponService:SwordTrailsEnabled(Character: Model, State: boolean)
	local Assets = Character.Assets
	local Weapon = Assets.Weapon

	local TrailsFound = {}

	for _, Part in Weapon.Weapon:GetChildren() do
		if Part.Name == "SwordTrail" then
			table.insert(TrailsFound, Part)
		end
	end

	if #TrailsFound == 0 then
		local SwordTrail = Weapon:FindFirstChild("SwordTrail", true)
		if SwordTrail then
			table.insert(TrailsFound, SwordTrail)
		end
	end

	for _, Trail in TrailsFound do
		Trail.Enabled = State
	end
end

function WeaponService:WeaponInput(Character: Model, Action: string, Data: { any })
	Data = Data or {}
	Data.Server = Data.Server or {}
	Data.RootCFrame = Data.RootCFrame or Character:GetPivot()

	if (Data.RootCFrame.Position - Character:GetPivot().Position).Magnitude > 10 then
		Data.RootCFrame = Character:GetPivot()
	end

	local StanceName = Character:GetAttribute("Stance")

	local WeaponModule = WeaponsModules[StanceName]
	if WeaponModule and WeaponModule[Action] then
		WeaponModule[Action](Character, Data)
		return
	end

	local WeaponTypeModule = WeaponsModules[Character:GetAttribute("WeaponType")]
	if WeaponTypeModule and WeaponTypeModule[Action] then
		WeaponTypeModule[Action](Character, Data)
		return
	end

	local DefaultModule = WeaponsModules["Weapons"]
	if DefaultModule and DefaultModule[Action] then
		DefaultModule[Action](Character, Data)
		return
	end
end
function WeaponService.Client:WeaponInput(Player: Player, Action: string, Data: { any })
	local Character = Player.Character
	if not Character then
		return
	end

	Data.Server = {}

	self.Server:WeaponInput(Character, Action, Data)
end

WeaponService.CancelM1Attributes = {
	"Died",
	"Downed",
	"Ragdoll",
	"BeenHitted",
	"Blocking",
	"Rolling",
	"BeenDeflected",
}
function WeaponService:DidCancel(Attacker: Model)
	if Attacker:GetAttribute("Stunless") then
		return false
	end

	for _, att in WeaponService.CancelM1Attributes do
		if Attacker:GetAttribute(att) == true then
			return true
		end
	end

	return false
end

function WeaponService.KnitInit()
	DebounceService = Knit.GetService("DebounceService")
	AnimationService = Knit.GetService("AnimationService")
	RagdollService = Knit.GetService("RagdollService")
	RenderService = Knit.GetService("RenderService")
	BloodService = Knit.GetService("BloodService")
	SoundEffectService = Knit.GetService("SoundEffectService")
	ItemService = Knit.GetService("ItemService")

	for _, Weapon in script:GetDescendants() do
		if Weapon:IsA("ModuleScript") then
			WeaponsModules[Weapon.Name] = require(Weapon)
		end
	end
end

function WeaponService.KnitStart() end

return WeaponService
