local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryHotbarSlots = require(ReplicatedStorage.Shared.Utils.InventoryHotbarSlots)

type HotbarSlot = {
	Button: ImageButton,
	ItemName: TextLabel,
	Index: TextLabel,
	Amount: TextLabel,
	Cooldown: Frame,
	Stroke: UIStroke?,
	TextColor: Color3,
	IndexColor: Color3,
	StrokeColor: Color3?,
	Tool: Tool?,
	Character: Model?,
	Connections: { RBXScriptConnection },
}

local HotbarController = Knit.CreateController({
	Name = "HotbarController",
})

local InventoryService
local SkillService
local AnimationController
local InventoryController
local MenuController
local InventoryDragController

local Player = Players.LocalPlayer
local PlayerGui: PlayerGui
local Hud: ScreenGui
local Hotbar: ScreenGui
local Background: Frame
local InventoryGui: ScreenGui?
local Slots: { [number]: HotbarSlot } = {}

local SkillTreeController

local EquipDebounce = false
local SelectedSlot: number?
local Ghosts = false
local DialogHidden = false
local InventoryModalHidden = false
local SelectionHighlight = false
local RefreshQueued = false
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

function HotbarController:HotbarEnabledBooleans(): (boolean, boolean)
	local Menu = PlayerGui and PlayerGui:FindFirstChild("Menu")
	local SkillTree = Menu and Menu:FindFirstChild("SkillTree") :: ScreenGui?

	return InventoryController:IsOpen() or self:IsSelectingSlot() or (SkillTree ~= nil and SkillTree.Enabled),
		self:IsSelectingSlot()
end

function HotbarController:IsSelectingSlot(): boolean
	return PendingHotbarItem ~= nil
end

function HotbarController:UpdateVisibility()
	local InventoryOpen = InventoryController:IsOpen()
	if Background and Hotbar then
		local Parent = if InventoryOpen and InventoryGui then InventoryGui else Hotbar
		if Background.Parent ~= Parent then
			Background.Parent = Parent
		end
		Background.Visible = not DialogHidden and not InventoryModalHidden
	end

	if Hotbar then
		Hotbar.Enabled = not DialogHidden and not InventoryOpen
	end
end

function HotbarController:SetInventoryModalHidden(Hidden: boolean)
	InventoryModalHidden = Hidden
	self:UpdateVisibility()
end

function HotbarController:ConfigureInventory(Gui: ScreenGui)
	InventoryGui = Gui
	self:UpdateVisibility()
end

function HotbarController:GetSlotAtPoint(Point: Vector2): (number?, ImageButton?)
	if not InventoryController:IsOpen() or DialogHidden or not Background or not Background.Visible then
		return nil, nil
	end

	for Index, Slot in Slots do
		local Button = Slot.Button
		local Position, Size = Button.AbsolutePosition, Button.AbsoluteSize
		if
			Button.Visible
			and Point.X >= Position.X
			and Point.Y >= Position.Y
			and Point.X < Position.X + Size.X
			and Point.Y < Position.Y + Size.Y
		then
			return Index, Button
		end
	end

	return nil, nil
end

function HotbarController:GetSlotButtons(): { [number]: ImageButton }
	local Buttons: { [number]: ImageButton } = {}
	if InventoryController:IsOpen() and not DialogHidden and Background and Background.Visible then
		for Index, Slot in Slots do
			if Slot.Button.Visible then
				Buttons[Index] = Slot.Button
			end
		end
	end

	return Buttons
end

function HotbarController:CanAssignItem(Item: { [string]: any }, Index: number): boolean
	local Tool = self:GetToolInHotbarIndex(Index)
	return InventoryHotbarSlots.IsValidIndex(Index)
		and InventoryHotbarSlots.Accepts(Item)
		and (not Tool or Tool:GetAttribute("Class") ~= "Artifact")
end

function HotbarController:CanMoveSlot(SourceIndex: number, Index: number, ItemName: string): boolean
	if not InventoryHotbarSlots.IsValidIndex(SourceIndex) or not InventoryHotbarSlots.IsValidIndex(Index) then
		return false
	end

	local Tool = self:GetToolInHotbarIndex(SourceIndex)
	return Tool ~= nil and (Tool:GetAttribute("Id") or Tool.Name) == ItemName
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

