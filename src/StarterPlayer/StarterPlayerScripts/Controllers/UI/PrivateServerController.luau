local Knit = require(game.ReplicatedStorage.Packages.Knit)

local PrivateServerController = Knit.CreateController({
	Name = "PrivateServerController",
})

local Player = game.Players.LocalPlayer
local PlayerGui
local Temporary
local PrivateServerUI
local content

local PrivateServerService

function PrivateServerController.KnitInit()
	PrivateServerService = Knit.GetService("PrivateServerService")
end

function PrivateServerController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Temporary = PlayerGui:WaitForChild("Temporary", math.huge)
	PrivateServerUI = Temporary:WaitForChild("PrivateServer")
	content = PrivateServerUI:WaitForChild("content")

	PrivateServerService.GeneratedCode:Connect(function(PSCode: string)
		content.YourServer.Text = "Your server code: " .. PSCode
	end)

	content.YourServer.Text = "Your server code: " .. (PrivateServerService:GetReservedCode(Player) or "")

	local InsertCode: TextBox = content:WaitForChild("TextButton"):WaitForChild("InsertCode")

	local InsertedCode

	InsertCode:GetPropertyChangedSignal("Text"):Connect(function()
		InsertedCode = InsertCode.Text
	end)
	InsertCode.FocusLost:Connect(function()
		PrivateServerService:TeleportToServer(InsertedCode)
	end)
end

return PrivateServerController
