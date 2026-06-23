-- Samurai Rampage item preset authoring plugin.
-- The plugin deliberately mirrors the runtime contracts in EquipmentController
-- and WeaponService instead of inventing a second configuration format.

-- Keep the Workspace source safe if Play is pressed before it is installed.
-- Once saved as a local plugin, Studio provides the `plugin` global and the
-- toolbar/widget code below runs normally.
if not plugin then
	return
end

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local StarterPlayer = game:GetService("StarterPlayer")

local PLUGIN_ID = "SamuraiRampageItemConfiguratorV1"
local SESSION_NAME = "_SamuraiItemConfigurator"
local TOOLBAR_NAME = "Samurai Rampage"

local EQUIPMENT_SLOTS = {
	"Head",
	"Face",
	"Torso",
	"Legs",
	"Back",
	"Eyes",
	"Waist",
	"Prosthetic",
	"Artifact",
}

local BODY_PARTS = {
	"Head",
	"Torso",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
}

local DEFAULT_BODY_PART = {
	Head = "Head",
	Face = "Head",
	Torso = "Torso",
	Legs = "Left Leg",
	Back = "Torso",
	Eyes = "Head",
	Waist = "Torso",
	Prosthetic = "Left Arm",
	Artifact = "Torso",
}

local COLORS = {
	Background = Color3.fromRGB(22, 24, 29),
	Panel = Color3.fromRGB(31, 34, 41),
	PanelAlt = Color3.fromRGB(40, 44, 53),
	Text = Color3.fromRGB(235, 238, 245),
	Muted = Color3.fromRGB(158, 166, 181),
	Accent = Color3.fromRGB(210, 63, 55),
	AccentDark = Color3.fromRGB(139, 42, 38),
	Good = Color3.fromRGB(75, 170, 104),
	Warning = Color3.fromRGB(224, 168, 65),
	Border = Color3.fromRGB(62, 67, 78),
}

local mode = plugin:GetSetting("Mode") == "Weapon" and "Weapon" or "Equipable"
local equipmentSlot = plugin:GetSetting("EquipmentSlot") or "Head"
local targetBodyPart = plugin:GetSetting("TargetBodyPart") or DEFAULT_BODY_PART[equipmentSlot] or "Head"
local hideBodyPart = plugin:GetSetting("HideBodyPart") == true
local replaceExisting = plugin:GetSetting("ReplaceExisting") == true

local function trim(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function indexOf(list, value)
	for index, candidate in list do
		if candidate == value then
			return index
		end
	end
	return 1
end

local BODY_PART_ALIASES = {
	head = "Head",
	torso = "Torso",
	leftarm = "Left Arm",
	rightarm = "Right Arm",
	leftleg = "Left Leg",
	rightleg = "Right Leg",
}

local function canonicalBodyPartName(name)
	local normalized = string.lower(name):gsub("[%s_%-]", "")
	return BODY_PART_ALIASES[normalized]
end

local function isBodyPartName(name)
	return canonicalBodyPartName(name) ~= nil
end

local function getAssets()
	return ReplicatedStorage:FindFirstChild("Assets")
end

local function getRigTemplate()
	local starterCharacter = StarterPlayer:FindFirstChild("StarterCharacter")
	if starterCharacter and starterCharacter:IsA("Model") then
		return starterCharacter
	end

	local assets = getAssets()
	local rigs = assets and assets:FindFirstChild("Rigs")
	local rig = rigs and rigs:FindFirstChild("KatanaVisualizer")
	if rig and rig:IsA("Model") then
		return rig
	end
	return nil
end

local function findItemModule(itemName)
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local index = shared and shared:FindFirstChild("Index")
	local items = index and index:FindFirstChild("Items")
	if not items then
		return nil
	end

	local direct = items:FindFirstChild(itemName, true)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end

	return nil
end

local function getSession()
	return workspace:FindFirstChild(SESSION_NAME)
end

local function getSessionDummy()
	local session = getSession()
	local dummy = session and session:FindFirstChild("Dummy")
	if dummy and dummy:IsA("Model") then
		return dummy
	end
	return nil
end

local function beginChange(name, callback)
	local recording = ChangeHistoryService:TryBeginRecording(name, name)
	if not recording then
		return false, "Studio could not start an undo recording. Stop playtesting and try again."
	end

	local ok, result = pcall(callback)
	ChangeHistoryService:FinishRecording(
		recording,
		if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)

	if not ok then
		return false, tostring(result)
	end

	return true, result
end

local toolbar = plugin:CreateToolbar(TOOLBAR_NAME)
local toolbarButton = toolbar:CreateButton(
	"Item Configurator",
	"Position armor and weapons on a dummy, then save a game-ready preset",
	"",
	"Item Configurator"
)
toolbarButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false,
	false,
	410,
	650,
	340,
	440
)

local widget
local widgetOk, widgetResult = pcall(function()
	return plugin:CreateDockWidgetPluginGuiAsync(PLUGIN_ID, widgetInfo)
end)
if widgetOk then
	widget = widgetResult
else
	widget = plugin:CreateDockWidgetPluginGui(PLUGIN_ID, widgetInfo)
end

widget.Title = "Samurai Item Configurator"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundColor3 = COLORS.Background
root.BorderSizePixel = 0
root.Size = UDim2.fromScale(1, 1)
root.Parent = widget

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = root

