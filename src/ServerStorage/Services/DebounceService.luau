local Knit = require(game.ReplicatedStorage.Packages.Knit)

--[[
    Módulo responsável por adicionar debounces á um Character.
    Os debounces podem ser "sobrepostos", removendo necessidade de utilizar instancias em pastas.
]]

local DebounceService = Knit.CreateService({
	Name = "DebounceService",
	Client = {},
})

local CharacterDebounces = {}

--[[ adiciona um debounce no Character, pode apenas ser valores booleanos ]]
function DebounceService:AddDebounce(Character: Model, debounceName: string, time: number, setEndTick: boolean?)
	local Debounces = DebounceService:GetCharacterDebounces(Character)

	table.insert(Debounces, debounceName)

	Character:SetAttribute(debounceName, true)

	if setEndTick then
		if Character:GetAttribute(debounceName .. "EndTick") then
			if tick() + time > Character:GetAttribute(debounceName .. "EndTick") then
				Character:SetAttribute(debounceName .. "EndTick", workspace:GetServerTimeNow() + time)
			end
		else
			Character:SetAttribute(debounceName .. "EndTick", workspace:GetServerTimeNow() + time)
		end
	end

	task.delay(time, function()
		local Index = table.find(Debounces, debounceName)

		table.remove(Debounces, Index)

		if not DebounceService:HaveDebounce(Character, debounceName) then
			Character:SetAttribute(debounceName, false)
			Character:SetAttribute(debounceName .. "EndTick", nil)
		end
	end)
end

function DebounceService:HaveDebounce(Character: Model, debounceName: string)
	local Debounces = DebounceService:GetCharacterDebounces(Character)

	local Index = table.find(Debounces, debounceName)
	if Index then
		return true
	end

	return false
end

function DebounceService:RemoveDebounce(Character: Model, debounceName: string)
	local Debounces = DebounceService:GetCharacterDebounces(Character)

	local Index = table.find(Debounces, debounceName)

	if Index then
		table.remove(Debounces, Index)

		if not DebounceService:HaveDebounce(Character, debounceName) then
			Character:SetAttribute(debounceName, false)
			Character:SetAttribute(debounceName .. "EndTick", nil)
		end
	end
end

function DebounceService:RemoveCharacterDebounces(Character: Model)
	if CharacterDebounces[Character] then
		while #CharacterDebounces[Character] > 0 do
			for _, debounceName in CharacterDebounces[Character] do
				DebounceService:RemoveDebounce(Character, debounceName)
			end
		end

		CharacterDebounces[Character] = nil
	end
end

function DebounceService:SetCharacterDebounces(Character: Model)
	if not CharacterDebounces[Character] then
		CharacterDebounces[Character] = {}
	end

	return CharacterDebounces[Character]
end

function DebounceService:GetCharacterDebounces(Character: Model)
	local Debounces = CharacterDebounces[Character]
	if not Debounces then
		Debounces = DebounceService:SetCharacterDebounces(Character)
	end

	return CharacterDebounces[Character]
end

return DebounceService
