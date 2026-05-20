local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local CharacterService = Knit.CreateService({
	Name = "CharacterService",
	Client = {
		CharacterDowned = Knit.CreateSignal(),
		Died = Knit.CreateSignal(),
	},
})

local DataService
local WeaponService
local ItemService
local RagdollService
local DebounceService
local RewardService
local ValuesService
local ToolService
local SkillService
local EquipmentService
local QuestService
local PlayerService
local RaceService
local DamageService
local SkillTreeService
local InteractionService
local HitboxService
local InCombatService
local PrisonService

local CachedParts = {}
local CharacterShared = require(game.ReplicatedStorage.Shared.CharacterShared)

function CharacterService:SetAttributes(Character: Model, Player: Player?)
	Character:SetAttribute("Health", 100)
	Character:SetAttribute("MaxHealth", 100)
	Character:SetAttribute("Regeneration", 0.01)

	Character:SetAttribute("Stamina", 100)
	Character:SetAttribute("MaxStamina", 100)

	Character:SetAttribute("Posture", 0)
	Character:SetAttribute("MaxPosture", 100)

	Character:SetAttribute("ComboCounter", 0)
	Character:SetAttribute("InCombat", false)
	Character:SetAttribute("Downed", false)
	Character:SetAttribute("Carried", false)
	Character:SetAttribute("Ragdoll", false)
	Character:SetAttribute("BeenHitted", false)
	Character:SetAttribute("HasHitted", false)
	Character:SetAttribute("SkillLockMovement", false)

	Character:SetAttribute("StopBlockingTick", 0)
	Character:SetAttribute("BeenBlocked", false)
	Character:SetAttribute("HasBlocked", false)

	Character:SetAttribute("Clashed", false)

	Character:SetAttribute("BeenDeflected", false)
	Character:SetAttribute("HasDeflected", false)

	Character:SetAttribute("Died", false)

	Character:SetAttribute("DefaultWalkSpeed", 12)
	Character:SetAttribute("DefaultJumpPower", 40)
	Character:SetAttribute("RunningWalkSpeed", 24)

	local EyesColor = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
	if Player then
		local PlayerData = DataService:GetData(Player)
		EyesColor = Color3.fromRGB(PlayerData.EyesColor[1], PlayerData.EyesColor[2], PlayerData.EyesColor[3])
	end

	Character:SetAttribute("EyesColor", EyesColor)

	Character:SetAttribute("WeaponEquipped", false)
	CharacterShared:UpdateBoth(Character)

	if Player then
		local PlayerData = DataService:GetData(Player)
		Character:SetAttribute("Weapon", PlayerData.Equipped.Weapon)

		if not Character:GetAttribute("Stance") then
			Character:SetAttribute("Stance", PlayerData.SelectedStance)
		end

		Character:SetAttribute("Artifact", PlayerData.Artifact)
		Character:SetAttribute("Race", PlayerData.Race)
		Character:SetAttribute("RaceVariant", PlayerData.RaceVariant)

		local WeaponName = PlayerData.Equipped.Weapon
		local WeaponData = ItemService:GetItemData(WeaponName)

		if WeaponData then
			Character:SetAttribute("WeaponType", WeaponData.Type)
		end
	else
		if Character:GetAttribute("Weapon") then
			local WeaponData = ItemService:GetItemData(Character:GetAttribute("Weapon"))

			if WeaponData then
				Character:SetAttribute("WeaponType", WeaponData.Type)
			end
		end
	end

	if not Character:GetAttribute("Stance") then
		Character:SetAttribute("Stance", "Beginner")
	end

	if not Character:GetAttribute("WeaponType") then
		Character:SetAttribute("AnimationPreset", "NoWeapon")
	end

	ValuesService:UpdateAll(Character, true)
end

