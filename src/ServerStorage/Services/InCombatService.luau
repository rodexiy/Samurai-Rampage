local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InCombatService = Knit.CreateService({
	Name = "InCombatService",
	Client = {},
})

local InCombatDuration = 45
local ActiveAttackers = {}

function InCombatService:SetInCombat(Character: Model, SetInCombat: boolean, Attacker: Model)
	local Player = Players:GetPlayerFromCharacter(Character)
	if Character:GetAttribute("IsAI") then
		Character:SetAttribute("InCombat", SetInCombat)
		return
	end
	if not Player then
		return
	end

	if not ActiveAttackers[Player] then
		ActiveAttackers[Player] = {}
	end

	if SetInCombat then
		Player:SetAttribute("InCombat", true)
		Character:SetAttribute("InCombat", true)
		Player:SetAttribute("InCombatEndTick", workspace:GetServerTimeNow() + InCombatDuration)

		if not Character:GetAttribute("CombatHooked") then
			Character:SetAttribute("CombatHooked", true)

			local Humanoid = Character:FindFirstChild("Humanoid")
			if Humanoid then
				Humanoid:GetAttributeChangedSignal("Died"):Connect(function()
					if ActiveAttackers[Player] then
						for _, Conn in pairs(ActiveAttackers[Player]) do
							Conn:Disconnect()
						end
						ActiveAttackers[Player] = nil
					end
					Player:SetAttribute("InCombat", false)
					Character:SetAttribute("InCombat", false)
					Player:SetAttribute("InCombatEndTick", nil)
				end)
			end

			Character.Destroying:Connect(function()
				if ActiveAttackers[Player] then
					for _, Conn in pairs(ActiveAttackers[Player]) do
						Conn:Disconnect()
					end
					ActiveAttackers[Player] = nil
				end
				Player:SetAttribute("InCombat", false)
				Player:SetAttribute("InCombatEndTick", nil)
			end)
		end

		if Attacker and not ActiveAttackers[Player][Attacker] then
			local function Cleanup()
				if ActiveAttackers[Player] and ActiveAttackers[Player][Attacker] then
					ActiveAttackers[Player][Attacker]:Disconnect()
					ActiveAttackers[Player][Attacker] = nil
				end
				if ActiveAttackers[Player] and next(ActiveAttackers[Player]) == nil then
					ActiveAttackers[Player] = nil
					Player:SetAttribute("InCombat", false)
					Character:SetAttribute("InCombat", false)
					Player:SetAttribute("InCombatEndTick", nil)
				end
			end

			local Conn
			local Hum = Attacker:FindFirstChild("Humanoid")
			if Hum then
				Conn = Attacker:GetAttributeChangedSignal("Died"):Connect(Cleanup)
			else
				Conn = Attacker.Destroying:Connect(Cleanup)
			end
			ActiveAttackers[Player][Attacker] = Conn
		end
	else
		if Attacker and ActiveAttackers[Player] and ActiveAttackers[Player][Attacker] then
			ActiveAttackers[Player][Attacker]:Disconnect()
			ActiveAttackers[Player][Attacker] = nil
		end
		if ActiveAttackers[Player] and next(ActiveAttackers[Player]) == nil then
			ActiveAttackers[Player] = nil
			Player:SetAttribute("InCombat", false)
			Character:SetAttribute("InCombat", false)
			Player:SetAttribute("InCombatEndTick", nil)
		end
	end
end

function InCombatService:GetInCombatWith(Character: Model)
	return ActiveAttackers[Players:GetPlayerFromCharacter(Character)]
end

return InCombatService
