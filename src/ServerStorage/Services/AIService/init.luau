local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local AIService = Knit.CreateService({
	Name = "AIService",
	Client = {},
})

local MobService

function AIService:ManageActivity()
	while true do
		for _, Entity in workspace.Entity:GetChildren() do
			if Entity:GetAttribute("IsAI") and not Entity:GetAttribute("WanderingNpc") then
				local InRange = false
				if Entity:GetAttribute("WisdomWorldMob") then
					local Owner = Players:GetPlayerByUserId(Entity:GetAttribute("WisdomWorldOwnerId") or 0)
					local OwnerCharacter = Owner and Owner.Character

					InRange = OwnerCharacter ~= nil and OwnerCharacter.Parent ~= nil and not OwnerCharacter:GetAttribute("Died")
				else
					for _, Player in Players:GetPlayers() do
						local PlayerCharacter = Player.Character
						if PlayerCharacter then
							local Distance = (PlayerCharacter:GetPivot().Position - Entity:GetPivot().Position).Magnitude

							if Distance < 100 then
								InRange = true
								break
							end
						end
					end
				end

				Entity.Runner:SetAttribute("Enabled", InRange)
			end
		end

		task.wait(1)
	end
end

function AIService:PrepareMob(Character: Model)
	local LookAttachment = Instance.new("Attachment")
	LookAttachment.Name = "LookAttachment"
	LookAttachment.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	LookAttachment.Parent = Character.PrimaryPart

	local AlignOrientation = Instance.new("AlignOrientation", Character.PrimaryPart)
	AlignOrientation.Enabled = false
	AlignOrientation.Name = "LookPlayer"
	AlignOrientation.ReactionTorqueEnabled = false
	AlignOrientation.AlignType = Enum.AlignType.PrimaryAxisLookAt

	AlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	AlignOrientation.Attachment0 = LookAttachment
	AlignOrientation.Responsiveness = 200
	AlignOrientation.MaxTorque = 20000
	AlignOrientation.MaxAngularVelocity = 30

	AlignOrientation:GetPropertyChangedSignal("Enabled"):Connect(function()
		MobService:SetNetworkOwner(Character)
	end)

	local HitboxDetected = Instance.new("BindableEvent")
	HitboxDetected.Name = "HitboxDetected"
	HitboxDetected.Parent = Character
end

function AIService:AddAI(Character: Model, AIRunner: string, AIConfig: string, Job: string?)
	if not Character then
		return
	end

	local Runner = script.Runners:FindFirstChild(AIRunner, true)

	local Config
	if typeof(AIConfig) == "string" then
		Config = script.Configs:FindFirstChild(AIConfig, true)
	elseif typeof(AIConfig) == "table" then
		Config = AIConfig
	end

	if not Runner or not Config then
		return
	end

	AIService:PrepareMob(Character)

	local Runner = Runner:Clone()
	Runner.Name = "Runner"
	Runner.Parent = Character

	local Health = Character:FindFirstChild("Health")
	if Health then
		Health.Enabled = true
	end
	local Config = if typeof(AIConfig) == "string" then require(Config) else Config

	local TotalLifes = 0
	for _, Life in Config.Lifes do
		TotalLifes += 1
	end

	if Job then
		Character:SetAttribute("Job", Job)
	end

	Character:SetAttribute("MaxHealth", Config.Lifes[tostring(TotalLifes)].Health or 100)
	Character:SetAttribute("Health", Character:GetAttribute("MaxHealth"))
	Character:SetAttribute("TotalLifes", TotalLifes)
	Character:SetAttribute("Lifes", TotalLifes)

	Character:GetAttributeChangedSignal("Lifes"):Connect(function()
		local LifeData = Config.Lifes[tostring(Character:GetAttribute("Lifes"))]
		if LifeData then
			Character:SetAttribute("MaxHealth", LifeData.Health or 100)
			Character:SetAttribute("Health", Character:GetAttribute("MaxHealth"))
		end
	end)

	task.spawn(function()
		require(Runner).Start(Config)
		Runner:SetAttribute("Enabled", true)
	end)
end

function AIService.KnitInit()
	MobService = Knit.GetService("MobService")
end

function AIService.KnitStart()
	AIService:ManageActivity()
end

return AIService
