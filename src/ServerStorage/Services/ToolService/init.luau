local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ToolService = Knit.CreateService({
	Name = "ToolService",
	Client = {},
})

local ItemService
local InventoryService
local DataService

local Tools = {}

function ToolService:ToolInput(Character: Model, Input: string, Data: { any })
	local CharacterTool = Character:FindFirstChildWhichIsA("Tool")
	if not CharacterTool then
		return
	end

	local Tool = Tools[CharacterTool.Name]

	if Tool and Tool[Input] then
		Tool[Input](Character, Data)
		return
	end

	local Class = CharacterTool:GetAttribute("Class")
	if Class then
		if Tools[Class] and Tools[Class][Input] then
			Tools[Class][Input](Character, Data)
		end
	end
end
function ToolService.Client:ToolInput(Player: Player, Input: string, Data: { any })
	self.Server:ToolInput(Player.Character, Input, Data)
end

local AttributeTypes = {
	"vector3",
	"number",
	"boolean",
	"string",
	"cframe",
	"color3",
}

function ToolService:CopyAttributesToTool(Tool: Tool, Data: { any })
	for name, value in Data do
		if table.find(AttributeTypes, typeof(value)) then
			Tool:SetAttribute(name, value)
		end
	end
end

local ItemTools = ReplicatedStorage.Assets.Tools
function ToolService:GiveToolToPlayer(
	Player: Player,
	ToolName: string,
	index: number,
	ignoreCheck: boolean,
	StackId: string?
)
	local Data = DataService:GetData(Player)
	StackId = StackId or (Data.HotbarStackIds or {})[tostring(index)] or ToolName
	local ItemData = InventoryService:GetPlayerStack(Player, StackId)
	if not ItemData then
		if not ignoreCheck then
			return
		end
		ItemData = ItemService:GetItemData(ToolName)
	end

	local Tool
	if ItemData.Class == "Skill" then
		Tool = Instance.new("Tool")
		Tool.Name = ToolName
	else
		local _Tool = ItemTools:FindFirstChild(ToolName)
		if not _Tool then
			return
		end

		Tool = _Tool:Clone()
	end

	Tool.RequiresHandle = false
	Tool.CanBeDropped = false

	local FullItemData = ItemService:GetItemData(ToolName)
	self:CopyAttributesToTool(Tool, FullItemData)
	self:CopyAttributesToTool(Tool, ItemData)
	Tool:SetAttribute("HotbarIndex", tonumber(index))
	Tool:SetAttribute("Id", StackId)

	Tool.Parent = Player.Backpack
end

function ToolService:LoadPlayerTools(Player: Player)
	InventoryService:GetInventoryLayout(Player)
	local PlayerData = DataService:GetData(Player)

	for index, ToolName in PlayerData.Hotbar do
		self:GiveToolToPlayer(Player, ToolName, index)
	end
end

function ToolService:RemoveToolFromCharacter(Character: Model, ToolName: string?, StackId: string?)
	if not Character then
		return
	end

	local Tool = Character:FindFirstChildWhichIsA("Tool")
	if
		Tool
		and (not ToolName or Tool.Name == ToolName)
		and (not StackId or (Tool:GetAttribute("Id") or Tool.Name) == StackId)
	then
		Tool:Destroy()
	end
end

function ToolService:RemoveToolFromPlayer(Player: Player, ToolName: string, StackId: string?)
	for _, Tool in Player.Backpack:GetChildren() do
		if
			Tool:IsA("Tool")
			and Tool.Name == ToolName
			and (not StackId or (Tool:GetAttribute("Id") or Tool.Name) == StackId)
		then
			Tool:Destroy()
		end
	end

	self:RemoveToolFromCharacter(Player.Character, ToolName, StackId)
end

function ToolService:GetToolFromPlayer(Player: Player, ToolName: string, StackId: string?): Tool?
	for _, Tool in Player.Backpack:GetChildren() do
		if
			Tool:IsA("Tool")
			and Tool.Name == ToolName
			and (not StackId or (Tool:GetAttribute("Id") or Tool.Name) == StackId)
		then
			return Tool
		end
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local Tool = Character:FindFirstChildWhichIsA("Tool")
	if Tool and Tool.Name == ToolName and (not StackId or (Tool:GetAttribute("Id") or Tool.Name) == StackId) then
		return Tool
	end
	return nil
end

function ToolService.KnitInit()
	ItemService = Knit.GetService("ItemService")
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
end

function ToolService.KnitStart()
	for _, Tool in script:GetDescendants() do
		if Tool:IsA("ModuleScript") then
			Tools[Tool.Name] = require(Tool)
		end
	end
end

return ToolService
