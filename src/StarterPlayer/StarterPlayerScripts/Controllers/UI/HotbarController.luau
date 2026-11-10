local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local HotbarController = Knit.CreateController({
	Name = "HotbarController",
})

local InventoryService
local SkillService
local AnimationController
local InventoryController
local MenuController

local Player = game.Players.LocalPlayer
local PlayerGui
local Hud
local Hotbar
local Background

local SkillTreeController

local EquipDebounce = false
local SelectedSlot
local Ghosts = false
local DialogHidden = false
local PendingHotbarItem: string? = nil
local AssigningSlots: { [number]: boolean } = {}

local Character = Player.Character
local KeysDisplay = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 0,
}

local EquippedTextColor = Color3.fromRGB(255, 183, 0)
local EasyVisuals = require(ReplicatedStorage.Assets.Libraries.EasyVisuals)

function HotbarController:HotbarEnabledBooleans(): (boolean, boolean)
	local Menu = PlayerGui and PlayerGui:FindFirstChild("Menu")
	local SkillTree = Menu and Menu:FindFirstChild("SkillTree") :: ScreenGui?

	return self:IsSelectingSlot() or (SkillTree ~= nil and SkillTree.Enabled), self:IsSelectingSlot()
end

function HotbarController:IsSelectingSlot(): boolean
	return PendingHotbarItem ~= nil
end

function HotbarController:UpdateVisibility()
	if Hotbar then
		Hotbar.Enabled = not DialogHidden and not InventoryController:IsOpen()
	end
end

function HotbarController:CancelSlotSelection()
	if not PendingHotbarItem then
		return
	end

	PendingHotbarItem = nil
	MenuController:SetHudFocus(false)
	self:LoadHotbar(self:HotbarEnabledBooleans())
	self:UpdateVisibility()
end

function HotbarController:BeginSlotSelection(ItemName: string)
	if DialogHidden or not Hotbar then
		return
	end

	MenuController:CloseAllMenus()
	PendingHotbarItem = ItemName
	MenuController:SetHudFocus(true, Hotbar)
	self:LoadHotbar(true, true)
	self:UpdateVisibility()
end

function HotbarController:ConfirmSlotSelection(Index: number)
	local ItemName = PendingHotbarItem
	if not ItemName or Index < 0 or Index > 9 or Index % 1 ~= 0 then
		return
	end

	self:CancelSlotSelection()
	InventoryService:EquipToHotbar(ItemName, Index)
end

function HotbarController:SetDialogHidden(Hidden: boolean)
	DialogHidden = Hidden

	if Hidden then
		self:CancelSlotSelection()
	end

	self:UpdateVisibility()
end

function HotbarController:GetToolInHotbarIndex(Index: number)
	for _, Tool: Tool in Player.Backpack:GetChildren() do
		if Tool:GetAttribute("HotbarIndex") == tonumber(Index) then
			return Tool
		end
	end
	if not Character then
		return
	end

	local Tool: Tool = Character:FindFirstChildWhichIsA("Tool")
	if Tool and Tool:GetAttribute("HotbarIndex") == tonumber(Index) then
		return Tool
	end
end

local Collector = require(ReplicatedStorage.Shared.Collector)
local Connections = Collector.new()

local CooldownTweens = {}
function HotbarController:ClearHotbar()
	Connections:DisconnectAll()

	for _, child in Background:GetChildren() do
		if child:IsA("ImageButton") then
			local Tween = CooldownTweens[child.Cooldown]

			if Tween then
				local ToolInIndex = HotbarController:GetToolInHotbarIndex(child.Name)
				if not ToolInIndex or ToolInIndex.Name ~= child.ItemName.Text:gsub(" ", "") then
					Tween:Cancel()
					CooldownTweens[child.Cooldown] = nil

					child.Cooldown.UIGradient.Offset = Vector2.new(0, -0.5)
					child.Cooldown.Visible = false

					child.Cooldown:SetAttribute("TweeningEndTickOf", nil)
				end
			end

			child.ItemName.Text = ""
			child.ItemNameShadow.Text = ""
			child.HotbarIndex.Text = child.Name
			child.HotbarIndexShadow.Text = child.Name
			child.HotbarIndex.TextColor3 = Color3.fromRGB(254, 254, 254)
			child.ItemName.TextColor3 = Color3.fromRGB(254, 254, 254)
		end
	end
end

local Visuals = {}

