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
local Stances = require(game.ReplicatedStorage.Shared.Index.Stances)

local WeaponSlots = {
	{ WeaponName = "Weapon", SheathName = "Sheath" },
	{ WeaponName = "LeftWeapon", SheathName = "LeftSheath" },
}

local LeftWeaponSheathCFrame = CFrame.new(-1, 0.025, -1.4) * CFrame.Angles(0, math.rad(90), math.rad(110))
local LeftSheathCFrame = CFrame.new(0, -0.55, 1.65) * CFrame.Angles(0, math.rad(90), math.rad(110))

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

local function GetHand(Character: Model, Side: string): BasePart?
	return Character:FindFirstChild(Side .. "Hand") or Character:FindFirstChild(Side .. " Arm")
end

local function WaitForBasePart(Parent: Instance, Name: string): BasePart?
	local Part = Parent:FindFirstChild(Name) or Parent:WaitForChild(Name, 3)
	if Part and Part:IsA("BasePart") then
		return Part
	end

	return nil
end

local function GetSheathPart(Character: Model, IsLeftWeapon: boolean): BasePart?
	if IsLeftWeapon then
		return WaitForBasePart(Character, "SheathPart2")
	end

	return WaitForBasePart(Character, "SheathPart")
end

local function GetWeld(InstanceToSearch: Instance, Name: string): Weld?
	local Weld = InstanceToSearch:FindFirstChild(Name)
	if Weld and Weld:IsA("Weld") then
		return Weld
	end

	return nil
end

local function SetWeldEnabled(Model: Model, WeldName: string, Enabled: boolean)
	local Weld = GetWeld(Model, WeldName)
	if Weld then
		Weld.Enabled = Enabled
	end
end

local function GetWeaponHandWeld(Weapon: Model, IsLeftWeapon: boolean): (Weld?, boolean)
	if IsLeftWeapon then
		local LeftHandWeld = GetWeld(Weapon, "LeftHandWeld")
		if LeftHandWeld then
			return LeftHandWeld, true
		end
	end

	return GetWeld(Weapon, "HandWeld"), false
end

local function GetWeaponSheathWeld(Weapon: Model, IsLeftWeapon: boolean): (Weld?, boolean)
	if IsLeftWeapon then
		local Sheath2Weld = GetWeld(Weapon, "Sheath2Weld")
		if Sheath2Weld then
			return Sheath2Weld, true
		end
	end

	return GetWeld(Weapon, "SheathWeld"), false
end

local function GetSheathWeld(Sheath: Model, IsLeftWeapon: boolean): (Weld?, boolean)
	if IsLeftWeapon then
		local Sheath2Weld = GetWeld(Sheath, "Sheath2Weld")
		if Sheath2Weld then
			return Sheath2Weld, true
		end
	end

	return GetWeld(Sheath, "SheathWeld"), false
end

local function GetStanceData(Character: Model, StanceName: string?)
	return Stances[StanceName or Character:GetAttribute("Stance")]
end

local function IsDualWieldStance(Character: Model, StanceName: string?): boolean
	local StanceData = GetStanceData(Character, StanceName)
	return StanceData and StanceData.DualWield == true
end

local function DestroyWeaponSlot(Character: Model, WeaponName: string, SheathName: string)
	local WeaponFolder = Character.Assets.Weapon

	local Weapon = WeaponFolder:FindFirstChild(WeaponName)
	if Weapon then
		Weapon:Destroy()
	end

	local Sheath = WeaponFolder:FindFirstChild(SheathName)
	if Sheath then
		Sheath:Destroy()
	end
end

