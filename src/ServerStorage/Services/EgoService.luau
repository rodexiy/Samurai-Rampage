local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local EgoConfig = require(ReplicatedStorage.Shared.EgoConfig)
local Progression = require(ReplicatedStorage.Shared.StatProgression)
local CharacterShared = require(ReplicatedStorage.Shared.CharacterShared)

local EgoService = Knit.CreateService({
	Name = "EgoService",
	Client = { Toggle = Knit.CreateSignal(), Cancel = Knit.CreateSignal(), Cutscene = Knit.CreateSignal() },
})

type Exposure = { Source: Player, Pressure: number, Gain: number, Distance: number, SourceLevel: number, TargetLevel: number }
type Scene = { Source: Player, Character: Model }
local Active: { [Player]: Model } = {}
local ActionConnections: { [Player]: RBXScriptConnection } = {}
local Available: { string } = {}
local RandomGenerator = Random.new()
local LastToggle: { [Player]: number } = {}
local Scenes: { [Player]: Scene } = {}
local LastScene: { [Player]: number } = {}
local Pulse: RBXScriptConnection?
local Elapsed = 0
local StatService
local DataService
local FearService
local PartyService
local BowService
local AlertService

local InvalidStates = {
	"Died", "Downed", "Ragdoll", "Mounted", "Climbing", "WallRunning", "Vaulting",
	"PostureBreak", "HeavyDeflect", "BeenHitted", "RealmEditing", "RealmTeleporting", "CameraCutscene",
	"EgoCutscene", "SkillLockMovement", "UsingSkillCantAttack", "IntroOpening", "InCell", "InLabor",
	"Kicking",
}

local function IsAlive(Character: Model?): boolean
	local Humanoid = Character and Character:FindFirstChildWhichIsA("Humanoid")
	return Character ~= nil and Character:IsDescendantOf(workspace) and Character.PrimaryPart ~= nil
		and Humanoid ~= nil and Humanoid.Health > 0 and not Character:GetAttribute("Died")
end

function EgoService:SetEgo(Player: Player, Id: string): (boolean, string?)
	local Definition = EgoConfig.Definitions[Id]
	if not Definition then
		return false, "Unknown Ego ID."
	end

	local Asset = ReplicatedStorage.Assets.VFX.Ego:FindFirstChild(Definition.Aura)
	if not Asset or not Asset:IsA("Model") then
		return false, "Ego aura is unavailable."
	end

	local Data = DataService:GetData(Player)
	if not Data then
		return false, "Player data is not loaded."
	end

	Data.EgoId = Id
	Player:SetAttribute("EgoId", Id)
	if Player.Character then
		Player.Character:SetAttribute("EgoId", Id)
	end

	return true
end

