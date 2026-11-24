local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local IntroCutsceneConfig = require(ReplicatedStorage.Shared.IntroCutsceneConfig)
local Config = IntroCutsceneConfig.CombatTutorial
local IntroCombatTutorialController = Knit.CreateController({ Name = "IntroCombatTutorialController" })

type Scene = {
	Token: string,
	Attempt: number,
	Step: number,
	Stage: string,
	Character: Model,
	Boss: Model,
	Ship: Model,
	Attack: AnimationTrack?,
	OwnsAttack: boolean,
	Animation: Animation?,
}

local Player = Players.LocalPlayer
local Active: Scene?
local Service
local AnimationController
local CutsceneController
local IntroScenePauseController
local DeviceController

local function IsActive(Scene: Scene): boolean
	return Active == Scene
		and Player.Character == Scene.Character
		and Scene.Character.Parent ~= nil
		and Scene.Boss.Parent ~= nil
end

local function ClearSwing(Scene: Scene)
	if Scene.Attack and Scene.OwnsAttack then
		Scene.Attack:Stop(0.1)
		Scene.Attack:Destroy()
	end
	Scene.Attack = nil
	Scene.OwnsAttack = false
end

local function Cancel()
	if not Active then
		return
	end
	local Scene = Active
	Active = nil
	IntroScenePauseController:Resume()
	ClearSwing(Scene)
	CutsceneController:HideInstruction()
end

local function CaptureTrack(Scene: Scene)
	if not Scene.Animation then
		return
	end
	local Humanoid = Scene.Boss:FindFirstChildWhichIsA("Humanoid")
	local Animator = Humanoid and Humanoid:FindFirstChildWhichIsA("Animator")
	if Animator then
		for _, Track in Animator:GetPlayingAnimationTracks() do
			if Track.Animation and Track.Animation.AnimationId == Scene.Animation.AnimationId then
				Scene.Attack, Scene.OwnsAttack = Track, false
				return
			end
		end
	end
	Scene.Attack = AnimationController:PlayAnimation(Scene.Boss, Scene.Animation)
	Scene.OwnsAttack = true
	if Scene.Attack then
		Scene.Attack.Priority = Enum.AnimationPriority.Action2
	end
end

local function ShowAction(Scene: Scene)
	local Mobile = DeviceController:IsMobile()
	local Message = if Scene.Step == 1
		then (if Mobile then "Tap Block to parry." else "Press F to parry.")
		elseif Scene.Step == 2 then (if Mobile then "Tap Attack." else "Left click to attack.")
		elseif Scene.Step == 3 then (if Mobile then "Move sideways and tap Roll." else "Press A or D + Q to dodge.")
		else (if Mobile then "Move close and tap Kick to push your opponent away." else "Move close and press G to kick your opponent away.")
	CutsceneController:ShowInstruction("", Message)
end

function IntroCombatTutorialController:Update(
	Token: string,
	Attempt: number,
	Step: number,
	Stage: string,
	Character: Model,
	Boss: Model,
	ShipName: string,
	_Success: boolean?,
	Animation: Animation?,
	FreezeTime: number?
)
	if Player.Character ~= Character then
		return
	end
	local Scene = Active
	if Scene and Scene.Token == Token and Attempt < Scene.Attempt then
		return
	end
	if not Scene or Scene.Token ~= Token then
		local Ships = workspace:FindFirstChild(IntroCutsceneConfig.ShipsFolderName)
		local Ship = Ships and Ships:FindFirstChild(ShipName) :: Model?
		if not Ship then
			return
		end
		Cancel()
		Scene = {
			Token = Token,
			Attempt = Attempt,
			Step = Step,
			Stage = Stage,
			Character = Character,
			Boss = Boss,
			Ship = Ship,
			OwnsAttack = false,
		}
		Active = Scene
	end
	if not IsActive(Scene) then
		return
	end
	if Attempt ~= Scene.Attempt then
		IntroScenePauseController:Resume()
		ClearSwing(Scene)
	end
	Scene.Attempt, Scene.Step, Scene.Stage, Scene.Animation = Attempt, Step, Stage, Animation
	if Stage == "Incoming" then
		CutsceneController:HideInstruction()
		CaptureTrack(Scene)
	elseif Stage == "Explain" then
		if Step == 1 or Step == 3 then
			if not Scene.Attack then
				CaptureTrack(Scene)
			end
			if Scene.Attack and FreezeTime then
				Scene.Attack.TimePosition = FreezeTime
			end
		end
		-- The player keeps the normal camera and can execute the requested native action.
		IntroScenePauseController:Pause(Scene.Ship, { Scene.Boss })
		ShowAction(Scene)
	else
		IntroScenePauseController:Resume()
		CutsceneController:HideInstruction()
		if Stage == "Practice" and Scene.Attack then
			Scene.Attack:AdjustSpeed(Config.PauseBeforeHit / Config.ReactionReleaseTime)
		elseif Stage == "Result" then
			if Step == 3 and Scene.Attack then
				Scene.Attack:AdjustSpeed(1)
			else
				ClearSwing(Scene)
			end
		end
	end
end

function IntroCombatTutorialController.KnitInit()
	Service = Knit.GetService("IntroCombatTutorialService")
	AnimationController = Knit.GetController("AnimationController")
	CutsceneController = Knit.GetController("CutsceneController")
	IntroScenePauseController = Knit.GetController("IntroScenePauseController")
	DeviceController = Knit.GetController("DeviceController")
end

function IntroCombatTutorialController.KnitStart()
	Service.StateChanged:Connect(
		function(
			Token: string,
			Attempt: number,
			Step: number,
			Stage: string,
			Character: Model,
			Boss: Model,
			ShipName: string,
			Success: boolean?,
			Animation: Animation?,
			FreezeTime: number?
		)
			IntroCombatTutorialController:Update(
				Token,
				Attempt,
				Step,
				Stage,
				Character,
				Boss,
				ShipName,
				Success,
				Animation,
				FreezeTime
			)
		end
	)
	Service.Ended:Connect(function(Token: string)
		if Active and Active.Token == Token then
			Cancel()
		end
	end)
	Player.CharacterRemoving:Connect(function(Character: Model)
		if Active and Active.Character == Character then
			Cancel()
		end
	end)
	Player:GetAttributeChangedSignal("InIntroCutscene"):Connect(function()
		if not Player:GetAttribute("InIntroCutscene") then
			Cancel()
		end
	end)
	task.spawn(function()
		local OneArm = ReplicatedStorage.Assets.Animations.Stances:FindFirstChild("OneArm")
		local Success, Error = pcall(function()
			ContentProvider:PreloadAsync(if OneArm then { OneArm } else {})
		end)
		if not Success then
			warn("Unable to preload intro training animations:", Error)
		end
	end)
end

return IntroCombatTutorialController