function HotbarController:GetToolInHotbarIndex(Index: number?): Tool?
	if Index == nil then
		return nil
	end

	for _, Tool: Tool in Player.Backpack:GetChildren() do
		if Tool:IsA("Tool") and Tool:GetAttribute("HotbarIndex") == Index then
			return Tool
		end
	end
	if not Character then
		return nil
	end

	local Tool = Character:FindFirstChildWhichIsA("Tool")
	if Tool and Tool:GetAttribute("HotbarIndex") == Index then
		return Tool
	end

	return nil
end

local CooldownTweens: { [Frame]: Tween } = {}

function HotbarController:CreateSlots()
	local Template = Background:WaitForChild("HotbarTemplate") :: ImageButton
	Template.Visible = false

	for Order = 1, 10 do
		local Index = Order % 10
		local Button = Template:Clone()
		Button.Name = tostring(Index)
		Button.LayoutOrder = Order
		Button.Size = UDim2.fromScale(1, 1)
		Button:SetAttribute("EquipmentSlot", nil)
		Button:SetAttribute("HotbarIndex", Index)
		Button.Visible = false

		local NameLabel = Button:WaitForChild("ItemName") :: TextLabel
		local IndexLabel = Button:WaitForChild("HotbarIndex") :: TextLabel
		local AmountLabel = Button:WaitForChild("ItemAmount") :: TextLabel
		local Cooldown = Button:WaitForChild("Cooldown") :: Frame
		local Stroke = Button:FindFirstChildWhichIsA("UIStroke")
		Cooldown.Visible = false
		Cooldown.Size = UDim2.fromScale(1, 0)
		IndexLabel.Text = tostring(Index)
		NameLabel.Text = ""
		AmountLabel.Text = ""

		Slots[Index] = {
			Button = Button,
			ItemName = NameLabel,
			Index = IndexLabel,
			Amount = AmountLabel,
			Cooldown = Cooldown,
			Stroke = Stroke,
			TextColor = NameLabel.TextColor3,
			IndexColor = IndexLabel.TextColor3,
			StrokeColor = if Stroke then Stroke.Color else nil,
			Connections = {},
		}
		Button.Parent = Background
	end
end

local function ClearCooldown(Slot: HotbarSlot)
	local Cooldown = Slot.Cooldown
	local Tween = CooldownTweens[Cooldown]
	if Tween then
		CooldownTweens[Cooldown] = nil
		Tween:Cancel()
	end

	Cooldown:SetAttribute("TweeningEndTickOf", nil)
	Cooldown:SetAttribute("EndTick", nil)
	Cooldown.Visible = false
	Cooldown.Size = UDim2.fromScale(1, 0)
end

function HotbarController:ClearHotbar()
	for _, Slot in Slots do
		for _, Connection in Slot.Connections do
			Connection:Disconnect()
		end
		table.clear(Slot.Connections)
		Slot.Tool = nil
		Slot.Character = nil
		ClearCooldown(Slot)

		Slot.Button:SetAttribute("ItemName", nil)
		Slot.Button.Visible = false
		Slot.ItemName.Text = ""
		Slot.Amount.Text = ""
		Slot.Amount.Visible = false
		Slot.Index.TextColor3 = Slot.IndexColor
		Slot.ItemName.TextColor3 = Slot.TextColor
		if Slot.Stroke and Slot.StrokeColor then
			Slot.Stroke.Color = Slot.StrokeColor
		end
	end
end

function HotbarController:QueueRefresh()
	if RefreshQueued then
		return
	end

	RefreshQueued = true
	task.defer(function()
		RefreshQueued = false
		self:LoadHotbar(self:HotbarEnabledBooleans())
	end)
end

