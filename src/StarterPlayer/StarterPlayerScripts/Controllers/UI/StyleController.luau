local StarterGui = game:GetService("StarterGui")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local StyleController = Knit.CreateController({
	Name = "StyleController",
})

local Player = game.Players.LocalPlayer
local PlayerGui
local Styles = {}

local StylesCreated = {}
function StyleController:ApplyStyles()
	for _, Component in PlayerGui:GetDescendants() do
		local StylesAttribute: string = Component:GetAttribute("Style")
		if StylesAttribute then
			local ClassNames = StylesAttribute:split(" ")
			for _, className in ClassNames do
				local Style = Styles[className]
				if Style then
					Style = Style:Clone()
					table.insert(StylesCreated, Style)
					Style.Parent = Component
				end
			end
		end

		if Component:IsA("TextButton") or Component:IsA("ImageButton") then
			local StyleAttribute: string = Component:GetAttribute("Style")
			if StyleAttribute and StyleAttribute:find("-Button") then
				continue
			end
			local Style = Styles["Button"]:Clone()
			table.insert(StylesCreated, Style)
			Style.Parent = Component
		end
	end

	for _, StyleCreated in StylesCreated do
		task.spawn(function()
			StyleCreated.Enabled = true
		end)
		task.wait()
	end
end

function StyleController.KnitInit()
	PlayerGui = Player:WaitForChild("PlayerGui")

	for _, Style in game.ReplicatedStorage.Assets.Styles:GetChildren() do
		Styles[Style.Name] = Style
	end

	repeat
		task.wait()
	until #PlayerGui:GetDescendants() >= #StarterGui:GetDescendants()

	StyleController:ApplyStyles()
end

function StyleController.KnitStart() end

return StyleController
