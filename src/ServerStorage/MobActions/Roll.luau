local Knit = require(game.ReplicatedStorage.Packages.Knit)

---a
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MovementService = Knit.GetService("MovementService")
local CameraController
local Block


local ROLL_DRAG = 2.3

local Character = script.Parent.Parent
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local RollAnimsPath = game.ReplicatedStorage.Assets.Animations.Combat.Roll
local RollDirectionsAnimations = {
	["Forward"] = Humanoid.Animator:LoadAnimation(RollAnimsPath.Forward),
	["Backward"] = Humanoid.Animator:LoadAnimation(RollAnimsPath.Backward),
	["Left"] = Humanoid.Animator:LoadAnimation(RollAnimsPath.Left),
	["Right"] = Humanoid.Animator:LoadAnimation(RollAnimsPath.Right),
}

local Roll = {}

function Roll:Roll(Direction)
	task.spawn(function()

		MovementService:Roll(Character, Direction)

		
		Character:SetAttribute("Rolling", true)

		local BodyVelocity = Instance.new("BodyVelocity")
		BodyVelocity.Name = "Roll_BodyVelocity"
		BodyVelocity.MaxForce = Vector3.new(1,0,1) * 10000
		BodyVelocity.Parent = RootPart
		Debris:AddItem(BodyVelocity, 0.5)

		local function GetMapFromDirection()
			local map = Vector3.zero

			if Direction == "Right" then
				map += Vector3.new(1, 0, 0)
			end
			if Direction == "Left" then
				map += Vector3.new(-1, 0, 0)
			end
			if Direction == "Forward"  then
				map += Vector3.new(0, 0, 1)
			end
			if Direction == "Backward" then
				map += Vector3.new(0, 0, -1)
			end

			return map
		end

		local map = GetMapFromDirection()

		local RollAnimation = RollDirectionsAnimations[Direction]:: AnimationTrack
		RollAnimation.Priority = Enum.AnimationPriority.Action
		RollAnimation:Play()


		local VelocityMultiplier = 135
		local ForwardRayParams = RaycastParams.new()
		ForwardRayParams.RespectCanCollide = true

		ForwardRayParams.FilterDescendantsInstances = {Workspace.Entity}
		ForwardRayParams.FilterType = Enum.RaycastFilterType.Exclude

		task.spawn(function()
			while VelocityMultiplier > 38 and Character:GetAttribute("Rolling") do
				local reversed = Vector3.new(map.X, 0, -map.Z)
				local LookDirection = CFrame.new(RootPart.CFrame.Position, (RootPart.CFrame * CFrame.new(reversed)).Position).LookVector

				local ForwardRay = Workspace:Raycast(RootPart:GetPivot().Position, LookDirection * 28, ForwardRayParams)
				if ForwardRay and ForwardRay.Distance <= 3 then 
					BodyVelocity:Destroy()
					Character:SetAttribute("Rolling", false)
					break
				end

				task.wait()
			end
		end)

		while VelocityMultiplier > 38 and Character:GetAttribute("Rolling") do
			if not BodyVelocity then
				break
			end

			local reversed = Vector3.new(map.X, 0, -map.Z)
			local LookDirection = CFrame.new(RootPart.CFrame.Position, (RootPart.CFrame * CFrame.new(reversed)).Position).LookVector
			VelocityMultiplier = VelocityMultiplier / ROLL_DRAG

			BodyVelocity.Velocity = (LookDirection * VelocityMultiplier)
			task.wait(0.1)
		end
	end)

end




return Roll