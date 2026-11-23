local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryService = Knit.GetService("InventoryService")
local DebounceService = Knit.GetService("DebounceService")
local AlertService = Knit.GetService("AlertService")

local Bandage = {}

function Bandage.Activated(Character: Model, _Data: { any })
	local Player = Players:GetPlayerFromCharacter(Character)
	if not Player or Character:GetAttribute("Died") or Character:GetAttribute("Downed")
		or Character:GetAttribute("Bandaging") or Character:GetAttribute("BandageDebounce") then
		return
	end
	for _, Attribute in { "Attack", "Attacking", "Blocking", "Rolling", "Ragdoll", "BeenHitted", "PostureBreak", "UsingSkillCantAttack" } do
		if Character:GetAttribute(Attribute) then
			return
		end
	end
	local Item = InventoryService:GetPlayerItemByName(Player, "Bandage")
	if not Item or Item.Stack <= 0 then
		return
	end

	local Duration, Heal = 2, 15
	local Health = Character:GetAttribute("Health") or 0
	local Finished = false
	local Connections: { RBXScriptConnection } = {}
	Character:SetAttribute("Bandaging", true)
	DebounceService:AddDebounce(Character, "BandageDebounce", 10)
	InventoryService:ConsumeToolItem(Player, "Bandage", 1)
	AlertService:AlertPlayer(Player, "Applying bandage...", "Info")

	local function Finish(Interrupted: boolean)
		if Finished then
			return
		end
		Finished = true
		for _, Connection in Connections do
			Connection:Disconnect()
		end
		if not Character.Parent then
			return
		end
		Character:SetAttribute("Bandaging", false)
		if Player.Character ~= Character or Character:GetAttribute("Died") or Character:GetAttribute("Downed")
			or Character:GetAttribute("Health") <= 0 then
			return
		end

		if Interrupted then
			return
		end
		Character:SetAttribute("Health", math.min(Character:GetAttribute("MaxHealth"), Character:GetAttribute("Health") + Heal))
	end

	table.insert(Connections, Character:GetAttributeChangedSignal("Health"):Connect(function()
		local Current = Character:GetAttribute("Health") or 0
		if Current < Health then
			Finish(true)
		end
		Health = Current
	end))
	for _, Attribute in { "Downed", "Died", "Ragdoll", "PostureBreak", "BeenHitted" } do
		table.insert(Connections, Character:GetAttributeChangedSignal(Attribute):Connect(function()
			if Character:GetAttribute(Attribute) then
				Finish(true)
			end
		end))
	end
	table.insert(Connections, Character.Destroying:Connect(function()
		Finish(true)
	end))
	task.delay(Duration, function()
		Finish(false)
	end)
end

return Bandage
