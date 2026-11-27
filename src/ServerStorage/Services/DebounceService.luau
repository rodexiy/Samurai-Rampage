local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[[
    Módulo responsável por adicionar debounces á um Character.
    Os debounces podem ser "sobrepostos", removendo necessidade de utilizar instancias em pastas.
]]

local DebounceService = Knit.CreateService({
	Name = "DebounceService",
	Client = {},
})

type Debounce = { Name: string }
local CharacterDebounces: { [Model]: { Debounce } } = {}

local function FindDebounceIndex(Debounces: { Debounce }, Name: string): number?
	for Index, Debounce in Debounces do
		if Debounce.Name == Name then
			return Index
		end
	end

	return nil
end

--[[ adiciona um debounce no Character, pode apenas ser valores booleanos ]]
function DebounceService:AddDebounce(Character: Model, debounceName: string, time: number, setEndTick: boolean?)
	local Debounces = DebounceService:GetCharacterDebounces(Character)
	local Entry = { Name = debounceName }

	table.insert(Debounces, Entry)

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
		local Index = table.find(Debounces, Entry)
		if not Index then
			return
		end

		table.remove(Debounces, Index)

		if not DebounceService:HaveDebounce(Character, debounceName) then
			Character:SetAttribute(debounceName, false)
			Character:SetAttribute(debounceName .. "EndTick", nil)
		end
	end)
end

function DebounceService:HaveDebounce(Character: Model, debounceName: string): boolean
	return FindDebounceIndex(DebounceService:GetCharacterDebounces(Character), debounceName) ~= nil
end

function DebounceService:RemoveDebounce(Character: Model, debounceName: string)
	local Debounces = DebounceService:GetCharacterDebounces(Character)

	local Index = FindDebounceIndex(Debounces, debounceName)

	if Index then
		table.remove(Debounces, Index)

		if not DebounceService:HaveDebounce(Character, debounceName) then
			Character:SetAttribute(debounceName, false)
			Character:SetAttribute(debounceName .. "EndTick", nil)
		end
	end
end

function DebounceService:RemoveCharacterDebounces(Character: Model)
	local Debounces = CharacterDebounces[Character]
	if Debounces then
		while #Debounces > 0 do
			DebounceService:RemoveDebounce(Character, Debounces[1].Name)
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

function DebounceService:GetCharacterDebounces(Character: Model): { Debounce }
	local Debounces = CharacterDebounces[Character]
	if not Debounces then
		Debounces = DebounceService:SetCharacterDebounces(Character)
	end

	return CharacterDebounces[Character]
end

return DebounceService
