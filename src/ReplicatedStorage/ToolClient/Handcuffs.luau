local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Handcuffs = {}

local Player = game.Players.LocalPlayer

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local Collector = require(game.ReplicatedStorage.Shared.Collector)

local PrisonService = Knit.GetService("PrisonService")

local SharedConstants = require(game.ReplicatedStorage.Shared.Constants)
local PRISON_BOUNTY = SharedConstants.PRISON_BOUNTY

function Handcuffs.Activated(Character: Model, Tool: Tool) end

local CuffsPrompts = {}
local Connections = Collector.new()

function Handcuffs.Equipped(Character: Model, Tool: Tool)
	local function CreatePrompt(CharacterToCuff: Model, PlayerToCuff: Player)
		local Bounty = PlayerToCuff:GetAttribute("Bounty")
		if not Bounty or Bounty < PRISON_BOUNTY then
			return
		end

		local Prompt = Instance.new("ProximityPrompt")
		Prompt.Style = Enum.ProximityPromptStyle.Custom
		Prompt.ActionText = "Cuff"
		Prompt.HoldDuration = 0
		Prompt.RequiresLineOfSight = false
		Prompt.KeyboardKeyCode = Enum.KeyCode.F

		Prompt:SetAttribute("callback", "Cuff")
		table.insert(CuffsPrompts, Prompt)

		Prompt.Parent = CharacterToCuff
	end

	for _, PlayerToCuff in Players:GetPlayers() do
		if PlayerToCuff == Player then
			continue
		end

		local CharacterToCuff = PlayerToCuff.Character

		if CharacterToCuff then
			if CharacterToCuff:GetAttribute("Downed") then
				CreatePrompt(CharacterToCuff, PlayerToCuff)
			else
				Connections:Add(CharacterToCuff:GetAttributeChangedSignal("Downed"):Connect(function()
					if CharacterToCuff:GetAttribute("Downed") then
						CreatePrompt(CharacterToCuff, PlayerToCuff)
					else
						for _, Prompt in CuffsPrompts do
							if Prompt.Parent == CharacterToCuff then
								Prompt:Destroy()
							end
						end
					end
				end))
			end
		end
	end
end

function Handcuffs.Unequipped(Character: Model, Tool: Tool)
	Connections:DisconnectAll()
	for _, Prompt in CuffsPrompts do
		Prompt:Destroy()
	end
	table.clear(CuffsPrompts)
end

return Handcuffs