function HotbarController:UpdateCooldown(Slot: HotbarSlot, Tool: Tool)
	local EndTick = if Character then Character:GetAttribute(Tool.Name .. "DebounceEndTick") else nil
	local Duration = if typeof(EndTick) == "number" then EndTick - workspace:GetServerTimeNow() else 0
	if Duration <= 0 then
		ClearCooldown(Slot)
		return
	end

	local Cooldown = Slot.Cooldown
	if
		CooldownTweens[Cooldown]
		and Cooldown:GetAttribute("EndTick") == EndTick
		and Cooldown:GetAttribute("TweeningEndTickOf") == Tool.Name
	then
		return
	end

	ClearCooldown(Slot)
	Cooldown.Visible = true
	Cooldown.Size = UDim2.fromScale(1, 1)
	Cooldown:SetAttribute("TweeningEndTickOf", Tool.Name)
	Cooldown:SetAttribute("EndTick", EndTick)

	local Tween = TweenService:Create(Cooldown, TweenInfo.new(Duration, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(1, 0),
	})
	CooldownTweens[Cooldown] = Tween
	Tween.Completed:Once(function(State: Enum.PlaybackState)
		if State == Enum.PlaybackState.Completed and CooldownTweens[Cooldown] == Tween then
			CooldownTweens[Cooldown] = nil
			Cooldown.Visible = false
			Cooldown:SetAttribute("TweeningEndTickOf", nil)
			Cooldown:SetAttribute("EndTick", nil)
		end
	end)
	Tween:Play()
end

function HotbarController:UpdateSlot(Index: number, Tool: Tool?)
	local Slot = Slots[Index]
	if Slot.Tool ~= Tool or Slot.Character ~= Character then
		for _, Connection in Slot.Connections do
			Connection:Disconnect()
		end
		table.clear(Slot.Connections)
		ClearCooldown(Slot)
		Slot.Tool = Tool
		Slot.Character = Character

		if Tool then
			for _, Attribute in { "Stack", "DisplayName" } do
				table.insert(
					Slot.Connections,
					Tool:GetAttributeChangedSignal(Attribute):Connect(function()
						self:UpdateSlot(Index, Tool)
					end)
				)
			end
			table.insert(
				Slot.Connections,
				Tool:GetAttributeChangedSignal("HotbarIndex"):Connect(function()
					self:QueueRefresh()
				end)
			)
			if Character then
				table.insert(
					Slot.Connections,
					Character:GetAttributeChangedSignal(Tool.Name .. "DebounceEndTick"):Connect(function()
						self:UpdateCooldown(Slot, Tool)
					end)
				)
			end
			self:UpdateCooldown(Slot, Tool)
		end
	end

	local Visible = Tool ~= nil or Ghosts
	local Name = if Tool then Tool:GetAttribute("DisplayName") or Tool.Name else ""
	local Amount = if Tool then Tool:GetAttribute("Stack") else nil
	local AmountVisible = typeof(Amount) == "number" and Amount > 1
	local AmountText = if AmountVisible then "x" .. tostring(Amount) else ""
	local Equipped = Tool ~= nil and Tool.Parent == Character
	local TextColor = if Equipped then EquippedTextColor else Slot.TextColor
	local IndexColor = if Equipped or SelectionHighlight then EquippedTextColor else Slot.IndexColor
	if Slot.Button.Visible ~= Visible then
		Slot.Button.Visible = Visible
	end
	if Slot.Button:GetAttribute("ItemName") ~= (Tool and Tool.Name) then
		Slot.Button:SetAttribute("ItemName", Tool and Tool.Name)
	end
	if Slot.ItemName.Text ~= Name then
		Slot.ItemName.Text = Name
	end
	if Slot.Amount.Visible ~= AmountVisible then
		Slot.Amount.Visible = AmountVisible
	end
	if Slot.Amount.Text ~= AmountText then
		Slot.Amount.Text = AmountText
	end
	if Slot.ItemName.TextColor3 ~= TextColor then
		Slot.ItemName.TextColor3 = TextColor
	end
	if Slot.Index.TextColor3 ~= IndexColor then
		Slot.Index.TextColor3 = IndexColor
	end
	if Slot.Stroke and Slot.StrokeColor then
		local Color = if Equipped then EquippedTextColor else Slot.StrokeColor
		if Slot.Stroke.Color ~= Color then
			InventoryDragController:SetSlotStrokeColor(Slot.Button, Color)
		end
	end
end

