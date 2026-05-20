local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local BIND_DISTANCE = 400
local UNBIND_DISTANCE = 450

local Collector = require(game.ReplicatedStorage.Shared.Collector)
local BindedAIs = {}
local AIConnections = {}
local TrackedAIs = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Character = player.Character or player.CharacterAdded:Wait()

player.CharacterAdded:Connect(function()
	Character = player.Character
end)

local AllPresets = game.ReplicatedStorage.Assets.Presets
local PresetsTable = {}

for _, preset in AllPresets:GetChildren() do
	if not PresetsTable[preset.Name] then
		PresetsTable[preset.Name] = {}
	end
	for _, value in preset:GetChildren() do
		PresetsTable[preset.Name][value.Name] = value
	end
end

local userAnimateScaleRunSuccess, userAnimateScaleRunValue = pcall(function()
	return UserSettings():IsUserFeatureEnabled("UserAnimateScaleRun")
end)
local userAnimateScaleRun = userAnimateScaleRunSuccess and userAnimateScaleRunValue

local function UnbindAI(Character)
	if not BindedAIs[Character] then
		return
	end

	local Connections = AIConnections[Character]
	if Connections then
		Connections:Destroy()
		AIConnections[Character] = nil
	end

	TrackedAIs[Character] = nil
	BindedAIs[Character] = nil

	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if not Humanoid then
		return
	end
	local Animator = Humanoid:FindFirstChild("Animator")
	if not Animator then
		return
	end

	for _, Animation in Animator:GetPlayingAnimationTracks() do
		Animation:Stop()
		Animation:Destroy()
	end
end

local function BindAI(Character)
	if BindedAIs[Character] then
		return
	end
	BindedAIs[Character] = true

	local currentState = "idle"
	local currentTrack = nil
	local currentAnimInstance = nil
	local currentAnimSpeed

	local Humanoid = Character:WaitForChild("Humanoid", 10)
	local RootPart = Character:WaitForChild("HumanoidRootPart", 10)
	if not Humanoid or not RootPart then
		UnbindAI(Character)
		return
	end

	local Animator = Humanoid:WaitForChild("Animator", 10)
	if not Animator then
		UnbindAI(Character)
		return
	end

	AIConnections[Character] = Collector.new()
	local Connections = AIConnections[Character]

	local function getrandomanim(folder, totalweight)
		local weighttable = {}
		for _, obj in pairs(folder:GetChildren()) do
			weighttable[obj.Name] = obj:GetAttribute("Weight") or 0
		end

		local RandomNumber = math.random(1, totalweight)
		local Number = 0

		for anim, weight in pairs(weighttable) do
			Number = Number + weight
			if RandomNumber <= Number then
				return folder:FindFirstChild(anim)
			end
		end
	end

	local function gettotalweight(folder)
		local weight = 0
		for _, obj in pairs(folder:GetChildren()) do
			if obj:GetAttribute("Weight") then
				weight += obj:GetAttribute("Weight")
			end
		end
		return weight
	end

	local function updateAnimation(animName, transitionTime)
		local presetfolder = nil
		local anim = nil
		local function getanim()
			presetfolder = PresetsTable[Character:GetAttribute("AnimationPreset") or "Default"]

			if currentState == "Running" and Character:GetAttribute("Running") then
				animName = "running"
			end

			anim = presetfolder[animName]
			if not anim then
				anim = PresetsTable.Default[animName]
				if not anim then
					return
				end
			end

			if anim:IsA("Folder") then
				anim = getrandomanim(anim, gettotalweight(anim))
			end
		end

		if typeof(animName) == "string" then
			getanim()
		elseif animName:IsA("Animation") then
			anim = animName
		end

		-- custom swim integration
		if not anim and animName == "swim" then
			animName = "run"
			getanim()
		elseif not anim and animName == "swimidle" then
			animName = "idle"
			getanim()
		end

		-- switch animation
		if anim and (anim ~= currentAnimInstance) then
			if currentTrack ~= nil then
				currentTrack:Stop(transitionTime)
				currentTrack:Destroy()
			end

			currentAnimSpeed = 1.0

			currentTrack = Humanoid:LoadAnimation(anim)
			currentTrack.Priority = Enum.AnimationPriority.Core
			currentTrack:Play(transitionTime)

			currentState = animName
			currentAnimInstance = anim

			if TrackedAIs[Character] then
				TrackedAIs[Character].State = currentState
				TrackedAIs[Character].CurrentAnim = currentTrack
			end
		end
	end

	Connections:Add(RootPart:GetPropertyChangedSignal("Anchored"):Connect(function()
		if RootPart.Anchored then
			updateAnimation("idle", 0)
		end
	end))

	Connections:Add(Character:GetAttributeChangedSignal("AnimationPreset"):Connect(function()
		updateAnimation(currentState)
	end))

	Connections:Add(Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if Character:GetAttribute("Ragdoll") then
			if RootPart.Anchored then
				if currentTrack then
					currentTrack:Stop()
					currentTrack = nil
				end
				currentAnimInstance = nil
				currentState = nil
			end
		end
	end))

	updateAnimation(currentState)

	-- Add to global tracker
	TrackedAIs[Character] = {
		RootPart = RootPart,
		State = currentState,
		Update = updateAnimation,
	}
end

local AllAIs = {} -- all known AIs

-- Track all Entity-tagged AIs
for _, AI in CollectionService:GetTagged("Entity") do
	if AI:GetAttribute("IsAI") then
		AllAIs[AI] = true
	end
end

CollectionService:GetInstanceAddedSignal("Entity"):Connect(function(AI)
	if AI:GetAttribute("IsAI") then
		AllAIs[AI] = true
	end
end)

CollectionService:GetInstanceRemovedSignal("Entity"):Connect(function(AI)
	if AI:GetAttribute("IsAI") then
		AllAIs[AI] = nil
		UnbindAI(AI)
	end
end)

local function getDistanceToPlayer(position)
	local playerRootPosition = Character:GetPivot().Position
	if not playerRootPosition or not position then
		return math.huge
	end
	return (position - playerRootPosition).Magnitude
end

local function shouldBind(rootPart)
	local dist = getDistanceToPlayer(rootPart:GetPivot().Position)
	if dist > UNBIND_DISTANCE then
		return false
	end

	return true
end

while true do
	task.wait(0.1)
	if not Character then
		continue
	end

	for AI, _ in pairs(AllAIs) do
		if AI.Parent then
			local root = AI.PrimaryPart
			if root then
				local bindNow = shouldBind(root)
				if bindNow and not BindedAIs[AI] then
					BindAI(AI)
				elseif not bindNow and BindedAIs[AI] then
					UnbindAI(AI)
				end

				if BindedAIs[AI] and TrackedAIs[AI] then
					local vel = root.Velocity.Magnitude
					local newState = vel > 0 and "walk" or "idle"
					if newState ~= TrackedAIs[AI].State then
						TrackedAIs[AI].State = newState
						TrackedAIs[AI].Update(newState, 0.1)
					end
				end
			end
		end
	end
end