function EgoService:AssignEgo(Player: Player): string?
	local Data = DataService:GetData(Player)
	if not Data then
		return nil
	end

	local Id = Data.EgoId
	if typeof(Id) ~= "string" or not EgoConfig.Definitions[Id] then
		if #Available == 0 then
			return nil
		end

		Id = Available[RandomGenerator:NextInteger(1, #Available)]
		Data.EgoId = Id
	end

	Player:SetAttribute("EgoId", Id)
	if Player.Character then
		Player.Character:SetAttribute("EgoId", Id)
	end

	return Id
end

function EgoService:GetLevel(Character: Model): number
	local Player = Players:GetPlayerFromCharacter(Character)
	if not Player then
		return math.max(0, Character:GetAttribute("Level") or 0)
	end

	local Level = 0
	for _, Name in Progression.Names do
		Level += StatService:GetLevel(Player, Name)
	end

	return Level
end

function EgoService:CanUse(Player: Player): boolean
	local Character = Player.Character
	if not IsAlive(Character) or not Character or Character:GetAttribute("Loaded") ~= true
		or Player:GetAttribute("InIntroCutscene") or Player:GetAttribute("InDialog") then
		return false
	end

	for _, Attribute in InvalidStates do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end
	for Attribute in EgoConfig.CancelStates do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end
	for _, Name in Progression.Names do
		if StatService:GetLevel(Player, Name) < EgoConfig.RequiredStatLevel then
			return false
		end
	end

	local SkillState = Character:GetAttribute("SkillState")
	return SkillState ~= "Charge" and SkillState ~= "Charged"
end

local function FinishScene(Player: Player)
	local Scene = Scenes[Player]
	if not Scene then
		return
	end

	Scenes[Player] = nil
	Scene.Character:SetAttribute("EgoCutscene", false)
	if Scene.Character.Parent then
		CharacterShared:UpdateBoth(Scene.Character)
	end
	if Player.Parent == Players then
		EgoService.Client.Cutscene:Fire(Player, nil)
	end
end

function EgoService:SetActive(Player: Player, Enabled: boolean): boolean
	if Enabled and (not self:CanUse(Player) or not self:AssignEgo(Player)) then
		return false
	end

	local Character = Active[Player] or Player.Character
	if not Enabled then
		Active[Player] = nil
		local Connection = ActionConnections[Player]
		if Connection then
			ActionConnections[Player] = nil
			Connection:Disconnect()
		end

		if Character then
			Character:SetAttribute("EgoActive", false)
			CharacterShared:UpdateBoth(Character)
		end
		for Target, Scene in Scenes do
			if Scene.Source == Player then
				FinishScene(Target)
			end
		end
		if not next(Active) and Pulse then
			Pulse:Disconnect()
			Pulse = nil
			Elapsed = 0
		end
		return true
	end

	if not Character or Active[Player] then
		return true
	end
	Active[Player] = Character
	ActionConnections[Player] = Character.AttributeChanged:Connect(function(Attribute: string)
		if Active[Player] == Character and EgoConfig.CancelStates[Attribute] and Character:GetAttribute(Attribute) then
			self:SetActive(Player, false)
		end
	end)

	BowService:CancelDraw(Player)
	Character:SetAttribute("EgoActive", true)
	CharacterShared:UpdateBoth(Character)

	if not Pulse then
		Pulse = RunService.Heartbeat:Connect(function(DeltaTime: number)
			Elapsed += DeltaTime
			if Elapsed >= EgoConfig.SampleInterval then
				local Step = math.min(Elapsed, 0.5)
				Elapsed = 0
				self:Step(Step)
			end
		end)
	end

	return true
end

local function IsEnemy(Source: Player, Target: Model): boolean
	if Target == Source.Character or Target:GetAttribute("Friendly") or Target:GetAttribute("ForceField")
		or Target:FindFirstChildWhichIsA("ForceField") then
		return false
	end

	local TargetPlayer = Players:GetPlayerFromCharacter(Target)
	if TargetPlayer then
		if TargetPlayer:GetAttribute("InIntroCutscene") or TargetPlayer:GetAttribute("InWisdomWorld") then
			return false
		end
		local Party = PartyService:GetPlayerParty(Source)
		if Party and Party == PartyService:GetPlayerParty(TargetPlayer) then
			return false
		end
		if not Source.Neutral and not TargetPlayer.Neutral and Source.Team == TargetPlayer.Team then
			return false
		end
	end

	return TargetPlayer ~= nil or Target:GetAttribute("IsAI") == true
end

local function TryCutscene(Player: Player, Character: Model, Exposure: Exposure)
	local Now = workspace:GetServerTimeNow()
	if Scenes[Player] or Now - (LastScene[Player] or -math.huge) < EgoConfig.CutsceneCooldown
		or Player:GetAttribute("InCombat") or Character:GetAttribute("InCombat")
		or Character:GetAttribute("CameraCutscene") or Character:GetAttribute("Mounted")
		or Player:GetAttribute("InDialog") or Player:GetAttribute("InIntroCutscene")
		or not EgoConfig.ShouldPlayCutscene(Exposure.SourceLevel, Exposure.TargetLevel, Exposure.Distance) then
		return
	end

	local Scene: Scene = { Source = Exposure.Source, Character = Character }
	Scenes[Player] = Scene
	LastScene[Player] = Now
	Character:SetAttribute("EgoCutscene", true)
	CharacterShared:UpdateBoth(Character)
	EgoService.Client.Cutscene:Fire(Player, Exposure.Source.Character, EgoConfig.CutsceneDuration)
	task.delay(EgoConfig.CutsceneDuration, function()
		if Scenes[Player] == Scene then
			FinishScene(Player)
		end
	end)
end

function EgoService:Step(DeltaTime: number)
	local Exposures: { [Model]: Exposure } = {}
	local Levels: { [Model]: number } = {}
	for Player, Character in Active do
		if Player.Character ~= Character or not self:CanUse(Player) then
			self:SetActive(Player, false)
			continue
		end

		local Root = Character.PrimaryPart
		if not Root then
			continue
		end
		local SourceLevel = self:GetLevel(Character)
		local Seen: { [Model]: boolean } = {}
		local Params = OverlapParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = { Character }

		for _, Part in workspace:GetPartBoundsInRadius(Root.Position, EgoConfig.Radius, Params) do
			local Target = Part:FindFirstAncestorOfClass("Model")
			if not Target or Seen[Target] then
				continue
			end
			Seen[Target] = true
			if not IsAlive(Target) or not IsEnemy(Player, Target) then
				continue
			end

			local TargetRoot = Target.PrimaryPart
			if not TargetRoot then
				continue
			end
			local Distance = (TargetRoot.Position - Root.Position).Magnitude
			local TargetLevel = Levels[Target] or self:GetLevel(Target)
			Levels[Target] = TargetLevel
			local Pressure, Gain = EgoConfig.GetPressure(SourceLevel, TargetLevel, Distance)
			local Previous = Exposures[Target]
			-- Use the strongest aura; multiple weaker players cannot stack past the level cap.
			if Pressure > 0 and (not Previous or Pressure > Previous.Pressure) then
				Exposures[Target] = {
					Source = Player, Pressure = Pressure, Gain = Gain, Distance = Distance,
					SourceLevel = SourceLevel, TargetLevel = TargetLevel,
				}
			end
		end
	end

	for Character, Exposure in Exposures do
		local Player = Players:GetPlayerFromCharacter(Character)
		local Subject = Player or Character
		local Current = FearService:GetFear(Subject)
		if Current < Exposure.Pressure then
			FearService:SetFear(Subject, math.min(Exposure.Pressure, Current + Exposure.Gain * DeltaTime))
		end
		if Player then
			TryCutscene(Player, Character, Exposure)
		end
	end
	for Player, Scene in Scenes do
		if not IsAlive(Scene.Character) or Player:GetAttribute("InCombat") or Scene.Character:GetAttribute("InCombat") then
			FinishScene(Player)
		end
	end
end

local function TrackPlayer(Player: Player)
	Player:GetAttributeChangedSignal("Loaded"):Connect(function()
		if Player:GetAttribute("Loaded") then
			EgoService:AssignEgo(Player)
		end
	end)

	EgoService:AssignEgo(Player)
	Player.CharacterAdded:Connect(function(Character: Model)
		Character:SetAttribute("EgoId", EgoService:AssignEgo(Player))
	end)
	Player.CharacterRemoving:Connect(function(_Character: Model)
		EgoService:SetActive(Player, false)
		FinishScene(Player)
	end)
end

function EgoService.KnitInit()
	for Id, Definition in EgoConfig.Definitions do
		local Asset = ReplicatedStorage.Assets.VFX.Ego:FindFirstChild(Definition.Aura)
		if Asset and Asset:IsA("Model") then
			table.insert(Available, Id)
		end
	end
	table.sort(Available)

	StatService = Knit.GetService("StatService")
	DataService = Knit.GetService("DataService")
	FearService = Knit.GetService("FearService")
	PartyService = Knit.GetService("PartyService")
	BowService = Knit.GetService("BowService")
	AlertService = Knit.GetService("AlertService")
end

function EgoService.KnitStart()
	EgoService.Client.Cancel:Connect(function(Player: Player)
		if Active[Player] then
			EgoService:SetActive(Player, false)
		end
	end)

	EgoService.Client.Toggle:Connect(function(Player: Player)
		if Active[Player] then
			EgoService:SetActive(Player, false)
			return
		end

		local Now = workspace:GetServerTimeNow()
		if Now - (LastToggle[Player] or -math.huge) < EgoConfig.ToggleCooldown then
			return
		end
		LastToggle[Player] = Now
		if not EgoService:SetActive(Player, true) then
			AlertService:AlertPlayer(Player, "Ego requires level 3 in every stat and a free action state.", "Warn")
		end
	end)
	Players.PlayerAdded:Connect(TrackPlayer)
	Players.PlayerRemoving:Connect(function(Player: Player)
		EgoService:SetActive(Player, false)
		FinishScene(Player)
		LastToggle[Player], LastScene[Player] = nil, nil
	end)
	for _, Player in Players:GetPlayers() do
		TrackPlayer(Player)
	end
end

return EgoService
