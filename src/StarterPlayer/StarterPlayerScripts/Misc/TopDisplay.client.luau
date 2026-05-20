local CollectionService = game:GetService("CollectionService")
local StatusDisplayManager = require(game.ReplicatedStorage.Shared.Utils.StatusDisplayManager)

local function attach(entity)
	if not entity:IsA("Model") then
		return
	end
	if CollectionService:HasTag(entity, "Boss") then
		return
	end

	StatusDisplayManager:AddTopDisplay(entity)

	local conn
	conn = entity:GetAttributeChangedSignal("Died"):Connect(function()
		if entity:GetAttribute("Died") then
			StatusDisplayManager:RemoveTopDisplay(entity)
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end
	end)
end

for _, entity in ipairs(CollectionService:GetTagged("Entity")) do
	attach(entity)
end

CollectionService:GetInstanceAddedSignal("Entity"):Connect(attach)