local function SetWeaponEquipState(Weapon: Model, State: boolean)
	local IsLeftWeapon = Weapon.Name == "LeftWeapon"
	local HandWeld = GetWeaponHandWeld(Weapon, IsLeftWeapon)
	local SheathWeld = GetWeaponSheathWeld(Weapon, IsLeftWeapon)

	SetWeldEnabled(Weapon, "HandWeld", false)
	SetWeldEnabled(Weapon, "LeftHandWeld", false)
	SetWeldEnabled(Weapon, "SheathWeld", false)
	SetWeldEnabled(Weapon, "Sheath2Weld", false)

	if HandWeld then
		HandWeld.Enabled = State
	end

	if SheathWeld then
		SheathWeld.Enabled = not State
	end
end

local function NormalizeWeaponSide(WeaponSide: string?): string
	if WeaponSide == "Left" or WeaponSide == "Right" then
		return WeaponSide
	end

	return "Both"
end

local function GetWeaponModels(Character: Model, WeaponSide: string?): { Model }
	local WeaponFolder = Character.Assets.Weapon
	local Models = {}
	local NormalizedSide = NormalizeWeaponSide(WeaponSide)

	local function AddWeaponModel(WeaponName: string)
		local Weapon = WeaponFolder:FindFirstChild(WeaponName)
		if Weapon and Weapon:IsA("Model") then
			table.insert(Models, Weapon)
		end
	end

	if NormalizedSide == "Right" then
		AddWeaponModel("Weapon")
	elseif NormalizedSide == "Left" then
		AddWeaponModel("LeftWeapon")
	else
		for _, Slot in WeaponSlots do
			AddWeaponModel(Slot.WeaponName)
		end
	end

	return Models
end