function HotbarController:LoadHotbar(ShowEmpty: boolean, Selected: boolean?)
	if not Background then
		return
	end

	Ghosts = ShowEmpty or InventoryController:IsOpen()
	SelectionHighlight = Selected == true
	local ByIndex: { [number]: Tool } = {}
	for _, Tool in Player.Backpack:GetChildren() do
		local Index = Tool:GetAttribute("HotbarIndex")
		if Tool:IsA("Tool") and InventoryHotbarSlots.IsValidIndex(Index) then
			ByIndex[Index] = Tool
		end
	end

	local EquippedTool = if Character then Character:FindFirstChildWhichIsA("Tool") else nil
	SelectedSlot = if EquippedTool then EquippedTool:GetAttribute("HotbarIndex") else nil
	if EquippedTool and InventoryHotbarSlots.IsValidIndex(SelectedSlot) then
		ByIndex[SelectedSlot] = EquippedTool
	end
	for Index in Slots do
		self:UpdateSlot(Index, ByIndex[Index])
	end

	self:UpdateVisibility()
	if InventoryDragController:IsDragging() then
		InventoryDragController:RefreshDropHighlights()
	end
end

function HotbarController:HandleEquip()
	if not Character then
		return
	end

	local Tool = HotbarController:GetToolInHotbarIndex(SelectedSlot)
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
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

function HotbarController:GetToolByNameFromPlayer(ToolName: string): Tool?
	for _, Tool: Tool in Player.Backpack:GetChildren() do
		if Tool:IsA("Tool") and Tool.Name == ToolName then
			return Tool
		end
	end

	local Tool = if Character then Character:FindFirstChildWhichIsA("Tool") else nil
	if Tool and Tool.Name == ToolName then
		return Tool
	end

	return nil
end

local Camera = workspace.CurrentCamera
local Mouse = Player:GetMouse()
local Items = require(ReplicatedStorage.Shared.Index.Items)
local Validate = require(ReplicatedStorage.Shared.Validate)

local Released = false
function HotbarController.OnKeyPress(value: number?, state: Enum.UserInputState)
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

		local Root = Character.PrimaryPart
		local LookAtMouse = if Root then Root:FindFirstChild("LookAtMouse") :: AlignOrientation? else nil
		local LockCharacterMouse = if Root then Root:FindFirstChild("LockCharacterMouse") :: AlignPosition? else nil

		if state == Enum.UserInputState.End then
			if LookAtMouse and LockCharacterMouse then
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

					if LookAtMouse and LockCharacterMouse then
						if not LookAtMouse.Enabled then
							LookAtMouse.Enabled = true
							LockCharacterMouse.Position = Character:GetPivot().Position
							LockCharacterMouse.Enabled = true
							local Acc = 0
							AnimationController:PlayAnimation(
								Character,
								ReplicatedStorage.Assets.Animations.Skills.Artifacts.ThunderHeart.ThunderWrathStart
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

	SelectedSlot = nil
	local BoundCharacter = Character
	local function RefreshTools(Child: Instance)
		if Child:IsA("Tool") then
			self:QueueRefresh()
		end
	end

	Character.ChildAdded:Connect(RefreshTools)
	Character.ChildRemoved:Connect(RefreshTools)

	Character:GetAttributeChangedSignal("Loaded"):Connect(function()
		if Character:GetAttribute("Loaded") then
			self:QueueRefresh()
		end
	end)

	local function ClearMouseLock()
		local Root = BoundCharacter.PrimaryPart
		local LookAtMouse = if Root then Root:FindFirstChild("LookAtMouse") :: AlignOrientation? else nil
		local LockCharacterMouse = if Root then Root:FindFirstChild("LockCharacterMouse") :: AlignPosition? else nil
		if LookAtMouse then
			LookAtMouse.Enabled = false
		end
		if LockCharacterMouse then
			LockCharacterMouse.Enabled = false
		end
	end

	Character:GetAttributeChangedSignal("UnlockMouse"):Connect(function()
		if not Character:GetAttribute("UnlockMouse") then
			return
		end
		ClearMouseLock()
	end)

	Character:GetAttributeChangedSignal("SkillState"):Connect(function()
		if not Character:GetAttribute("SkillState") then
			ClearMouseLock()
		end
	end)

	Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
		if not Character:GetAttribute("Ragdoll") then
			return
		end
		ClearMouseLock()
	end)