function HotbarController:LoadHotbar(_Ghosts: boolean, Selected: boolean)
	if not Background then
		return
	end

	Ghosts = _Ghosts
	HotbarController:ClearHotbar()

	if not Character then
		return
	end

	for _, Visual in Visuals do
		Visual:Destroy()
	end
	table.clear(Visuals)

	for i = 0, 9 do
		local Tool: Tool = HotbarController:GetToolInHotbarIndex(i)
		if Tool or Ghosts then
			local Template = Background[i]
			Template:SetAttribute("HotbarIndex", i)

			if Selected then
				table.insert(Visuals, EasyVisuals.new(Template, "GhostStroke", 1, 1))
			end

			Template.HotbarIndex.Text = i
			Template.HotbarIndexShadow.Text = i
			Template.ItemName.Text = ""
			Template.ItemNameShadow.Text = ""
			if Tool then
				Template.ItemName.Text = Tool:GetAttribute("DisplayName") or Tool.Name
				Template.ItemNameShadow.Text = Tool:GetAttribute("DisplayName") or Tool.Name

				local function TweenEndTick()
					local EndTick = Character:GetAttribute(Tool.Name .. "DebounceEndTick")

					if not EndTick then
						return
					end

					if Template.Cooldown:GetAttribute("TweeningEndTickOf") ~= Tool.Name then
						local Duration = EndTick - workspace:GetServerTimeNow()

						Template.Cooldown.Visible = true
						Template.Cooldown.UIGradient.Offset = Vector2.new(0, -0.5)
						CooldownTweens[Template.Cooldown] = TweenService:Create(
							Template.Cooldown.UIGradient,
							TweenInfo.new(Duration, Enum.EasingStyle.Linear),
							{
								Offset = Vector2.new(0, 0.5), -- Moves the gradient upward
							}
						)

						CooldownTweens[Template.Cooldown]:Play()

						task.delay(Duration, function()
							Template.Cooldown:SetAttribute("TweeningEndTickOf", nil)
						end)
					end

					Template.Cooldown:SetAttribute("TweeningEndTickOf", Tool.Name)
				end

				if Character:GetAttribute(Tool.Name .. "DebounceEndTick") then
					TweenEndTick()
				end

				Connections:Add(Character:GetAttributeChangedSignal(Tool.Name .. "DebounceEndTick"):Connect(function()
					TweenEndTick()
				end))

				local CharacterTool = Character:FindFirstChildWhichIsA("Tool")
				if CharacterTool and CharacterTool == Tool then
					Template.ItemName.TextColor3 = EquippedTextColor
					Template.HotbarIndex.TextColor3 = EquippedTextColor
				else
					Template.ItemName.TextColor3 = Color3.fromRGB(254, 254, 254)
					Template.HotbarIndex.TextColor3 = Color3.fromRGB(254, 254, 254)
				end
			end
		end
	end

	self:UpdateVisibility()
end

function HotbarController:HandleEquip()
	local Tool = HotbarController:GetToolInHotbarIndex(SelectedSlot)
	local Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then
		return
	end

	if Tool then
		if Tool.Parent ~= Player.Character then
			Humanoid:EquipTool(Tool)
			Tool.Parent = Player.Character
		else
			Humanoid:UnequipTools()
			if Tool.Parent ~= nil then
				Tool.Parent = Player.Backpack
			end
		end
	else
		Humanoid:UnequipTools()
		if Tool and Tool.Parent ~= nil then
			Tool.Parent = Player.Backpack
		end
	end

	HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
end

function HotbarController:GetToolByNameFromPlayer(ToolName: string)
	for _, Tool: Tool in Player.Backpack:GetChildren() do
		if Tool.Name == ToolName then
			return Tool
		end
	end

	local Tool: Tool = Character:FindFirstChildWhichIsA("Tool")
	if Tool and Tool.Name == ToolName then
		return Tool
	end
end

local Camera = workspace.CurrentCamera
local Mouse = Player:GetMouse()
local Items = require(ReplicatedStorage.Shared.Index.Items)
local Validate = require(ReplicatedStorage.Shared.Validate)

