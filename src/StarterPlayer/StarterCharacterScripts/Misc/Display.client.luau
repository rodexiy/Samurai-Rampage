local StatusDisplayManager = require(game.ReplicatedStorage.Shared.Utils.StatusDisplayManager)

local Character = script.Parent.Parent.Parent
repeat
	task.wait()
until Character:GetAttribute("Loaded")
local RootPart = Character:WaitForChild("HumanoidRootPart")
StatusDisplayManager:AddSideDisplay(Character)
