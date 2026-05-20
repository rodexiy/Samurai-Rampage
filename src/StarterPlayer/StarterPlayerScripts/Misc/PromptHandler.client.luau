local Knit = require(game.ReplicatedStorage.Packages.Knit)
local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

Knit.OnStart():andThen(function()
    local CharacterService = Knit.GetService("CharacterService")
    CharacterService.CharacterDowned:Connect(function()
        if Character:FindFirstChild("CarryPrompt") then
            Character:FindFirstChild("CarryPrompt"):Destroy()
        end
    end)
end)