local Released = false
function HotbarController.OnKeyPress(value: number, state: Enum.UserInputState)
	if not value or not Character then
		return
	end

	if DialogHidden or Player:GetAttribute("InDialog") then
		return
	end

	if state == Enum.UserInputState.End and AssigningSlots[value] then
		AssigningSlots[value] = nil
		return
	end

	if HotbarController:IsSelectingSlot() then
		if state == Enum.UserInputState.Begin then
			AssigningSlots[value] = true
			HotbarController:ConfirmSlotSelection(value)
		end

		return
	end

	if InventoryController:IsOpen() then
		return
	end

	local _Tool = HotbarController:GetToolInHotbarIndex(value)
	if not _Tool then
		return
	end

	if Character.Humanoid.Health <= 0 then
		return
	end

	if state == Enum.UserInputState.Begin and EquipDebounce then
		return
	end

	EquipDebounce = true
	task.delay(0.1, function()
		EquipDebounce = false
	end)

	if _Tool:GetAttribute("Class") == "Skill" then
		local SkillData = Items[_Tool.Name]
		local Origin = Mouse.Origin
		local Params = RaycastParams.new()
		Params.FilterDescendantsInstances = { Character, workspace.FaceHeadFolder }
		Params.FilterType = Enum.RaycastFilterType.Exclude

		local LookAtMouse = Character.HumanoidRootPart:FindFirstChild("LookAtMouse")
		local LockCharacterMouse = Character.HumanoidRootPart:FindFirstChild("LockCharacterMouse") :: AlignPosition

		if state == Enum.UserInputState.End then
			if LookAtMouse then
				if SkillData.LockOnRelease then
					Released = true
				else
					LookAtMouse.Enabled = false
					LockCharacterMouse.Enabled = false
				end
			end
		end

		if state == Enum.UserInputState.Begin then
			local StaminaCost = SkillData.StaminaCost or 0

			if SkillData and SkillData.FollowMouse and Validate:CanUseSkill(Character, StaminaCost) then
				task.spawn(function()
					local MaxHoldDuration = SkillData.MaxHoldDuration or 5
					Released = false

					if LookAtMouse then
						if not LookAtMouse.Enabled then
							LookAtMouse.Enabled = true
							LockCharacterMouse.Position = Character:GetPivot().Position
							LockCharacterMouse.Enabled = true
							local Acc = 0
							AnimationController:PlayAnimation(
								Character,
								game.ReplicatedStorage.Assets.Animations.Skills.Artifacts.ThunderHeart.ThunderWrathStart
							)

							while LookAtMouse.Enabled and not Released do
								LookAtMouse.CFrame = CFrame.new(Mouse.Hit.p)
								Acc += task.wait()

								if Acc >= MaxHoldDuration then
									SkillService:UseSkill(_Tool.Name, {
										RootCFrame = Character:GetPivot(),
										CameraCFrame = Camera.CFrame,
										MouseHit = Mouse.Hit,
										MouseCast = workspace:Spherecast(
											Origin.Position,
											5,
											Mouse.UnitRay.Direction * 1000,
											Params
										),
										InputState = Enum.UserInputState.End,
									})

									if not SkillData.LockOnRelease then
										LookAtMouse.Enabled = false
										LockCharacterMouse.Enabled = false
									end
								end
							end

							if not SkillData.LockOnRelease or Character:GetAttribute("SkillState") == "Charged" then
								task.delay(Character:GetAttribute("Ping"), function()
									AnimationController:StopAnimationFind(Character, "ThunderWrathStart")
								end)
							else
								task.spawn(function()
									repeat
										task.wait()
									until Character:GetAttribute("SkillState") ~= "Charge"
									task.wait(0.1)
									AnimationController:StopAnimationFind(Character, "ThunderWrathStart")
								end)
							end

							Released = false
						end
					end
				end)
			end

			SkillService:UseSkill(_Tool.Name, {
				RootCFrame = Character:GetPivot(),
				CameraCFrame = Camera.CFrame,
				MouseHit = Mouse.Hit,
				MouseCast = workspace:Spherecast(Origin.Position, 5, Mouse.UnitRay.Direction * 1000, Params),
				InputState = state,
			})
		end

		if SkillData and SkillData.FireOnRelease and state == Enum.UserInputState.End then
			SkillService:UseSkill(_Tool.Name, {
				RootCFrame = Character:GetPivot(),
				CameraCFrame = Camera.CFrame,
				MouseHit = Mouse.Hit,
				MouseCast = workspace:Spherecast(Origin.Position, 5, Mouse.UnitRay.Direction * 1000, Params),
				InputState = state,
			})
		end

		Character.Humanoid:UnequipTools()
		return
	end

	if state ~= Enum.UserInputState.Begin then
		return
	end

	if value == SelectedSlot then
		SelectedSlot = nil
	else
		SelectedSlot = value
	end

	if value and UserInputService:GetFocusedTextBox() == nil then
		HotbarController:HandleEquip()
	end
end