local function LoadWeaponModel(Character: Model, WeaponFolder: Instance, WeaponName: string, SheathName: string, HandSide: string)
	local Torso = Character:WaitForChild("Torso", 3)
	local Hand = GetHand(Character, HandSide)
	local IsLeftWeapon = WeaponName == "LeftWeapon"

	if not Torso or not Hand then
		return
	end

	local Weapon = WeaponFolder.Weapon:Clone()
	Weapon.Name = WeaponName
	ScaleInstanceToCharacter(Weapon, Character)

	if Weapon:FindFirstChild("Right Arm") and Weapon:FindFirstChild("Left Arm") then
		RenderService:WeldConstraint(Character["Right Arm"], Weapon["Right Arm"])
		Weapon["Right Arm"].CFrame = Character["Right Arm"].CFrame

		RenderService:WeldConstraint(Character["Left Arm"], Weapon["Left Arm"])
		Weapon["Left Arm"].CFrame = Character["Left Arm"].CFrame

		Weapon.Parent = Character.Assets.Weapon
	else
		local HandWeld = GetWeaponHandWeld(Weapon, IsLeftWeapon)
		local SheathWeld, HasLeftSheathWeld = GetWeaponSheathWeld(Weapon, IsLeftWeapon)

		if not Weapon.PrimaryPart or not HandWeld or not SheathWeld then
			Weapon:Destroy()
			return
		end

		HandWeld.Part1 = Weapon.PrimaryPart
		SheathWeld.Part0 = Torso
		SheathWeld.Part1 = Weapon.PrimaryPart
		if IsLeftWeapon and not HasLeftSheathWeld then
			SheathWeld.C0 = LeftWeaponSheathCFrame
			SheathWeld.C1 = CFrame.new()
		end

		HandWeld.Part0 = Hand
		HandWeld.Part1 = Weapon.PrimaryPart
		Weapon.Parent = Character.Assets.Weapon

		local Sheath = WeaponFolder:FindFirstChild("Sheath")
		if Sheath then
			local Sheath = Sheath:Clone()
			Sheath.Name = SheathName
			ScaleInstanceToCharacter(Sheath, Character)
			local SheathWeld, HasLeftSheathWeld = GetSheathWeld(Sheath, IsLeftWeapon)
			local SheathPart = GetSheathPart(Character, IsLeftWeapon)

			if Sheath.PrimaryPart and SheathWeld and SheathPart then
				SetWeldEnabled(Sheath, "SheathWeld", false)
				SetWeldEnabled(Sheath, "Sheath2Weld", false)

				SheathWeld.Part1 = Sheath.PrimaryPart
				SheathWeld.Part0 = SheathPart
				if IsLeftWeapon and not HasLeftSheathWeld then
					SheathWeld.C0 = LeftSheathCFrame
					SheathWeld.C1 = CFrame.new()
				end
				SheathWeld.Enabled = true
				Sheath.Parent = Character.Assets.Weapon
			else
				Sheath:Destroy()
			end
		end
	end

	SetWeaponEquipState(Weapon, Character:GetAttribute("WeaponEquipped"))

	return Weapon
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
		UnequipDelay = math.clamp(_UnequipDelay, 0, 1.4)
	else
		UnequipDelay = 1.4
	end

	local DebounceDelay = UnequipDelay or 0

	local CombatAnimations = WeaponService:GetCombatAnimationFolder(Character)

	local IsFastUnequip = false
	if not State then
		local UnequipAnimation
		if not Character:GetAttribute("InCombat") then
			UnequipAnimation =  AnimationService:PlayAnimation(Character, CombatAnimations.Unequip)
			SoundEffectService:PlaySoundEffect("WeaponUnequip", true, Character.PrimaryPart)
			
		else
			UnequipDelay = 1
			IsFastUnequip = true
			UnequipAnimation =  AnimationService:PlayAnimation(Character, CombatAnimations.FastUnequip)
			SoundEffectService:PlaySoundEffect("FastWeaponUnequip", true, Character.PrimaryPart)
			
		end

		UnequipAnimation.Priority = Enum.AnimationPriority.Action2
		Character:SetAttribute("Blocking", false)
		--Character:SetAttribute("Running", false)
	end

	DebounceService:AddDebounce(Character, "EquipDebounce", 1 + DebounceDelay)
	

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
		if not IsFastUnequip then
			task.delay(0.15, function()
				BloodService:RemoveBloodFromBlade(Character)
				RenderService:RenderForAllPlayers("Combat", "UnequipBlood", { Character = Character })
			end)
		else
			task.delay(0.5, function()
				BloodService:RemoveBloodFromBlade(Character)
			end)
		end
	end

	if State then
		SoundEffectService:PlaySoundEffect("EquipDraw", true, Character.PrimaryPart)
	end
	if not State and UnequipDelay then
		task.wait(UnequipDelay)
	end

	for _, Weapon in GetWeaponModels(Character) do
		SetWeaponEquipState(Weapon, State)
	end

	if State then
		Character:SetAttribute("AnimationPreset", Character:GetAttribute("Stance"))
	else
		Character:SetAttribute("SwordOnFire", false)
		Character:SetAttribute("ConfettiOnSword", false)
		Character:SetAttribute("AnimationPreset", "Default")
	end
end
function WeaponService.Client:Equip(Player: Player, State: boolean)
	self.Server:Equip(Player.Character, State)
end

function WeaponService:UnloadRightWeapon(Character: Model)
	DestroyWeaponSlot(Character, "Weapon", "Sheath")
	Character:SetAttribute("WeaponType", nil)
end

function WeaponService:UnloadLeftWeapon(Character: Model)
	DestroyWeaponSlot(Character, "LeftWeapon", "LeftSheath")
	Character:SetAttribute("LeftWeapon", nil)
	Character:SetAttribute("LeftWeaponType", nil)
end

function WeaponService:UnloadWeapon(Character: Model)
	Character.Assets.Weapon:ClearAllChildren()
	Character:SetAttribute("WeaponType", nil)
	Character:SetAttribute("LeftWeapon", nil)
	Character:SetAttribute("LeftWeaponType", nil)
