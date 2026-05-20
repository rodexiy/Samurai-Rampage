local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DeviceController = Knit.CreateController({
	Name = "DeviceController",
})

local Device = "Desktop"

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Actions = PlayerGui:WaitForChild("Actions", math.huge)
local content = Actions:WaitForChild("content")
local Template = Actions:WaitForChild("Template")

function DeviceController:ApplyStrokeValue()
	if DeviceController:IsDevice("Mobile") then
		task.spawn(function()
			repeat
				task.wait()
			until #PlayerGui:GetDescendants() >= #StarterGui:GetDescendants()

			for _, content: UIStroke in PlayerGui:GetDescendants() do
				if content:IsA("UIStroke") then
					content.Thickness = content.Thickness / 2
				end
			end
		end)
	end
end

function DeviceController:GetDevice()
	return Device
end

function DeviceController:IsDevice(DeviceName: string)
	return Device == DeviceName
end

function DeviceController:UnbindAction(ActionName: string)
	local Action = content:FindFirstChild(ActionName)
	if Action then
		Action:Destroy()
	end
end

function DeviceController:IsDown(ActionName: string)
	if content:FindFirstChild(ActionName) then
		return content[ActionName].GuiState == Enum.GuiState.Press
	end
end

function DeviceController:BindAction(ActionName: string, callback: any, Name: string, Position: UDim2)
	if content:FindFirstChild(ActionName) then
		return
	end
	if self:IsMobile() then
		local Action: ImageButton = Template:Clone()
		Action.Name = ActionName
		Action.ActionName.Text = Name
		Action.Position = Position

		local OldState
		Action:GetPropertyChangedSignal("GuiState"):Connect(function()
			if Action.GuiState == Enum.GuiState.Press then
				callback(Enum.UserInputState.Begin)
			elseif ActionName.GuiState == nil then
				callback(Enum.UserInputState.End)
			end
			OldState = Action.GuiState
		end)

		Action.Parent = content
		Action.Visible = true
	end
end

function DeviceController:IsMobile()
	return Device == "Mobile"
end

if UserInputService.TouchEnabled then
	Device = "Mobile"
end

function DeviceController.KnitInit()
	DeviceController:ApplyStrokeValue()
end

function DeviceController.KnitStart()
	Player.CharacterAdded:Connect(function()
		for _, action in content:GetChildren() do
			if action:IsA("ImageButton") then
				action:Destroy()
			end
		end
	end)
end

return DeviceController