local scroller = Instance.new("ScrollingFrame")
scroller.Name = "Content"
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.Size = UDim2.fromScale(1, 1)
scroller.ScrollBarThickness = 5
scroller.ScrollBarImageColor3 = COLORS.Accent
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.CanvasSize = UDim2.new()
scroller.Parent = root

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroller

local function rounded(guiObject, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 5)
	corner.Parent = guiObject
	return guiObject
end

local function stroke(guiObject)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = COLORS.Border
	uiStroke.Thickness = 1
	uiStroke.Parent = guiObject
	return guiObject
end

local function makeLabel(text, height, textSize, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height or 22)
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = color or COLORS.Text
	label.TextSize = textSize or 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Parent = scroller
	return label
end

local function makeButton(parent, text, height)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = COLORS.PanelAlt
	button.BorderSizePixel = 0
	button.Size = UDim2.new(1, 0, 0, height or 34)
	button.Font = Enum.Font.GothamMedium
	button.Text = text
	button.TextColor3 = COLORS.Text
	button.TextSize = 13
	button.Parent = parent
	rounded(button, 5)
	stroke(button)
	return button
end

local title = makeLabel("ITEM PRESET WORKBENCH", 26, 17)
title.Font = Enum.Font.GothamBold
title.TextColor3 = COLORS.Accent

local help = makeLabel(
	"Select an asset, generate a dummy, move the preview with Studio's Move/Rotate tools, then save the preset.",
	42,
	12,
	COLORS.Muted
)

local selectionLabel = makeLabel("Selection: nothing selected", 34, 12, COLORS.Muted)

local modeRow = Instance.new("Frame")
modeRow.Name = "ModeRow"
modeRow.BackgroundTransparency = 1
modeRow.Size = UDim2.new(1, 0, 0, 36)
modeRow.Parent = scroller

local modeLayout = Instance.new("UIListLayout")
modeLayout.FillDirection = Enum.FillDirection.Horizontal
modeLayout.Padding = UDim.new(0, 8)
modeLayout.Parent = modeRow

local equipableButton = makeButton(modeRow, "Equipable", 36)
equipableButton.Size = UDim2.new(0.5, -4, 1, 0)
local weaponButton = makeButton(modeRow, "Weapon", 36)
weaponButton.Size = UDim2.new(0.5, -4, 1, 0)

local itemNameBox = Instance.new("TextBox")
itemNameBox.Name = "ItemName"
itemNameBox.BackgroundColor3 = COLORS.Panel
itemNameBox.BorderSizePixel = 0
itemNameBox.Size = UDim2.new(1, 0, 0, 38)
itemNameBox.ClearTextOnFocus = false
itemNameBox.Font = Enum.Font.Gotham
itemNameBox.PlaceholderColor3 = COLORS.Muted
itemNameBox.PlaceholderText = "Exact preset name, e.g. SamuraiHelmet or Origin"
itemNameBox.Text = plugin:GetSetting("ItemName") or ""
itemNameBox.TextColor3 = COLORS.Text
itemNameBox.TextSize = 13
itemNameBox.TextXAlignment = Enum.TextXAlignment.Left
itemNameBox.Parent = scroller
rounded(itemNameBox, 5)
stroke(itemNameBox)

local namePadding = Instance.new("UIPadding")
namePadding.PaddingLeft = UDim.new(0, 10)
namePadding.PaddingRight = UDim.new(0, 10)
namePadding.Parent = itemNameBox

local equipmentControls = Instance.new("Frame")
equipmentControls.Name = "EquipmentControls"
equipmentControls.BackgroundTransparency = 1
equipmentControls.AutomaticSize = Enum.AutomaticSize.Y
equipmentControls.Size = UDim2.new(1, 0, 0, 0)
equipmentControls.Parent = scroller

local equipmentLayout = Instance.new("UIListLayout")
equipmentLayout.Padding = UDim.new(0, 8)
equipmentLayout.Parent = equipmentControls

local slotButton = makeButton(equipmentControls, "", 34)
local targetButton = makeButton(equipmentControls, "", 34)
local hideButton = makeButton(equipmentControls, "", 34)

local replaceButton = makeButton(scroller, "", 34)

local actions = Instance.new("Frame")
actions.Name = "Actions"
actions.BackgroundTransparency = 1
actions.AutomaticSize = Enum.AutomaticSize.Y
actions.Size = UDim2.new(1, 0, 0, 0)
actions.Parent = scroller

local actionLayout = Instance.new("UIListLayout")
actionLayout.Padding = UDim.new(0, 7)
actionLayout.Parent = actions

local generateButton = makeButton(actions, "Generate / Refresh Preview", 38)
generateButton.BackgroundColor3 = COLORS.Accent
local validateButton = makeButton(actions, "Validate Current Setup", 34)
local saveButton = makeButton(actions, "Save Preset to ReplicatedStorage.Assets", 38)
saveButton.BackgroundColor3 = COLORS.Good
local removeButton = makeButton(actions, "Remove Preview", 32)

local statusTitle = makeLabel("VALIDATION", 22, 12, COLORS.Muted)
statusTitle.Font = Enum.Font.GothamBold

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundColor3 = COLORS.Panel
status.BorderSizePixel = 0
status.AutomaticSize = Enum.AutomaticSize.Y
status.Size = UDim2.new(1, 0, 0, 110)
status.Font = Enum.Font.Code
status.Text = "Ready. Select an item asset to begin."
status.TextColor3 = COLORS.Text
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Parent = scroller
rounded(status, 5)
stroke(status)

