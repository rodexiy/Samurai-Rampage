local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local MissionBoardController = Knit.CreateController({
	Name = "MissionBoardController",
})

local MissionBoardService
local MenuController

local Missions = {}
local Cards = {}

local Player = Players.LocalPlayer
local PlayerGui
local Menu
local MissionBoardUI
local background
local content
local Template

function MultiplyUDim2(udim, factor)
	return UDim2.new(
		udim.X.Scale * factor, -- Multiply X Scale
		udim.X.Offset * factor, -- Multiply X Offset
		udim.Y.Scale * factor, -- Multiply Y Scale
		udim.Y.Offset * factor -- Multiply Y Offset
	)
end

local Mouse = Player:GetMouse()
function IsMouseInBounds(guiObject)
	local mousePos = Mouse -- Get current mouse position
	local absPos = guiObject.AbsolutePosition -- Top-left corner of UI
	local absSize = guiObject.AbsoluteSize -- Width and height of UI

	return mousePos.X >= absPos.X
		and mousePos.X <= absPos.X + absSize.X
		and mousePos.Y >= absPos.Y
		and mousePos.Y <= absPos.Y + absSize.Y
end

local HoverInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
function MissionBoardController:UpdateBoard()
	local function isOverlapping(newPos, newSize)
		for _, existingCard in pairs(Cards) do
			local existingPos = existingCard.AbsolutePosition
			local existingSize = existingCard.AbsoluteSize

			local existingX = existingPos.X
			local existingY = existingPos.Y
			local existingWidth = existingSize.X
			local existingHeight = existingSize.Y

			local newX = newPos.X
			local newY = newPos.Y
			local newWidth = newSize.X
			local newHeight = newSize.Y

			if
				newX < existingX + existingWidth
				and newX + newWidth > existingX
				and newY < existingY + existingHeight
				and newY + newHeight > existingY
			then
				return true
			end
		end

		return false
	end

	for _, Card in pairs(Cards) do
		Card:Destroy()
	end
	Cards = {}

	local contentSize = content.AbsoluteSize
	local cardTemplateSize = Template.AbsoluteSize
	local margin = 10

	-- Evita erro caso o container seja menor que o card
	local maxX = contentSize.X - cardTemplateSize.X
	local maxY = contentSize.Y - cardTemplateSize.Y

	if maxX < margin then
		maxX = margin
	end
	if maxY < margin then
		maxY = margin
	end

	for _, Mission in pairs(Missions) do
		local Card = Template:Clone()
		Card.Name = Mission.Id
		Card.Title.Text = Mission.DisplayName
		Card.Description.Text = Mission.Description
		Card.Rewards.Exp.Text = "Exp: " .. Mission.Exp
		Card.Rewards.Tetsu.Text = "Tetsu: " .. Mission.Tetsu
		Card.Icon.Image = Mission.Image
		Card.NailHead.Rotation = math.random(0, 360)

		Card.Parent = content
		local DefaultSize = Card.Size
		local HoverLeaveTween = TweenService:Create(Card, HoverInfo, { Size = DefaultSize, Rotation = 0 })
		local HoverTween = TweenService:Create(
			Card,
			HoverInfo,
			{ Size = MultiplyUDim2(DefaultSize, 1.1), Rotation = math.random(-10, 10) }
		)
		local CheckLeaveConnection

		Card.Activated:Connect(function()
			Card.Visible = false

			if MissionBoardService:Select(Mission.Id) then
				Card:Destroy()
			else
				Card.Visible = true
			end
		end)

		Card.MouseEnter:Connect(function()
			HoverLeaveTween:Pause()
			HoverTween:Pause()
			HoverTween:Play()
			Card.ZIndex = 2

			if CheckLeaveConnection then
				CheckLeaveConnection:Disconnect()
			end

			CheckLeaveConnection = RunService.RenderStepped:Connect(function()
				if not IsMouseInBounds(Card) then
					Card.ZIndex = 1
					HoverTween:Pause()
					HoverLeaveTween:Pause()
					HoverLeaveTween:Play()

					if CheckLeaveConnection then
						CheckLeaveConnection:Disconnect()
						CheckLeaveConnection = nil
					end
				end
			end)
		end)

		local maxAttempts = 100
		local foundPosition = false

		for _ = 1, maxAttempts do
			local randomX = math.random(margin, maxX)
			local randomY = math.random(margin, maxY)

			local newPos = UDim2.fromOffset(randomX, randomY)
			Card.Position = newPos

			if not isOverlapping(Card.AbsolutePosition, cardTemplateSize) then
				table.insert(Cards, Card)
				Card.AnchorPoint = Vector2.new(0.5, 0.5)
				Card.Position = UDim2.fromOffset(randomX + cardTemplateSize.X / 2, randomY + cardTemplateSize.Y / 2)
				foundPosition = true
				Card.Visible = true
				break
			end
		end

		if not foundPosition then
			Card:Destroy()
		end
	end
end

function MissionBoardController:OpenBoard(RequestingPlayer: Player)
	if not MissionBoardUI.Enabled then
		task.spawn(function()
			local OpenPosition
			while RequestingPlayer.Character do
				if not OpenPosition then
					OpenPosition = RequestingPlayer.Character:GetPivot().Position
				end

				local Distance = (OpenPosition - RequestingPlayer.Character:GetPivot().Position).Magnitude
				if Distance > 10 then
					break
				end

				task.wait()
			end

			MissionBoardUI.Enabled = false
		end)
	end

	MissionBoardUI.Enabled = true
end

function MissionBoardController.KnitInit()
	MissionBoardService = Knit.GetService("MissionBoardService")
	MenuController = Knit.GetController("MenuController")
end

function MissionBoardController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Menu = PlayerGui:WaitForChild("Menu")
	MissionBoardUI = Menu:WaitForChild("MissionBoard")
	background = MissionBoardUI:WaitForChild("background")
	content = background:WaitForChild("content")
	Template = background:WaitForChild("Template")
	local Close = background:WaitForChild("Close") :: GuiButton

	MenuController:BindCloseButton(Close, function()
		MissionBoardUI.Enabled = false
	end)

	MissionBoardService.UpdateBoard:Connect(function(NewMissions)
		Missions = NewMissions

		MissionBoardController:UpdateBoard()
	end)
end

return MissionBoardController