local UpdateBothAttributes = {
	"Attack",
	"Attacking",
	"PostureBreak",
	"BeenDeflected",
	"HasDeflected",
	"BeenHitted",
	"HeavyDeflect",
	"HasBlocked",
	"BeenBlocked",
	"SkillLockMovement",
}

function CharacterService:BindEvents(Character: Model, Player: Player)
	Character:GetAttributeChangedSignal("Died"):Connect(function()
		if Character:GetAttribute("Died") then
			QuestService:CallQuestFunction(Player, "Died")
			SkillService:ClearSkillData(Character)

			local Player = Players:GetPlayerFromCharacter(Character)
			if Player then
				CharacterService.Client.Died:Fire(Player)
				InCombatService:SetInCombat(Character, false)
			end

			pcall(function()
				for _, Equipment in Character.CharacterAssets:GetDescendants() do
					Equipment:RemoveTag("SmartBone")
				end
			end)

			if Character:GetAttribute("IsAI") then
				RewardService:GiveRewards(Character, Character:GetPivot().Position)
				task.wait(3)
				Character:Destroy()
				return
			end

			task.wait(10)
			Character:Destroy()

			if Player then
				CharacterService:LoadCharacter(Player)
			end
		end
	end)

	Character:GetAttributeChangedSignal("WeaponType"):Connect(function()
		if not Character:GetAttribute("WeaponType") then
			Character:SetAttribute("AnimationPreset", "NoWeapon")
		else
			if not Character:GetAttribute("WeaponEquipped") then
				Character:SetAttribute("AnimationPreset", "Default")
			end
		end
	end)

	Character:GetAttributeChangedSignal("Downed"):Connect(function()
		local Player = Players:GetPlayerFromCharacter(Character)
		if Character:GetAttribute("Downed") then
			--InteractionService:CreateButton(Character, Enum.KeyCode.C, "Carry", "CarryPrompt", nil, 2, "Carry")
			RagdollService:Ragdoll(Character)
			if Player then
				CharacterService.Client.CharacterDowned:Fire(Player)
			end
		else
			if Character:FindFirstChild("CarryPrompt") then
				Character:FindFirstChild("CarryPrompt"):Destroy()
			end
			if Character:GetAttribute("Ragdoll") then
				RagdollService:Unragdoll(Character)
			end
			local Humanoid = Character:FindFirstChild("Humanoid") :: Humanoid
			Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)

	Character:GetAttributeChangedSignal("Attacking"):Connect(function()
		if not Character:GetAttribute("Attacking") then
			WeaponService:SwordTrailsEnabled(Character, false)
		end
	end)

	Character:GetAttributeChangedSignal("Carried"):Connect(function()
		local MinHealthToGetUp = Character:GetAttribute("MaxHealth") * 0.2
		if not Character:GetAttribute("Carried") and Character:GetAttribute("Health") >= MinHealthToGetUp then
			RagdollService:Unragdoll(Character)
			local Humanoid = Character:FindFirstChild("Humanoid") :: Humanoid
			Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			if Character:FindFirstChild("CarryPrompt") then
				Character:FindFirstChild("CarryPrompt"):Destroy()
			end
			for i, v in pairs(Character:GetChildren()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
					v.CollisionGroup = "Entity"
					if CachedParts[v] then
						if CachedParts[v].Massless ~= nil then
							v.Massless = not CachedParts[v].Massless
						end
					end
				end
			end
		elseif Character:GetAttribute("Health") < MinHealthToGetUp and not Character:GetAttribute("Carried") then
			InteractionService:CreateButton(Character, Enum.KeyCode.C, "Carry", "CarryPrompt", nil, 2, "Carry")
			for i, v in pairs(Character:GetChildren()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
					v.CollisionGroup = "Entity"
					if CachedParts[v] then
						if CachedParts[v].Massless ~= nil then
							v.Massless = not CachedParts[v].Massless
						end
					end
				end
			end
		elseif Character:GetAttribute("Carried") then
			for i, v in pairs(Character:GetChildren()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
					v.CollisionGroup = "Carried"
					CachedParts[v] = {
						Massless = true,
					}
					v.Massless = true
				end
			end
		end
	end)

	Character:GetAttributeChangedSignal("Health"):Connect(function()
		local MinHealthToGetUp = Character:GetAttribute("MaxHealth") * 0.2
		if
			Character:GetAttribute("Downed")
			and Character:GetAttribute("Health") >= MinHealthToGetUp
			and not Character:GetAttribute("Carried")
		then
			Character:SetAttribute("Downed", false)
			RagdollService:Unragdoll(Character)
		end
	end)

	for _, att in UpdateBothAttributes do
		Character:GetAttributeChangedSignal(att):Connect(function()
			if Character:GetAttribute("Stunless") then
				CharacterShared:ChangeJumpPower(Character, Character:GetAttribute("DefaultJumpPower"), att)
				CharacterShared:ChangeWalkSpeed(Character, Character:GetAttribute("DefaultWalkSpeed"), att)
				return
			end
			CharacterShared:UpdateBoth(Character)
		end)
	end

	Character:GetAttributeChangedSignal("Running"):Connect(function()
		if not Character:GetAttribute("Running") then
			CharacterShared:UpdateBoth(Character)
		end
	end)

end

function CharacterService:SetStates(Character: Model)
	local Humanoid: Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then
		return
	end

	Character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
end

function CharacterService:EnableForceField(Character: Model, state: boolean)
	Character:SetAttribute("ForceField", state)

	if state then
		local ForceField = Character:FindFirstChild("ForceField")
		if ForceField then
			ForceField:Destroy()
		end

		self:SetCollisionGroup(Character, "ForceField")

		local ForceField = game.ReplicatedStorage.Assets.VFX.Misc.ForceField:Clone()
		ForceField.Parent = Character
		ForceField.Script.Enabled = true
	else
		local ForceField = Character:FindFirstChild("ForceField")
		self:SetCollisionGroup(Character)
		if ForceField then
			ForceField:Destroy()
		end
	end
end

function CharacterService:SetCollisionGroup(Character: Model, group: string?)
	for _, Part in Character:GetChildren() do
		if Part:IsA("BasePart") then
			if Character:GetAttribute("Big") then
				Part.CollisionGroup = "BigEntity"
			else
				Part.CollisionGroup = group or "Entity"
			end
		end
	end
end

function CharacterService:RemoveCollision(Character: Model, debug: boolean?)
	CharacterService:SetCollisionGroup(Character, "Carried")
	Character.Humanoid.PlatformStand = true
	for _, Part: Instance in pairs(Character:GetChildren()) do
		if Part:IsA("BasePart") or Part:IsA("Part") then
			Part.CanCollide = false
		end
	end
end

function CharacterService:RestoreCollision(Character: Model, debug: boolean?)
	CharacterService:SetCollisionGroup(Character, "Entity")
	for _, Part: Instance in pairs(Character:GetChildren()) do
		if Part:IsA("BasePart") or Part:IsA("Part") then
			Part.CanCollide = true
		end
	end
end

function CharacterService:LoadCharacter(Player: Player)
	if Player.Parent ~= game.Players then
		return
	end

	Player:LoadCharacter()

	local Character = Player.Character or Player.CharacterAdded:Wait()
	InCombatService:SetInCombat(Character, false)
	local RootPart = Character:WaitForChild("HumanoidRootPart")
	RootPart.Anchored = true
	self:SetCollisionGroup(Character)
	repeat
		Character.Parent = game.Workspace.Entity
		task.wait()
	until Character.Parent == game.Workspace.Entity

	if not Player:GetAttribute("NoForceField") then
		CharacterService:EnableForceField(Character, true)
	end

	DebounceService:RemoveCharacterDebounces(Character)

	CharacterService:LoadHairByUserId(Character, Player.UserId)

	CharacterService:SetAttributes(Character, Player)
	CharacterService:SetStates(Character)
	CharacterService:BindEvents(Character, Player)
	CharacterService:BindRegeneration(Character)

	RaceService:LoadRaceAssets(Character)
	EquipmentService:LoadEquipments(Player)
	ValuesService:UpdateAll(Character, true)

	WeaponService:LoadWeapon(Character)
	ToolService:LoadPlayerTools(Player)

	PrisonService:CheckJoin(Player)

	if not Character or not Character.Parent or not Character:FindFirstChild("HumanoidRootPart") then
		return
	end

	Character:AddTag("Character")
	Character:AddTag("Entity")

	HitboxService:LoadR6Hitbox(Character)

	RootPart.Anchored = false

	Character:SetAttribute("Loaded", true)
end

function CharacterService:LoadHairByUserId(Character: Model, UserId: number)
	local success, err = pcall(function()
		local HumanoidDescription: HumanoidDescription = Players:GetHumanoidDescriptionFromUserId(UserId) or {}

		local hairAccessories = {}
		for _, info in HumanoidDescription:GetAccessories(false) do
			if info.AccessoryType == Enum.AccessoryType.Hair then
				table.insert(hairAccessories, info)
			end
		end
		
		if #hairAccessories == 0 then
			return
		end
		

		local OtherHumanoidDescription = Instance.new("HumanoidDescription")
		OtherHumanoidDescription.HeadColor = HumanoidDescription.HeadColor
		OtherHumanoidDescription.TorsoColor = HumanoidDescription.TorsoColor
		OtherHumanoidDescription.LeftArmColor = HumanoidDescription.LeftArmColor
		OtherHumanoidDescription.RightArmColor = HumanoidDescription.RightArmColor
		OtherHumanoidDescription.LeftLegColor = HumanoidDescription.LeftLegColor
		OtherHumanoidDescription.RightLegColor = HumanoidDescription.RightLegColor
		
		OtherHumanoidDescription:SetAccessories(hairAccessories, false)


		local HeadItem = Character:GetAttribute("Head")
		if HeadItem then
			local HeadItemData = ItemService:GetItemData(HeadItem)

			if HeadItemData.HideHair then
				return
			end
		end


		local Humanoid: Humanoid = Character:FindFirstChild("Humanoid")

		if not Humanoid then
			return
		end

		Humanoid:ApplyDescriptionResetAsync(OtherHumanoidDescription)

		for i, accessory in Character:GetChildren() do
			if not accessory:IsA("Accessory") then
				continue
			end

			accessory.Name = "Hair"

			for i, handle in ipairs(accessory:GetChildren()) do
				if handle:IsA("BasePart") then
					handle.CanCollide = false
					handle.Anchored = false
					handle.Massless = true
				end
			end
		end

		HumanoidDescription:Destroy()
		OtherHumanoidDescription:Destroy()
	end)

	if not success then
		warn(err)
	end
end

function CharacterService:BindRegeneration(Character: Model)
	task.spawn(function()
		while Character and not Character:GetAttribute("Died") do
			local MaxHealth = Character:GetAttribute("MaxHealth") or 100
			local Health = Character:GetAttribute("Health") or MaxHealth
			local MaxStamina = Character:GetAttribute("MaxStamina") or 100
			local Stamina = Character:GetAttribute("Stamina") or MaxStamina
			local MaxPosture = Character:GetAttribute("MaxPosture") or 100
			local Posture = Character:GetAttribute("Posture") or MaxPosture
			local Regen = Character:GetAttribute("Regeneration") or 0
			local Downed = Character:GetAttribute("Downed")
			local InCombat = Character:GetAttribute("InCombat")
			local IsAI = Character:GetAttribute("IsAI")
			local Attacking = Character:GetAttribute("Attacking") or Character:GetAttribute("Attack")
			local Running = Character:GetAttribute("Running")
			local Climbing = Character:GetAttribute("Climbing")
			local BurnDamage = Character:GetAttribute("BurnDamage") or 0

			-- Health regen
			if Downed or not InCombat then
				local regenAmount = MaxHealth * Regen
				if IsAI then
					regenAmount = MaxHealth * (Downed and 0.01 or 0.05)
				end
				local newHealth = math.clamp(Health + regenAmount, 0, MaxHealth)
				if newHealth ~= Health then
					Character:SetAttribute("Health", newHealth)
				end
			end

			-- Burn damage
			if BurnDamage > 0 then
				DamageService:DealDamage(Character, BurnDamage)
			end

			-- Stamina regen
			local DontDrain = SkillTreeService:IsSkillUnlocked(Character, "No Run Stamina Drain")
			if
				Stamina < MaxStamina
				and not Attacking
				and not (Climbing and InCombat)
				and not (Running and (not DontDrain or InCombat))
			then
				local newStamina = math.clamp(Stamina + MaxStamina * 0.05, 0, MaxStamina)
				if newStamina ~= Stamina then
					Character:SetAttribute("Stamina", newStamina)
				end
			end

			-- Posture recovery
			if Posture > 0 then
				local newPosture = math.clamp(Posture - MaxPosture * (Regen + 0.01), 0, MaxPosture)
				if newPosture ~= Posture then
					Character:SetAttribute("Posture", newPosture)
				end
			end

			task.wait(1)
		end
	end)
end

function CharacterService.KnitInit()
	PhysicsService:RegisterCollisionGroup("ForceField")
	PhysicsService:RegisterCollisionGroup("Entity")
	PhysicsService:RegisterCollisionGroup("BigEntity")
	PhysicsService:RegisterCollisionGroup("Carried")

	PhysicsService:CollisionGroupSetCollidable("Carried", "ForceField", false)
	PhysicsService:CollisionGroupSetCollidable("Carried", "Debris", false)
	PhysicsService:CollisionGroupSetCollidable("Carried", "Entity", false)

	PhysicsService:CollisionGroupSetCollidable("ForceField", "ForceField", false)
	PhysicsService:CollisionGroupSetCollidable("Entity", "ForceField", false)
	PhysicsService:CollisionGroupSetCollidable("Entity", "Debris", false)

	PhysicsService:CollisionGroupSetCollidable("BigEntity", "Entity", false)
	PhysicsService:CollisionGroupSetCollidable("BigEntity", "BigEntity", false)
	PhysicsService:CollisionGroupSetCollidable("BigEntity", "ForceField", false)
	PhysicsService:CollisionGroupSetCollidable("BigEntity", "Debris", false)

	DataService = Knit.GetService("DataService")
	WeaponService = Knit.GetService("WeaponService")
	ItemService = Knit.GetService("ItemService")
	RagdollService = Knit.GetService("RagdollService")
	DebounceService = Knit.GetService("DebounceService")
	RewardService = Knit.GetService("RewardService")
	ValuesService = Knit.GetService("ValuesService")
	ToolService = Knit.GetService("ToolService")
	SkillService = Knit.GetService("SkillService")
	EquipmentService = Knit.GetService("EquipmentService")
	QuestService = Knit.GetService("QuestService")
	PlayerService = Knit.GetService("PlayerService")
	RaceService = Knit.GetService("RaceService")
	DamageService = Knit.GetService("DamageService")
	SkillTreeService = Knit.GetService("SkillTreeService")
	InteractionService = Knit.GetService("InteractionService")
	HitboxService = Knit.GetService("HitboxService")
	InCombatService = Knit.GetService("InCombatService")
	PrisonService = Knit.GetService("PrisonService")
	local Entity = Instance.new("Folder")
	Entity.Name = "Entity"
	Entity.Parent = game.Workspace
end

function CharacterService.KnitStart() end

return CharacterService