local statusPadding = Instance.new("UIPadding")
statusPadding.PaddingTop = UDim.new(0, 9)
statusPadding.PaddingBottom = UDim.new(0, 9)
statusPadding.PaddingLeft = UDim.new(0, 9)
statusPadding.PaddingRight = UDim.new(0, 9)
statusPadding.Parent = status

local function showMessages(messages)
	status.Text = table.concat(messages, "\n")
	for _, message in messages do
		if string.sub(message, 1, 3) == "[X]" then
			status.TextColor3 = Color3.fromRGB(242, 112, 106)
			return
		end
	end
	for _, message in messages do
		if string.sub(message, 1, 3) == "[!]" then
			status.TextColor3 = COLORS.Warning
			return
		end
	end
	status.TextColor3 = COLORS.Text
end

local function showError(message)
	showMessages({ "[X] " .. tostring(message) })
	warn("Samurai Item Configurator: " .. tostring(message))
end

local function updateControls()
	equipableButton.BackgroundColor3 = if mode == "Equipable" then COLORS.Accent else COLORS.PanelAlt
	weaponButton.BackgroundColor3 = if mode == "Weapon" then COLORS.Accent else COLORS.PanelAlt
	equipmentControls.Visible = mode == "Equipable"
	slotButton.Text = "Equipment slot:  " .. equipmentSlot .. "   (click to cycle)"
	targetButton.Text = "Default body part:  " .. targetBodyPart .. "   (click to cycle)"
	hideButton.Text = (if hideBodyPart then "[x]" else "[ ]") .. " Hide underlying body part"
	replaceButton.Text = (if replaceExisting then "[x]" else "[ ]") .. " Replace an existing preset with the same name"

	plugin:SetSetting("Mode", mode)
	plugin:SetSetting("EquipmentSlot", equipmentSlot)
	plugin:SetSetting("TargetBodyPart", targetBodyPart)
	plugin:SetSetting("HideBodyPart", hideBodyPart)
	plugin:SetSetting("ReplaceExisting", replaceExisting)
end

local function selectedTopLevelInstances()
	local selected = Selection:Get()
	local session = getSession()
	local selectedSet = {}
	for _, instance in selected do
		selectedSet[instance] = true
	end

	local filtered = {}
	for _, instance in selected do
		if not session or not instance:IsDescendantOf(session) then
			local ancestor = instance.Parent
			local hasSelectedAncestor = false
			while ancestor do
				if selectedSet[ancestor] then
					hasSelectedAncestor = true
					break
				end
				ancestor = ancestor.Parent
			end
			if not hasSelectedAncestor then
				table.insert(filtered, instance)
			end
		end
	end

	return filtered
end

local function guessNameFromSelection()
	local selected = selectedTopLevelInstances()
	if #selected ~= 1 then
		return nil
	end

	local source = selected[1]
	if mode == "Weapon" and (source.Name == "Weapon" or source.Name == "Sheath") and source.Parent then
		return source.Parent.Name
	end

	return source.Name
end