end
function WeaponService:LoadWeapon(Character: Model, WeaponName: string?, LeftWeaponName: string?, StanceName: string?)
	WeaponName = WeaponName or Character:GetAttribute("Weapon")
	if not WeaponName then
		return
	end

	if StanceName then
		Character:SetAttribute("Stance", StanceName)
	end
	Character:SetAttribute("Weapon", WeaponName)
	Character:SetAttribute("LeftWeapon", LeftWeaponName)

	local WeaponFolder = Weapons:FindFirstChild(WeaponName)
	if not WeaponFolder then
		return
	end

	DestroyWeaponSlot(Character, "Weapon", "Sheath")

	local WeaponData = ItemService:GetItemData(WeaponName)
	if WeaponData then
		Character:SetAttribute("WeaponType", WeaponData.Type)
	end

	LoadWeaponModel(Character, WeaponFolder, "Weapon", "Sheath", "Right")
	WeaponService:LoadLeftWeapon(Character, LeftWeaponName, WeaponName, StanceName)

	WeaponService:SwordTrailsEnabled(Character, false)
end

function WeaponService:LoadLeftWeapon(Character: Model, LeftWeaponName: string?, RightWeaponName: string?, StanceName: string?)
	local UseProvidedData = RightWeaponName ~= nil or StanceName ~= nil
	RightWeaponName = RightWeaponName or Character:GetAttribute("Weapon")
	if not UseProvidedData then
		LeftWeaponName = LeftWeaponName or Character:GetAttribute("LeftWeapon")
	end

	if StanceName then
		Character:SetAttribute("Stance", StanceName)
	end
	if RightWeaponName then
		Character:SetAttribute("Weapon", RightWeaponName)
	end
	Character:SetAttribute("LeftWeapon", LeftWeaponName)

	if not IsDualWieldStance(Character, StanceName) or not RightWeaponName then
		DestroyWeaponSlot(Character, "LeftWeapon", "LeftSheath")
		Character:SetAttribute("LeftWeaponType", nil)
		return
	end

	local WeaponName = LeftWeaponName or RightWeaponName
	if not WeaponName then
		DestroyWeaponSlot(Character, "LeftWeapon", "LeftSheath")
		Character:SetAttribute("LeftWeaponType", nil)
		return
	end

	local WeaponFolder = Weapons:FindFirstChild(WeaponName)
	if not WeaponFolder then
		DestroyWeaponSlot(Character, "LeftWeapon", "LeftSheath")
		Character:SetAttribute("LeftWeaponType", nil)
		return
	end

	DestroyWeaponSlot(Character, "LeftWeapon", "LeftSheath")

	local WeaponData = ItemService:GetItemData(WeaponName)
	if WeaponData then
		Character:SetAttribute("LeftWeaponType", WeaponData.Type)
	end

	LoadWeaponModel(Character, WeaponFolder, "LeftWeapon", "LeftSheath", "Left")

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
	Track.Priority = Enum.AnimationPriority.Action4
	Track:Play(0.05)

	return Track, AttackAnimations["M1_" .. Character:GetAttribute("ComboCounter")]
end

function WeaponService:SwordTrailsEnabled(Character: Model, State: boolean, WeaponSide: string?)
	local TrailsFound = {}
	local NormalizedSide = NormalizeWeaponSide(WeaponSide)

	if State and NormalizedSide ~= "Both" then
		for _, Weapon in GetWeaponModels(Character) do
			local SwordTrail = Weapon:FindFirstChild("SwordTrail", true)
			if SwordTrail and SwordTrail:IsA("Trail") then
				SwordTrail.Enabled = false
			end
		end
	end

	for _, Weapon in GetWeaponModels(Character, NormalizedSide) do
		local FoundForWeapon = false

		for _, Part in Weapon:GetChildren() do
			if Part.Name == "SwordTrail" and Part:IsA("Trail") then
				FoundForWeapon = true
				table.insert(TrailsFound, Part)
			end
		end

		if not FoundForWeapon then
			local SwordTrail = Weapon:FindFirstChild("SwordTrail", true)
			if SwordTrail and SwordTrail:IsA("Trail") then
				table.insert(TrailsFound, SwordTrail)
			end
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
