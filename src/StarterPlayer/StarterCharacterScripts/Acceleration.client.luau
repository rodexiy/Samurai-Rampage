local CharacterShared = require(game.ReplicatedStorage.Shared.CharacterShared)
local Character = script.Parent.Parent
CharacterShared:ChangeWalkSpeed(Character)
local TargetWalkspeed = 0
local RunService = game:GetService("RunService")
local Humanoid = Character:WaitForChild("Humanoid")

local function UpdateTargetWalkSpeed()
    TargetWalkspeed = Character:GetAttribute("TargetWalkSpeed")
end

Character:GetAttributeChangedSignal("TargetWalkSpeed"):Connect(function()
    UpdateTargetWalkSpeed()
end)

UpdateTargetWalkSpeed()

local SpeedIncreaseRate = 1.5
local SpeedDecreaseRate = 5
RunService.RenderStepped:Connect(function(deltaTime)
    local deltaSpeed = TargetWalkspeed * deltaTime
    
    if Humanoid.MoveDirection.Magnitude == 0 then
        deltaSpeed = deltaSpeed * SpeedDecreaseRate
        deltaSpeed = -deltaSpeed
    else
        deltaSpeed = deltaSpeed * SpeedIncreaseRate
    end
    
    local newWalkSpeed = math.clamp(Humanoid.WalkSpeed + deltaSpeed, 0, TargetWalkspeed)
    Humanoid.WalkSpeed = newWalkSpeed
end)