end

function HotbarController.KnitInit()
	InventoryService = Knit.GetService("InventoryService")
	InventoryController = Knit.GetController("InventoryController")
	MenuController = Knit.GetController("MenuController")
	SkillService = Knit.GetService("SkillService")
	SkillTreeController = Knit.GetController("SkillTreeController")
	AnimationController = Knit.GetController("AnimationController")
	InventoryDragController = Knit.GetController("InventoryDragController")
end

function HotbarController:BindButtons()
	local PressedSlot: number?
	local PressedInput: InputObject?

	for Index, Slot in Slots do
		Slot.Button.InputBegan:Connect(function(Input: InputObject)
			if
				Input.UserInputType ~= Enum.UserInputType.MouseButton1
				and Input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			local Tool = self:GetToolInHotbarIndex(Index)
			if InventoryController:IsOpen() then
				if Tool then
					InventoryDragController:BeginHotbarDrag(Slot.Button, Index, Tool, Input)
				end
				return
			end

			if
				not InventoryController:IsOpen()
				and not Ghosts
				and not self:IsSelectingSlot()
				and Tool
				and Tool:GetAttribute("Class") == "Skill"
			then
				PressedSlot = Index
				PressedInput = Input
				self.OnKeyPress(Index, Enum.UserInputState.Begin)
			end
		end)

		Slot.Button.Activated:Connect(function()
			if InventoryDragController:IsDragging() or InventoryDragController:ConsumesClick(Slot.Button) then
				return
			end

			if InventoryController:IsOpen() then
				if self:GetToolInHotbarIndex(Index) then
					InventoryService:RemoveItemFromHotbar(Index)
				end
				return
			end

			if self:IsSelectingSlot() then
				self:ConfirmSlotSelection(Index)
				return
			end

			local SelectedNode = SkillTreeController:GetSelected()
			local SkillTree = MenuController:GetMenu("SkillTree")

			if SelectedNode and SkillTree and SkillTree.Enabled then
				SelectedNode = SelectedNode:gsub(" ", "")
				InventoryService:EquipToHotbar(SelectedNode, Index)
				HotbarController:LoadHotbar(false, false)
			elseif not Ghosts then
				local Tool = self:GetToolInHotbarIndex(Index)
				if Tool and Tool:GetAttribute("Class") ~= "Skill" then
					self.OnKeyPress(Index, Enum.UserInputState.Begin)
				end
			elseif Slot.Button:GetAttribute("ItemName") then
				InventoryService:RemoveItemFromHotbar(Index)
			end
		end)
	end

	UserInputService.InputEnded:Connect(function(Input: InputObject)
		if PressedSlot ~= nil and (Input == PressedInput or Input.UserInputType == Enum.UserInputType.MouseButton1) then
			local Index = PressedSlot
			PressedSlot = nil
			PressedInput = nil
			self.OnKeyPress(Index, Enum.UserInputState.End)
		end
	end)
end

function HotbarController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	Hud = PlayerGui:WaitForChild("Hud") :: ScreenGui
	Hotbar = Hud:WaitForChild("NewHotbar") :: ScreenGui
	Background = Hotbar:WaitForChild("Background") :: Frame
	HotbarController:CreateSlots()
	HotbarController:UpdateVisibility()

	Player.Backpack.ChildAdded:Connect(function(Child: Instance)
		if Child:IsA("Tool") then
			HotbarController:QueueRefresh()
		end
	end)
	Player.Backpack.ChildRemoved:Connect(function(Child: Instance)
		if Child:IsA("Tool") then
			HotbarController:QueueRefresh()
		end
	end)

	Player.CharacterAdded:Connect(function(character: Model)
		HotbarController:CancelSlotSelection()
		HotbarController:ClearHotbar()
		Character = character

		HotbarController:BindCharacter()
		HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
	end)

	Character = Player.Character

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
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

	UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
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
		HotbarController:QueueRefresh()
	end)

	HotbarController:BindCharacter()
	HotbarController:BindButtons()
end

return HotbarController
