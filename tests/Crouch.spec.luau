-- Run production crouch modules with isolated Knit signals and temporary R6 character fixtures.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(Service: any, Animations: any, Config: any, Context: any): string
	local Checks = 0
	local Folder = Instance.new("Folder")
	Folder.Name = "CrouchValidationCharacters"
	Folder.Parent = workspace
	local Character = ReplicatedStorage.Assets.Rigs.KatanaVisualizer:Clone()
	Character:PivotTo(CFrame.new(0, 2000, 0))
	Character.Parent = Folder
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid") :: Humanoid
	for _, Part in Character:QueryDescendants("BasePart") :: { BasePart } do
		Part.Anchored = true
	end
	Character:SetAttribute("Loaded", true)
	Character:SetAttribute("Health", 100)
	Character:SetAttribute("DefaultWalkSpeed", 12)
	Character:SetAttribute("DefaultJumpPower", 40)
	Character:SetAttribute("RunningWalkSpeed", 24)
	Character:SetAttribute("Stamina", 100)
	local OriginalHeight = Humanoid.HipHeight
	local Player = {Character = Character}
	local State = Animations.Create(Character)
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		Check(State ~= nil and Config.CanCrouch(Character), "The game R6 rig must support crouching")
		Service:BindCharacter(Character)
		Check(Character:GetAttribute("Crouching") == false, "Characters must start standing")
		Character:SetAttribute("Running", true)
		Check(Service:SetCrouching(Character, true), "Valid characters must be allowed to crouch")
		Check(Character:GetAttribute("Crouching") and not Character:GetAttribute("Running"), "Entering crouch must stop sprinting")
		Check(math.abs(Humanoid.HipHeight - (OriginalHeight - Config.HeightDrop)) < 0.001, "Crouching must lower the character while preserving the standing height")
		task.wait()
		Check(Character:GetAttribute("TargetWalkSpeed") == Config.WalkSpeed and Humanoid.JumpPower == 0, "Crouch must cap walking speed and prevent jumping")

		local RightHip = Character.Torso["Right Hip"] :: Motor6D
		local LeftHip = Character.Torso["Left Hip"] :: Motor6D
		local RightC0, LeftC0 = RightHip.C0, LeftHip.C0
		local RightC1, LeftC1 = RightHip.C1, LeftHip.C1
		Animations.Update(State, 0)
		Check(State.Current == State.Idle and State.Idle.Animation.AnimationId == "rbxassetid://99254308802301", "Standing crouched must play the supplied idle animation")
		Check(State.Idle.Priority == Enum.AnimationPriority.Action2 and State.Walk.Priority == Enum.AnimationPriority.Action2, "Both crouch animations must use Action2")
		Check(State.Idle.Looped and State.Walk.Looped, "Crouch animation tracks must loop")
		Animations.Update(State, 6)
		Check(State.Current == State.Walk and State.Walk.Animation.AnimationId == "rbxassetid://83428367691067", "Moving crouched must play the supplied walk animation")
		Animations.Update(State, 3)
		Check(math.abs(State.Walk.Speed - 0.5) < 0.001, "Walk playback speed must follow character speed")
		Animations.Update(State, 0)
		Check(State.Current == State.Idle, "Stopping must return to idle")
		Check(RightHip.C0 == RightC0 and LeftHip.C0 == LeftC0 and RightHip.C1 == RightC1 and LeftHip.C1 == LeftC1, "Crouch must not manually change joint offsets")

		Context.HitResolved:Fire(Character, Character, "Blocked")
		task.wait()
		Check(Character:GetAttribute("Crouching"), "A blocked attack must not count as a received hit")
		Context.HitResolved:Fire(Character, Character, "Hit", {NoStun = true})
		task.wait()
		Check(not Character:GetAttribute("Crouching") and Humanoid.HipHeight == OriginalHeight, "Even hits without stun must cancel crouch and restore height")

		Check(Service:SetCrouching(Character, true), "Crouch must be reusable after a hit")
		Animations.Update(State, 0)
		Character:SetAttribute("Ragdoll", true)
		task.wait()
		Animations.Update(State)
		Check(not Character:GetAttribute("Crouching") and State.Current == nil, "Ragdoll must cancel gameplay and animation immediately")
		Check(not State.Idle.IsPlaying and not State.Walk.IsPlaying, "Ragdoll must stop both crouch tracks")
		Check(not Service:SetCrouching(Character, true), "A ragdolled character must not be allowed to crouch again")
		Character:SetAttribute("Ragdoll", false)
		task.wait()
		Check(not Character:GetAttribute("Crouching"), "Recovering from ragdoll must not automatically reenter crouch")

		for _, Attribute in {"BeenHitted", "Downed", "Mounted", "Climbing", "Rolling", "Attacking", "Meditating"} do
			Check(Service:SetCrouching(Character, true), "Crouch must remain reusable")
			Character:SetAttribute(Attribute, true)
			task.wait()
			Check(not Character:GetAttribute("Crouching") and not Service:SetCrouching(Character, true), Attribute .. " must cancel and prevent crouch")
			Character:SetAttribute(Attribute, false)
			task.wait()
		end

		Service:SetCrouching(Character, true)
		Character:SetAttribute("Health", 90)
		task.wait()
		Check(not Character:GetAttribute("Crouching"), "Custom health damage must cancel crouch")
		Service:SetCrouching(Character, true)
		Character:SetAttribute("Health", 95)
		task.wait()
		Check(Character:GetAttribute("Crouching"), "Healing must not cancel crouch")
		Humanoid.Health -= 1
		task.wait()
		Check(not Character:GetAttribute("Crouching"), "Humanoid damage must also cancel crouch")

		Context.Now += 1
		Service.Client.Request:Fire(Player, "true")
		Check(not Character:GetAttribute("Crouching"), "Malformed network input must be ignored")
		Service.Client.Request:Fire(Player, true)
		Check(Character:GetAttribute("Crouching"), "The Knit event must toggle the sender's character")
		Service.Client.Request:Fire(Player, false)
		Check(Character:GetAttribute("Crouching"), "Requests must be rate limited")
		Context.Now += 1
		Service.Client.Request:Fire(Player, false)
		Check(not Character:GetAttribute("Crouching"), "A later C toggle must return to standing")
		Character:SetAttribute("Loaded", false)
		Check(not Service:SetCrouching(Character, true), "Characters still loading must not crouch")
		Character:SetAttribute("Loaded", true)
		Service:SetCrouching(Character, true)
		Service:UnbindCharacter(Character)
		Check(not Character:GetAttribute("Crouching") and Humanoid.HipHeight == OriginalHeight, "Removing the character must restore movement and height")
		Check(not Service:SetCrouching(Character, true), "Removed characters must not retain crouch state")
	end)

	Service:UnbindCharacter(Character)
	if State then
		Animations.Destroy(State)
	end
	Folder:Destroy()
	assert(Success, tostring(Error))

	return tostring(Checks) .. " crouch checks passed"
end
