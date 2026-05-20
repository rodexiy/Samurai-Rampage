local Knit = require(game.ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid

local CurrentTool = nil
local ActivatedConnection = nil

local ToolService = Knit.GetService("ToolService")
local AnimationController = Knit.GetController("AnimationController")
local WeaponService = Knit.GetService("WeaponService")

local Validate = require(game.ReplicatedStorage.Shared.Validate)

local contextBindsNames = {}
local InputController = require(script.Parent.Parent.InputController)

local ToolsClient = {}

local function CallToolClientFunction(tool: Tool, Function: string)
	if ToolsClient[tool.Name] and ToolsClient[tool.Name][Function] then
		task.spawn(ToolsClient[tool.Name][Function], Character, tool)
	end
end

function toolEquipped(tool)
	local toolType = tool:GetAttribute("Class")

	local ToolTypes = {
		Usable = function()
			ToolService:ToolInput("Equipped")
		end,

		Skill = function()
			local skillName = tool:GetAttribute("SkillName")

			-- SkillService:SkillInput(skillName, Enum.UserInputState.Begin, {CharacterCFrame = Character:GetPivot()})

			repeat
				task.wait()
			until tool.Parent == Character

			Humanoid:UnequipTools()
		end,
	}

	CallToolClientFunction(tool, "Equipped")

	if ToolTypes[toolType] then
		ToolTypes[toolType]()
	end

	if
		not tool:GetAttribute("CanBeEquippedWithWeapon")
		and Character:GetAttribute("WeaponEquipped")
		and toolType ~= "Skill"
	then
		Character:SetAttribute("CallUnequipWeaponClient", true)
		task.defer(function()
			Character:SetAttribute("CallUnequipWeaponClient", false)
		end)
	end

	local IdleAnimation = game.ReplicatedStorage.Assets.Animations.Tools.DefaultIdle
	if tool:FindFirstChild("Animations") then
		IdleAnimation = tool.Animations:FindFirstChild("Idle")
			or game.ReplicatedStorage.Assets.Animations.Tools.DefaultIdle
	end

	local Track = AnimationController:PlayAnimation(Character, IdleAnimation)
	Track.Looped = true
	Track.Name = "TOOL_IDLE"
end

function ToolUnequipped(tool)
	local toolType = tool:GetAttribute("Class")
	local ToolTypes = {
		Usable = function()
			ToolService:ToolInput("Unequipped")
		end,

		Skill = function() end,

		Equipable = function() end,
	}

	CallToolClientFunction(tool, "Unequipped")

	if ToolTypes[toolType] then
		ToolTypes[toolType]()
	end

	AnimationController:StopAnimationFind(Character, "TOOL_IDLE")
end

function toolActivated(tool)
	local toolType = tool:GetAttribute("Class")

	local ToolTypes = {
		Usable = function()
			ToolService:ToolInput("Activated")
		end,

		Equipable = function()
			-- InventoryService:EquipItem()
		end,

		Artifact = function()
			ToolService:ToolInput("Activated")
		end,
	}

	CallToolClientFunction(tool, "Activated")

	if ToolTypes[toolType] then
		ToolTypes[toolType]()
	end
end

function unbindTool()
	if CurrentTool then
		if ActivatedConnection then
			ActivatedConnection:Disconnect()
		end
	end
end

function bindTool(tool)
	if CurrentTool then
		unbindTool()
	end

	CurrentTool = tool
	ActivatedConnection = tool.Activated:Connect(function()
		toolActivated(tool)
	end)
end

for _, ToolModule in game.ReplicatedStorage.Shared.ToolClient:GetChildren() do
	ToolsClient[ToolModule.Name] = require(ToolModule)
end

Character.ChildAdded:Connect(function(child)
	if not child:IsA("Tool") then
		return
	end

	toolEquipped(child)
	bindTool(child)
end)

Character.ChildRemoved:Connect(function(child)
	if not child:IsA("Tool") then
		return
	end
	ToolUnequipped(child)
	unbindTool()
end)
