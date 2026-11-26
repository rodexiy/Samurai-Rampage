local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.TreeCuttingConfig)
local AnimationService = Knit.GetService("AnimationService")
local DebounceService = Knit.GetService("DebounceService")
local TreeCuttingService = Knit.GetService("TreeCuttingService")

local Axe = {}

function Axe.Activated(Character: Model, _Data: { any })
	local Player = Players:GetPlayerFromCharacter(Character)
	local Tool = Character:FindFirstChildWhichIsA("Tool")
	local Stamina = Character:GetAttribute("Stamina")
	if
		not Player
		or not Tool
		or Character:GetAttribute("AxePick")
		or Character:GetAttribute("Died")
		or Character:GetAttribute("Ragdoll")
		or typeof(Stamina) ~= "number"
		or Stamina < 15
	then
		return
	end

	local Animation = Tool:FindFirstChild("Activated", true) :: Animation?
	if not Animation or not Animation:IsA("Animation") then
		return
	end
	DebounceService:AddDebounce(Character, "AxePick", Config.SwingCooldown)
	local Track = AnimationService:PlayAnimation(Character, Animation)
	if Track then
		Track.Priority = Enum.AnimationPriority.Action4
	end

	TreeCuttingService:Swing(Player, Character)
end

return Axe