function HotbarController:BindCharacter()
	Character = Player.Character
	if not Character then
		return
	end

	Character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(function()
				if not Character:FindFirstChildWhichIsA("Tool") then
					HotbarController.OnKeyPress(SelectedSlot)
				end
			end)
		end
	end)

	Character:GetAttributeChangedSignal("Loaded"):Connect(function()
		if Character:GetAttribute("Loaded") then
			HotbarController:ClearHotbar()
			HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
		end
	end)

	Character:GetAttributeChangedSignal("UnlockMouse"):Connect(function()
		if not Character:GetAttribute("UnlockMouse") then
			return
		end
		local LookAtMouse = Character.HumanoidRootPart:FindFirstChild("LookAtMouse")
		local LockCharacterMouse = Character.HumanoidRootPart:FindFirstChild("LockCharacterMouse") :: AlignPosition

		LookAtMouse.Enabled = false
		LockCharacterMouse.Enabled = false
	end)

	Character:GetAttributeChangedSignal("SkillState"):Connect(function()
		if not Character:GetAttribute("SkillState") then
			local LookAtMouse = Character.HumanoidRootPart:FindFirstChild("LookAtMouse")
			local LockCharacterMouse = Character.HumanoidRootPart:FindFirstChild("LockCharacterMouse") :: AlignPosition

			LookAtMouse.Enabled = false
			LockCharacterMouse.Enabled = false
		end
	end)

	Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if not Character:GetAttribute("Ragdoll") then
			return
		end
		local LookAtMouse = Character.HumanoidRootPart:FindFirstChild("LookAtMouse")
		local LockCharacterMouse = Character.HumanoidRootPart:FindFirstChild("LockCharacterMouse") :: AlignPosition

		LookAtMouse.Enabled = false
		LockCharacterMouse.Enabled = false
	end)
end

function HotbarController.KnitInit()
	InventoryService = Knit.GetService("InventoryService")
	InventoryController = Knit.GetController("InventoryController")
	MenuController = Knit.GetController("MenuController")
	SkillService = Knit.GetService("SkillService")
	SkillTreeController = Knit.GetController("SkillTreeController")
	AnimationController = Knit.GetController("AnimationController")
end

function HotbarController:BindButtons()
	for i = 0, 9 do
		local button = Background[i]
		button.Activated:Connect(function()
			if self:IsSelectingSlot() then
				self:ConfirmSlotSelection(i)
				return
			end

			local SelectedNode = SkillTreeController:GetSelected()
			local SkillTree = MenuController:GetMenu("SkillTree")

			if SelectedNode and SkillTree and SkillTree.Enabled then
				SelectedNode = SelectedNode:gsub(" ", "")
				InventoryService:EquipToHotbar(SelectedNode, i)
				HotbarController:LoadHotbar(false, false)
			elseif not Ghosts then
				local State

				if button.GuiState == Enum.GuiState.Press then
					State = Enum.UserInputState.Begin
				elseif button.GuiState == nil then
					State = Enum.UserInputState.End
				end

				HotbarController.OnKeyPress(i, State)
			elseif button.ItemName.Text ~= "" then
				InventoryService:RemoveItemFromHotbar(i)
			end
		end)
	end
end

function HotbarController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Hud = PlayerGui:WaitForChild("Hud")
	Hotbar = Hud:WaitForChild("NewHotbar")
	Background = Hotbar:WaitForChild("Background")
	HotbarController:UpdateVisibility()

	Player.Backpack.ChildAdded:Connect(function()
		if Character and Character:GetAttribute("Loaded") then
			HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
		end
	end)
	Player.Backpack.ChildRemoved:Connect(function()
		if Character and Character:GetAttribute("Loaded") then
			HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
		end
	end)

	Player.CharacterAdded:Connect(function(character)
		HotbarController:CancelSlotSelection()
		HotbarController:ClearHotbar()
		Character = character

		HotbarController:BindCharacter()
	end)

	Character = Player.Character

	UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if input.KeyCode == Enum.KeyCode.Escape and HotbarController:IsSelectingSlot() then
			HotbarController:CancelSlotSelection()
			return
		end

		if gameProcessedEvent then
			return
		end

		local value = KeysDisplay[input.KeyCode]
		if not value then
			return
		end

		HotbarController.OnKeyPress(value, Enum.UserInputState.Begin)
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then
			return
		end

		local value = KeysDisplay[input.KeyCode]
		if not value then
			return
		end

		HotbarController.OnKeyPress(value, Enum.UserInputState.End)
	end)

	if Character then
		HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
	end

	InventoryService.HotbarUpdated:Connect(function()
		if Character then
			HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
		end
	end)

	HotbarController:BindCharacter()
	HotbarController:BindButtons()
end

return HotbarController