local function updateSelectionLabel()
	local selected = Selection:Get()
	if #selected == 0 then
		selectionLabel.Text = "Selection: nothing selected"
	elseif #selected == 1 then
		selectionLabel.Text = "Selection: " .. selected[1]:GetFullName()
	else
		selectionLabel.Text = string.format("Selection: %d instances", #selected)
	end

	if not itemNameBox:IsFocused() and trim(itemNameBox.Text) == "" then
		local guessed = guessNameFromSelection()
		if guessed and guessed ~= SESSION_NAME then
			itemNameBox.Text = guessed
		end
	end
end

local function cameraPlacement()
	local camera = workspace.CurrentCamera
	if not camera then
		return CFrame.new(0, 3, 0)
	end

	local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	else
		look = look.Unit
	end

	local position = camera.CFrame.Position + look * 12
	position = Vector3.new(position.X, camera.Focus.Position.Y, position.Z)
	return CFrame.lookAt(position, position + look)
end

local function createDummy(session)
	local template = getRigTemplate()
	if not template then
		error("Missing StarterPlayer.StarterCharacter and the fallback KatanaVisualizer rig.")
	end

	local dummy = template:Clone()
	dummy.Name = "Dummy"

	local assets = dummy:FindFirstChild("Assets")
	if assets then
		assets:ClearAllChildren()
	end

	for _, descendant in dummy:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.Locked = true
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end

	dummy.Parent = session
	dummy:PivotTo(cameraPlacement())
	return dummy
end

local function cloneSelectionAsModel(selected)
	local preview = Instance.new("Model")
	preview.Name = "Item"

	if #selected == 1 and selected[1]:IsA("Model") then
		local clone = selected[1]:Clone()
		if not clone then
			error("The selected model is not Archivable and cannot be cloned.")
		end
		preview:Destroy()
		clone.Name = "Item"
		return clone
	end

	for _, source in selected do
		if source:IsA("BasePart") or source:IsA("Model") or source:IsA("Folder") then
			local clone = source:Clone()
			if clone then
				clone.Parent = preview
			end
		end
	end

	return preview
end

local function setPreviewPartProperties(rootInstance)
	for _, descendant in rootInstance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.Locked = false
		end
	end
	if rootInstance:IsA("BasePart") then
		rootInstance.Anchored = true
		rootInstance.CanCollide = false
		rootInstance.Locked = false
	end
end

local function getStructuredGroups(preview)
	local groups = {}
	for _, child in preview:GetChildren() do
		if isBodyPartName(child.Name) and (child:IsA("Model") or child:IsA("BasePart")) then
			table.insert(groups, child)
		end
	end
	return groups
end

local function movePreviewInstanceTo(instance, targetCFrame)
	if instance:IsA("Model") then
		instance:PivotTo(targetCFrame)
		return
	end

	-- Existing one-piece presets use an invisible BasePart as the group root,
	-- with visible MeshParts parented beneath it. Move the whole hierarchy;
	-- BasePart:PivotTo() alone would leave those descendants behind in Edit mode.
	local delta = targetCFrame * instance:GetPivot():Inverse()
	instance.CFrame = delta * instance.CFrame
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame = delta * descendant.CFrame
		end
	end
end

local function generateEquipablePreview(session, dummy, selected)
	if #selected == 0 then
		error("Select the raw equipable Model, Folder, or BaseParts first.")
	end

	local previewFolder = Instance.new("Folder")
	previewFolder.Name = "Preview"
	previewFolder.Parent = session

	local preview = cloneSelectionAsModel(selected)
	preview.Name = "Equipable"
	preview.Parent = previewFolder
	setPreviewPartProperties(preview)

	local groups = getStructuredGroups(preview)
	if #groups > 0 then
		for _, group in groups do
			local canonicalName = canonicalBodyPartName(group.Name)
			local bodyPart = canonicalName and dummy:FindFirstChild(canonicalName)
			if bodyPart and bodyPart:IsA("BasePart") then
				movePreviewInstanceTo(group, bodyPart:GetPivot())
			end
		end
	else
		local bodyPart = dummy:FindFirstChild(targetBodyPart)
		if not bodyPart or not bodyPart:IsA("BasePart") then
			error("The dummy is missing target body part " .. targetBodyPart .. ".")
		end
		preview:PivotTo(bodyPart:GetPivot())
	end

	Selection:Set({ preview })
	return preview, #groups
end

local function findWeaponSources(source)
	local weapon
	local sheath

	local childWeapon = source:FindFirstChild("Weapon")
	if childWeapon and childWeapon:IsA("Model") then
		weapon = childWeapon
		local childSheath = source:FindFirstChild("Sheath")
		if childSheath and childSheath:IsA("Model") then
			sheath = childSheath
		end
	elseif source:IsA("Model") then
		weapon = source
		if source.Name == "Weapon" and source.Parent then
			local sibling = source.Parent:FindFirstChild("Sheath")
			if sibling and sibling:IsA("Model") then
				sheath = sibling
			end
		end
	end

	return weapon, sheath
end

local function getHandle(model)
	local handle = model:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	return nil
end

local function findWeld(model, name)
	local weld = model:FindFirstChild(name)
	if weld and weld:IsA("Weld") then
		return weld
	end
	return nil
end

local function moveHandleTo(model, targetCFrame)
	local handle = getHandle(model)
	if not handle then
		error(model.Name .. " needs a direct BasePart named Handle (or at minimum a PrimaryPart).")
	end
	if not model.PrimaryPart then
		model.PrimaryPart = handle
	end
	local delta = targetCFrame * handle.CFrame:Inverse()
	model:PivotTo(delta * model:GetPivot())
end

local function addPreviewLabel(model, text, color)
	local handle = getHandle(model)
	if not handle then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ConfiguratorAdornment"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(170, 30)
	billboard.StudsOffset = Vector3.new(0, 1.4, 0)
	billboard.Adornee = handle
	billboard.Parent = model

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextSize = 13
	label.Parent = billboard
	rounded(label, 5)
end

local function weldTargetCFrame(part0, weld, fallback)
	if weld then
		return part0.CFrame * weld.C0 * weld.C1:Inverse()
	end
	return part0.CFrame * fallback
end

local DEFAULT_HELD = CFrame.Angles(0, math.rad(90), math.rad(90))
local DEFAULT_SHEATHED = CFrame.new(-1, -0.4, -1.5) * CFrame.Angles(0, math.rad(90), math.rad(100))
local DEFAULT_SHEATH = CFrame.new(0, -0.435, 1.75) * CFrame.Angles(0, math.rad(90), math.rad(100))
local DEFAULT_LEFT_SHEATHED = CFrame.new(-1, 0.025, -1.4) * CFrame.Angles(0, math.rad(90), math.rad(110))
local DEFAULT_LEFT_SHEATH = CFrame.new(0, -0.55, 1.65) * CFrame.Angles(0, math.rad(90), math.rad(110))

local function generateWeaponPreview(session, dummy, selected)
	if #selected ~= 1 then
		error("Select exactly one weapon preset Folder or Weapon Model.")
	end

	local sourceWeapon, sourceSheath = findWeaponSources(selected[1])
	if not sourceWeapon then
		error("Could not find a Weapon Model. Select a folder containing Weapon, or select the Weapon model itself.")
	end

	local rightHand = dummy:FindFirstChild("RightHand") or dummy:FindFirstChild("Right Arm")
	local leftHand = dummy:FindFirstChild("LeftHand") or dummy:FindFirstChild("Left Arm")
	local torso = dummy:FindFirstChild("Torso")
	local sheathPart = dummy:FindFirstChild("SheathPart")
	local sheathPart2 = dummy:FindFirstChild("SheathPart2")
	if not rightHand or not leftHand or not torso or not sheathPart or not sheathPart2 then
		error("The reference character must contain both hands, Torso, SheathPart, and SheathPart2.")
	end

	local previewFolder = Instance.new("Folder")
	previewFolder.Name = "Preview"
	previewFolder.Parent = session

	local held = sourceWeapon:Clone()
	held.Name = "HeldWeapon"
	held.Parent = previewFolder
	setPreviewPartProperties(held)

	local sheathed = sourceWeapon:Clone()
	sheathed.Name = "SheathedWeapon"
	sheathed.Parent = previewFolder
	setPreviewPartProperties(sheathed)

	local leftHeld = sourceWeapon:Clone()
	leftHeld.Name = "LeftHeldWeapon"
	leftHeld.Parent = previewFolder
	setPreviewPartProperties(leftHeld)

	local leftSheathed = sourceWeapon:Clone()
	leftSheathed.Name = "LeftSheathedWeapon"
	leftSheathed.Parent = previewFolder
	setPreviewPartProperties(leftSheathed)

	local handWeld = findWeld(sourceWeapon, "HandWeld")
	local leftHandWeld = findWeld(sourceWeapon, "LeftHandWeld") or handWeld
	local sheathWeld = findWeld(sourceWeapon, "SheathWeld")
	local sheath2Weld = findWeld(sourceWeapon, "Sheath2Weld")
	moveHandleTo(held, weldTargetCFrame(rightHand, handWeld, DEFAULT_HELD))
	moveHandleTo(sheathed, weldTargetCFrame(torso, sheathWeld, DEFAULT_SHEATHED))
	moveHandleTo(leftHeld, weldTargetCFrame(leftHand, leftHandWeld, DEFAULT_HELD))
	moveHandleTo(leftSheathed, weldTargetCFrame(torso, sheath2Weld, DEFAULT_LEFT_SHEATHED))
	addPreviewLabel(held, "RIGHT: HELD", Color3.fromRGB(102, 225, 135))
	addPreviewLabel(sheathed, "RIGHT: SHEATHED", Color3.fromRGB(255, 183, 77))
	addPreviewLabel(leftHeld, "LEFT: HELD", Color3.fromRGB(123, 235, 190))
	addPreviewLabel(leftSheathed, "LEFT: SHEATHED", Color3.fromRGB(255, 132, 102))

	local sheathPreview
	local leftSheathPreview
	if sourceSheath then
		sheathPreview = sourceSheath:Clone()
		sheathPreview.Name = "Sheath"
		sheathPreview.Parent = previewFolder
		setPreviewPartProperties(sheathPreview)
		local sourceSheathWeld = findWeld(sourceSheath, "SheathWeld")
		moveHandleTo(sheathPreview, weldTargetCFrame(sheathPart, sourceSheathWeld, DEFAULT_SHEATH))
		addPreviewLabel(sheathPreview, "RIGHT: SHEATH", Color3.fromRGB(112, 183, 255))

		leftSheathPreview = sourceSheath:Clone()
		leftSheathPreview.Name = "LeftSheath"
		leftSheathPreview.Parent = previewFolder
		setPreviewPartProperties(leftSheathPreview)
		local sourceSheath2Weld = findWeld(sourceSheath, "Sheath2Weld")
		moveHandleTo(leftSheathPreview, weldTargetCFrame(sheathPart2, sourceSheath2Weld, DEFAULT_LEFT_SHEATH))
		addPreviewLabel(leftSheathPreview, "LEFT: SHEATH", Color3.fromRGB(155, 139, 255))
	end

	Selection:Set(
		if sheathPreview and leftSheathPreview
			then { held, leftHeld, sheathed, leftSheathed, sheathPreview, leftSheathPreview }
			else { held, leftHeld, sheathed, leftSheathed }
	)
	return held, leftHeld, sheathed, leftSheathed, sheathPreview, leftSheathPreview
end

local function getValidItemName()
	local itemName = trim(itemNameBox.Text)
	if itemName == "" then
		return nil, "Enter the exact item preset name."
	end
	if string.find(itemName, "[%c/\\]") then
		return nil, "The item name cannot contain slashes or control characters."
	end
	return itemName
end

local function cleanConfiguratorObjects(rootInstance)
	for _, descendant in rootInstance:GetDescendants() do
		if descendant.Name == "ConfiguratorAdornment" then
			descendant:Destroy()
		end
	end
end

local function hasBasePart(rootInstance)
	if rootInstance:IsA("BasePart") then
		return true
	end
	return rootInstance:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function jointsConnect(part0, part1, rootInstance)
	for _, descendant in rootInstance:GetDescendants() do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			if
				(descendant.Part0 == part0 and descendant.Part1 == part1)
				or (descendant.Part0 == part1 and descendant.Part1 == part0)
			then
				return true
			end
		end
	end
	return false
end

local function ensureRigidModel(model, handle, hideHandle)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
			descendant.Locked = false
		end
	end

	if hideHandle then
		handle.Transparency = 1
		handle.CastShadow = false
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= handle and not jointsConnect(handle, descendant, model) then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "ConfiguratorWeld"
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = handle
		end
	end

	model.PrimaryPart = handle
end

local function cloneContents(source, target)
	if source:IsA("BasePart") then
		local clone = source:Clone()
		clone.Parent = target
		return
	end

	for _, child in source:GetChildren() do
		local clone = child:Clone()
		if clone then
			clone.Parent = target
		end
	end
end

local function createEquipmentGroup(source, bodyPart, hidePart)
	local group = Instance.new("Model")
	group.Name = bodyPart.Name
	group:SetAttribute("HidePart0", hidePart)

	cloneContents(source, group)
	cleanConfiguratorObjects(group)

	-- When a preset created by this plugin is edited again, discard its old
	-- invisible pivot. A fresh pivot is captured from the current dummy pose.
	local oldHandle = group:FindFirstChild("Handle")
	if
		oldHandle
		and oldHandle:IsA("BasePart")
		and oldHandle.Transparency >= 0.99
		and oldHandle:FindFirstChild("ConfiguratorWeld")
	then
		oldHandle:Destroy()
	end

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.CFrame = bodyPart.CFrame
	handle.Color = Color3.fromRGB(255, 0, 255)
	handle.Material = Enum.Material.SmoothPlastic
	handle.Parent = group

	ensureRigidModel(group, handle, true)
	return group
end

local function removePresetWelds(model)
	for _, name in { "HandWeld", "LeftHandWeld", "SheathWeld", "Sheath2Weld" } do
		local existing = model:FindFirstChild(name)
		if existing and existing:IsA("Weld") then
			existing:Destroy()
		end
	end
end

local function createPresetWeld(name, c0, handle)
	local weld = Instance.new("Weld")
	weld.Name = name
	weld.C0 = c0
	weld.C1 = CFrame.new()
	weld.Part1 = handle
	return weld
end

local function getOrCreateFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("Folder") then
			error(existing:GetFullName() .. " exists but is not a Folder.")
		end
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function saveEquipable(itemName)
	local session = getSession()
	local dummy = getSessionDummy()
	local previewFolder = session and session:FindFirstChild("Preview")
	local preview = previewFolder and previewFolder:FindFirstChild("Equipable")
	if not session or not dummy or not preview then
		error("Generate an equipable preview first.")
	end

	local assets = getAssets()
	if not assets then
		error("Missing ReplicatedStorage.Assets.")
	end
	local equipables = getOrCreateFolder(assets, "Equipables")
	local slotFolder = getOrCreateFolder(equipables, equipmentSlot)
	local existing = slotFolder:FindFirstChild(itemName)
	if existing and not replaceExisting then
		error("A preset named " .. itemName .. " already exists. Enable Replace Existing if this is intentional.")
	end

	local output = Instance.new("Model")
	output.Name = itemName

	local groups = getStructuredGroups(preview)
	if #groups > 0 then
		for _, sourceGroup in groups do
			local canonicalName = canonicalBodyPartName(sourceGroup.Name)
			local bodyPart = canonicalName and dummy:FindFirstChild(canonicalName)
			if bodyPart and bodyPart:IsA("BasePart") then
				local configured = createEquipmentGroup(sourceGroup, bodyPart, hideBodyPart)
				configured.Parent = output
			end
		end
	else
		local bodyPart = dummy:FindFirstChild(targetBodyPart)
		if not bodyPart or not bodyPart:IsA("BasePart") then
			error("Dummy body part " .. targetBodyPart .. " is missing.")
		end
		local configured = createEquipmentGroup(preview, bodyPart, hideBodyPart)
		configured.Parent = output
	end

	if #output:GetChildren() == 0 then
		output:Destroy()
		error("No valid body-part groups were found to save.")
	end

	if existing then
		existing:Destroy()
	end
	output.Parent = slotFolder
	Selection:Set({ output })
	return output
end

local function cloneWeaponForOutput(previewModel, outputName)
	local output = previewModel:Clone()
	output.Name = outputName
	cleanConfiguratorObjects(output)
	removePresetWelds(output)
	local handle = getHandle(output)
	if not handle then
		output:Destroy()
		error(outputName .. " is missing a Handle.")
	end
	ensureRigidModel(output, handle, false)
	return output, handle
end

local function saveWeapon(itemName)
	local session = getSession()
	local dummy = getSessionDummy()
	local previewFolder = session and session:FindFirstChild("Preview")
	local held = previewFolder and previewFolder:FindFirstChild("HeldWeapon")
	local leftHeld = previewFolder and previewFolder:FindFirstChild("LeftHeldWeapon")
	local sheathed = previewFolder and previewFolder:FindFirstChild("SheathedWeapon")
	local leftSheathed = previewFolder and previewFolder:FindFirstChild("LeftSheathedWeapon")
	local sheathPreview = previewFolder and previewFolder:FindFirstChild("Sheath")
	local leftSheathPreview = previewFolder and previewFolder:FindFirstChild("LeftSheath")
	if not session or not dummy or not held or not leftHeld or not sheathed or not leftSheathed then
		error("Generate a weapon preview first.")
	end

	local rightHand = dummy:FindFirstChild("RightHand") or dummy:FindFirstChild("Right Arm")
	local leftHand = dummy:FindFirstChild("LeftHand") or dummy:FindFirstChild("Left Arm")
	local torso = dummy:FindFirstChild("Torso")
	local sheathPart = dummy:FindFirstChild("SheathPart")
	local sheathPart2 = dummy:FindFirstChild("SheathPart2")
	if not rightHand or not leftHand or not torso or not sheathPart or not sheathPart2 then
		error("The preview dummy is missing its weapon reference parts.")
	end

	local assets = getAssets()
	if not assets then
		error("Missing ReplicatedStorage.Assets.")
	end
	local weapons = getOrCreateFolder(assets, "Weapons")
	local existing = weapons:FindFirstChild(itemName)
	if existing and not replaceExisting then
		error("A weapon preset named " .. itemName .. " already exists. Enable Replace Existing if intentional.")
	end

	local outputFolder = Instance.new("Folder")
	outputFolder.Name = itemName

	local weapon, weaponHandle = cloneWeaponForOutput(held, "Weapon")
	local heldHandle = getHandle(held)
	local leftHeldHandle = getHandle(leftHeld)
	local sheathedHandle = getHandle(sheathed)
	local leftSheathedHandle = getHandle(leftSheathed)
	if not heldHandle or not leftHeldHandle or not sheathedHandle or not leftSheathedHandle then
		weapon:Destroy()
		outputFolder:Destroy()
		error("All right- and left-hand weapon previews need a Handle.")
	end

	local handC0 = rightHand.CFrame:ToObjectSpace(heldHandle.CFrame)
	local leftHandC0 = leftHand.CFrame:ToObjectSpace(leftHeldHandle.CFrame)
	local sheathedC0 = torso.CFrame:ToObjectSpace(sheathedHandle.CFrame)
	local leftSheathedC0 = torso.CFrame:ToObjectSpace(leftSheathedHandle.CFrame)
	local handWeld = createPresetWeld("HandWeld", handC0, weaponHandle)
	handWeld.Parent = weapon
	local leftHandWeld = createPresetWeld("LeftHandWeld", leftHandC0, weaponHandle)
	leftHandWeld.Parent = weapon
	local sheathWeld = createPresetWeld("SheathWeld", sheathedC0, weaponHandle)
	sheathWeld.Parent = weapon
	local sheath2Weld = createPresetWeld("Sheath2Weld", leftSheathedC0, weaponHandle)
	sheath2Weld.Parent = weapon
	weapon.Parent = outputFolder

	if sheathPreview then
		if not leftSheathPreview then
			outputFolder:Destroy()
			error("The left sheath preview is missing; regenerate the weapon preview.")
		end
		local sheath, sheathHandle = cloneWeaponForOutput(sheathPreview, "Sheath")
		local previewHandle = getHandle(sheathPreview)
		local leftPreviewHandle = getHandle(leftSheathPreview)
		if not previewHandle or not leftPreviewHandle then
			sheath:Destroy()
			outputFolder:Destroy()
			error("Both sheath previews need a Handle.")
		end
		local sheathC0 = sheathPart.CFrame:ToObjectSpace(previewHandle.CFrame)
		local weld = createPresetWeld("SheathWeld", sheathC0, sheathHandle)
		weld.Parent = sheath
		local leftSheathC0 = sheathPart2.CFrame:ToObjectSpace(leftPreviewHandle.CFrame)
		local leftWeld = createPresetWeld("Sheath2Weld", leftSheathC0, sheathHandle)
		leftWeld.Parent = sheath
		sheath.Parent = outputFolder
	end

	if existing then
		existing:Destroy()
	end
	outputFolder.Parent = weapons
	Selection:Set({ outputFolder })
	return outputFolder
end

local function validateSession()
	local messages = {}
	local itemName, nameError = getValidItemName()
	if not itemName then
		table.insert(messages, "[X] " .. nameError)
	else
		table.insert(messages, "[OK] Preset name: " .. itemName)
		if findItemModule(itemName) then
			table.insert(messages, "[OK] Matching item-data ModuleScript found")
		else
			table.insert(messages, "[!] No matching item-data ModuleScript named " .. itemName)
		end
	end

	local session = getSession()
	local dummy = getSessionDummy()
	if not session or not dummy then
		table.insert(messages, "[X] Generate a preview first")
		return messages
	end

	if session:GetAttribute("Mode") ~= mode then
		table.insert(messages, "[X] Preview type differs from the selected mode; regenerate it")
		return messages
	end

	local previewFolder = session:FindFirstChild("Preview")
	if mode == "Equipable" then
		local preview = previewFolder and previewFolder:FindFirstChild("Equipable")
		if not preview or not hasBasePart(preview) then
			table.insert(messages, "[X] Equipable preview contains no BaseParts")
			return messages
		end

		local groups = getStructuredGroups(preview)
		if #groups == 0 then
			table.insert(messages, "[OK] One-piece item will bind to " .. targetBodyPart)
		else
			table.insert(messages, string.format("[OK] %d named body-part group(s) found", #groups))
			for _, group in groups do
				if not hasBasePart(group) then
					table.insert(messages, "[X] " .. group.Name .. " contains no BaseParts")
				end
			end
		end

		local assets = getAssets()
		local equipables = assets and assets:FindFirstChild("Equipables")
		local slotFolder = equipables and equipables:FindFirstChild(equipmentSlot)
		if itemName and slotFolder and slotFolder:FindFirstChild(itemName) then
			table.insert(messages, if replaceExisting then "[!] Existing preset will be replaced" else "[X] Preset already exists")
		end
	else
		local held = previewFolder and previewFolder:FindFirstChild("HeldWeapon")
		local leftHeld = previewFolder and previewFolder:FindFirstChild("LeftHeldWeapon")
		local sheathed = previewFolder and previewFolder:FindFirstChild("SheathedWeapon")
		local leftSheathed = previewFolder and previewFolder:FindFirstChild("LeftSheathedWeapon")
		local sheath = previewFolder and previewFolder:FindFirstChild("Sheath")
		local leftSheath = previewFolder and previewFolder:FindFirstChild("LeftSheath")
		if not held or not leftHeld or not sheathed or not leftSheathed then
			table.insert(messages, "[X] Right and left held/sheathed previews are required")
			return messages
		end
		if getHandle(held) and getHandle(leftHeld) and getHandle(sheathed) and getHandle(leftSheathed) then
			table.insert(messages, "[OK] All dual-wield weapon Handles found")
		else
			table.insert(messages, "[X] Every weapon preview needs a direct BasePart named Handle")
		end
		if held:FindFirstChild("Parts") then
			table.insert(messages, "[OK] Weapon Parts container found")
		else
			table.insert(messages, "[!] Weapon has no Parts container (allowed, but unlike current presets)")
		end
		if held:FindFirstChild("Blade", true) then
			table.insert(messages, "[OK] Blade found")
		else
			table.insert(messages, "[!] No BasePart named Blade; sword trails may be unavailable")
		end
		if getHandle(held) and getHandle(held):FindFirstChild("DmgPoint") then
			table.insert(messages, "[OK] DmgPoint attachment(s) found")
		else
			table.insert(messages, "[!] Handle has no DmgPoint attachments")
		end
		if sheath then
			if leftSheath and getHandle(sheath) and getHandle(leftSheath) then
				table.insert(messages, "[OK] Both dual-wield sheath Handles found")
			else
				table.insert(messages, "[X] Both right and left sheath previews need a Handle")
			end
		else
			table.insert(messages, "[!] No sheath selected; a weapon-only preset will be saved")
		end
		table.insert(messages, "[OK] Dedicated left-hand and second-sheath offsets will be saved")

		local assets = getAssets()
		local weapons = assets and assets:FindFirstChild("Weapons")
		if itemName and weapons and weapons:FindFirstChild(itemName) then
			table.insert(messages, if replaceExisting then "[!] Existing preset will be replaced" else "[X] Preset already exists")
		end
	end

	return messages
end

local function generatePreview()
	local itemName, nameError = getValidItemName()
	if not itemName then
		showError(nameError)
		return
	end

	local selected = selectedTopLevelInstances()
	if #selected == 0 then
		showError("Select the source asset in Explorer before generating the preview.")
		return
	end

	local ok, result = beginChange("Generate item configurator preview", function()
		local oldSession = getSession()
		if oldSession then
			oldSession:Destroy()
		end

		local session = Instance.new("Model")
		session.Name = SESSION_NAME
		session:SetAttribute("Mode", mode)
		session:SetAttribute("ItemName", itemName)
		session:SetAttribute("EquipmentSlot", equipmentSlot)
		session.Parent = workspace

		local dummy = createDummy(session)
		if mode == "Equipable" then
			generateEquipablePreview(session, dummy, selected)
		else
			generateWeaponPreview(session, dummy, selected)
		end
		return session
	end)

	if not ok then
		showError(result)
		return
	end

	plugin:SetSetting("ItemName", itemName)
	showMessages(validateSession())
end

local function savePreset()
	local itemName, nameError = getValidItemName()
	if not itemName then
		showError(nameError)
		return
	end

	local validation = validateSession()
	for _, message in validation do
		if string.sub(message, 1, 3) == "[X]" then
			showMessages(validation)
			return
		end
	end

	local ok, result = beginChange("Save " .. mode .. " preset " .. itemName, function()
		if mode == "Equipable" then
			return saveEquipable(itemName)
		end
		return saveWeapon(itemName)
	end)

	if not ok then
		showError(result)
		return
	end

	showMessages({
		"[OK] Saved " .. result:GetFullName(),
		"[OK] Parts were unanchored, made massless, and welded automatically",
		"[OK] Use Ctrl+Z to undo this save",
	})
end

local function removePreview()
	local session = getSession()
	if not session then
		showMessages({ "[OK] There is no preview to remove" })
		return
	end

	local ok, result = beginChange("Remove item configurator preview", function()
		session:Destroy()
	end)
	if not ok then
		showError(result)
		return
	end
	showMessages({ "[OK] Preview removed" })
end

equipableButton.MouseButton1Click:Connect(function()
	mode = "Equipable"
	updateControls()
end)

weaponButton.MouseButton1Click:Connect(function()
	mode = "Weapon"
	updateControls()
end)

slotButton.MouseButton1Click:Connect(function()
	local nextIndex = (indexOf(EQUIPMENT_SLOTS, equipmentSlot) % #EQUIPMENT_SLOTS) + 1
	equipmentSlot = EQUIPMENT_SLOTS[nextIndex]
	targetBodyPart = DEFAULT_BODY_PART[equipmentSlot] or targetBodyPart
	updateControls()
end)

targetButton.MouseButton1Click:Connect(function()
	local nextIndex = (indexOf(BODY_PARTS, targetBodyPart) % #BODY_PARTS) + 1
	targetBodyPart = BODY_PARTS[nextIndex]
	updateControls()
end)

hideButton.MouseButton1Click:Connect(function()
	hideBodyPart = not hideBodyPart
	updateControls()
end)

replaceButton.MouseButton1Click:Connect(function()
	replaceExisting = not replaceExisting
	updateControls()
end)

itemNameBox.FocusLost:Connect(function()
	plugin:SetSetting("ItemName", trim(itemNameBox.Text))
end)

generateButton.MouseButton1Click:Connect(generatePreview)
validateButton.MouseButton1Click:Connect(function()
	showMessages(validateSession())
end)
saveButton.MouseButton1Click:Connect(savePreset)
removeButton.MouseButton1Click:Connect(removePreview)

Selection.SelectionChanged:Connect(updateSelectionLabel)

toolbarButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toolbarButton:SetActive(widget.Enabled)
	if widget.Enabled then
		updateSelectionLabel()
	end
end)

updateControls()
updateSelectionLabel()
