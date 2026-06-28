-- Samurai Rampage invisible-region authoring plugin.
-- This file is safe inside a place before it is installed as a local plugin.
if not plugin then
	return
end

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

local PLUGIN_ID = "SamuraiRampageRegionEditorV1"
local TOOLBAR_NAME = "Samurai Rampage"
local ADORNMENT_FOLDER_NAME = "_SamuraiRegionEditorGuides"

local COLORS = {
	Background = Color3.fromRGB(22, 24, 29),
	Panel = Color3.fromRGB(31, 34, 41),
	PanelAlt = Color3.fromRGB(40, 44, 53),
	Text = Color3.fromRGB(235, 238, 245),
	Muted = Color3.fromRGB(158, 166, 181),
	Accent = Color3.fromRGB(210, 63, 55),
	Good = Color3.fromRGB(75, 170, 104),
	Warning = Color3.fromRGB(224, 168, 65),
	Border = Color3.fromRGB(62, 67, 78),
}

local CATEGORIES = {
	{
		Key = "LightingRegions",
		DisplayName = "Lighting",
		FolderNames = { "LightingRegions" },
		Color = Color3.fromRGB(255, 214, 92),
	},
	{
		Key = "NamedRegions",
		DisplayName = "Named",
		FolderNames = { "NamedRegions" },
		Color = Color3.fromRGB(95, 205, 255),
	},
	{
		Key = "OSTRegions",
		DisplayName = "OST",
		FolderNames = { "OSTRegions", "OstRegions" },
		Color = Color3.fromRGB(197, 123, 255),
	},
	{
		Key = "SoundRegions",
		DisplayName = "Sound",
		FolderNames = { "SoundRegions" },
		Color = Color3.fromRGB(100, 225, 151),
	},
	{
		Key = "WorldWalls",
		DisplayName = "World Walls",
		FolderNames = { "WorldWalls" },
		Color = Color3.fromRGB(255, 108, 101),
	},
}

local categoryByKey = {}
for _, category in CATEGORIES do
	categoryByKey[category.Key] = category
end

local selectedCategoryKey = plugin:GetSetting("SelectedCategory")
if not categoryByKey[selectedCategoryKey] then
	selectedCategoryKey = CATEGORIES[1].Key
end

local guidesEnabled = plugin:GetSetting("GuidesEnabled") ~= false
local foldersByCategory = {}
local partsByCategory = {}
local categoryByPart = {}
local categoryButtons = {}
local partRows = {}
local selectionConnections = {}
local guideFolder = nil
local proxyFolder = nil
local sourceByProxy = {}
local proxyBySource = {}
local proxyConnections = {}

local function trim(value: string): string
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function beginChange(name: string, callback)
	if RunService:IsRunning() then
		return false, "Stop the playtest before editing region properties."
	end

	local recording = ChangeHistoryService:TryBeginRecording(name, name)
	if not recording then
		return false, "Studio could not start an Undo recording."
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

local function rounded(guiObject: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 5)
	corner.Parent = guiObject
end

local function stroked(guiObject: GuiObject)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Border
	stroke.Thickness = 1
	stroke.Parent = guiObject
end

local function makeButton(parent: Instance, text: string, height: number?): TextButton
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
	rounded(button)
	stroked(button)
	return button
end

local function makeLabel(parent: Instance, text: string, height: number, textSize: number?, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height)
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = color or COLORS.Text
	label.TextSize = textSize or 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local toolbar = plugin:CreateToolbar(TOOLBAR_NAME)
local toolbarButton = toolbar:CreateButton(
	"Region Editor",
	"Reveal and edit invisible regions and world walls",
	"",
	"Region Editor"
)
toolbarButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false,
	false,
	430,
	720,
	360,
	500
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

widget.Title = "Samurai Region Editor"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundColor3 = COLORS.Background
root.BorderSizePixel = 0
root.Size = UDim2.fromScale(1, 1)
root.Parent = widget

local rootPadding = Instance.new("UIPadding")
rootPadding.PaddingTop = UDim.new(0, 12)
rootPadding.PaddingBottom = UDim.new(0, 12)
rootPadding.PaddingLeft = UDim.new(0, 12)
rootPadding.PaddingRight = UDim.new(0, 12)
rootPadding.Parent = root

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.CanvasSize = UDim2.new()
content.ScrollBarImageColor3 = COLORS.Accent
content.ScrollBarThickness = 5
content.Size = UDim2.fromScale(1, 1)
content.Parent = root

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 8)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

local title = makeLabel(content, "INVISIBLE REGION EDITOR", 26, 17, COLORS.Accent)
title.Font = Enum.Font.GothamBold

makeLabel(
	content,
	"Select invisible volumes, reveal them with temporary guides, then use precise fields or Studio's Move and Scale tools.",
	42,
	12,
	COLORS.Muted
)

local topActions = Instance.new("Frame")
topActions.BackgroundTransparency = 1
topActions.Size = UDim2.new(1, 0, 0, 36)
topActions.Parent = content

local topActionsLayout = Instance.new("UIListLayout")
topActionsLayout.FillDirection = Enum.FillDirection.Horizontal
topActionsLayout.Padding = UDim.new(0, 8)
topActionsLayout.Parent = topActions

local refreshButton = makeButton(topActions, "Refresh", 36)
refreshButton.Size = UDim2.new(0.5, -4, 1, 0)
local guidesButton = makeButton(topActions, "", 36)
guidesButton.Size = UDim2.new(0.5, -4, 1, 0)

local categoryFrame = Instance.new("Frame")
categoryFrame.BackgroundTransparency = 1
categoryFrame.Size = UDim2.new(1, 0, 0, 108)
categoryFrame.Parent = content

local categoryLayout = Instance.new("UIGridLayout")
categoryLayout.CellPadding = UDim2.fromOffset(7, 6)
categoryLayout.CellSize = UDim2.new(0.5, -4, 0, 32)
categoryLayout.FillDirectionMaxCells = 2
categoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
categoryLayout.Parent = categoryFrame

for index, category in CATEGORIES do
	local button = makeButton(categoryFrame, category.DisplayName, 32)
	button.LayoutOrder = index
	categoryButtons[category.Key] = button
end

local folderLabel = makeLabel(content, "", 34, 12, COLORS.Muted)

local searchBox = Instance.new("TextBox")
searchBox.Name = "Search"
searchBox.BackgroundColor3 = COLORS.Panel
searchBox.BorderSizePixel = 0
searchBox.ClearTextOnFocus = false
searchBox.Font = Enum.Font.Gotham
searchBox.PlaceholderColor3 = COLORS.Muted
searchBox.PlaceholderText = "Filter regions by name or folder..."
searchBox.Size = UDim2.new(1, 0, 0, 36)
searchBox.Text = ""
searchBox.TextColor3 = COLORS.Text
searchBox.TextSize = 13
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.Parent = content
rounded(searchBox)
stroked(searchBox)

local searchPadding = Instance.new("UIPadding")
searchPadding.PaddingLeft = UDim.new(0, 10)
searchPadding.PaddingRight = UDim.new(0, 10)
searchPadding.Parent = searchBox

local partList = Instance.new("ScrollingFrame")
partList.Name = "RegionList"
partList.BackgroundColor3 = COLORS.Panel
partList.BorderSizePixel = 0
partList.CanvasSize = UDim2.new()
partList.AutomaticCanvasSize = Enum.AutomaticSize.Y
partList.ScrollBarImageColor3 = COLORS.Accent
partList.ScrollBarThickness = 5
partList.Size = UDim2.new(1, 0, 0, 220)
partList.Parent = content
rounded(partList)
stroked(partList)

local partListPadding = Instance.new("UIPadding")
partListPadding.PaddingTop = UDim.new(0, 6)
partListPadding.PaddingBottom = UDim.new(0, 6)
partListPadding.PaddingLeft = UDim.new(0, 6)
partListPadding.PaddingRight = UDim.new(0, 6)
partListPadding.Parent = partList

local partListLayout = Instance.new("UIListLayout")
partListLayout.Padding = UDim.new(0, 4)
partListLayout.SortOrder = Enum.SortOrder.LayoutOrder
partListLayout.Parent = partList

local selectionLabel = makeLabel(content, "Selection: none", 30, 12, COLORS.Muted)

local listActions = Instance.new("Frame")
listActions.BackgroundTransparency = 1
listActions.Size = UDim2.new(1, 0, 0, 34)
listActions.Parent = content

local listActionsLayout = Instance.new("UIListLayout")
listActionsLayout.FillDirection = Enum.FillDirection.Horizontal
listActionsLayout.Padding = UDim.new(0, 8)
listActionsLayout.Parent = listActions

local selectAllButton = makeButton(listActions, "Select Category", 34)
selectAllButton.Size = UDim2.new(0.5, -4, 1, 0)
local focusButton = makeButton(listActions, "Focus Selection", 34)
focusButton.Size = UDim2.new(0.5, -4, 1, 0)

local function createVectorEditor(labelText: string)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 56)
	frame.Parent = content

	local label = makeLabel(frame, labelText, 18, 12, COLORS.Muted)
	label.Position = UDim2.fromOffset(0, 0)

	local boxes = {}
	for index, axis in { "X", "Y", "Z" } do
		local box = Instance.new("TextBox")
		box.Name = axis
		box.BackgroundColor3 = COLORS.Panel
		box.BorderSizePixel = 0
		box.ClearTextOnFocus = false
		box.Font = Enum.Font.Code
		box.PlaceholderColor3 = COLORS.Muted
		box.PlaceholderText = axis
		box.Position = UDim2.new((index - 1) / 3, if index == 1 then 0 else 4, 0, 22)
		box.Size = UDim2.new(1 / 3, -6, 0, 32)
		box.Text = ""
		box.TextColor3 = COLORS.Text
		box.TextSize = 13
		box.Parent = frame
		rounded(box)
		stroked(box)
		boxes[index] = box
	end

	return boxes
end

local positionBoxes = createVectorEditor("POSITION  (X / Y / Z)")
local sizeBoxes = createVectorEditor("SIZE  (X / Y / Z)")

local editActions = Instance.new("Frame")
editActions.BackgroundTransparency = 1
editActions.Size = UDim2.new(1, 0, 0, 38)
editActions.Parent = content

local editActionsLayout = Instance.new("UIListLayout")
editActionsLayout.FillDirection = Enum.FillDirection.Horizontal
editActionsLayout.Padding = UDim.new(0, 8)
editActionsLayout.Parent = editActions

local applyButton = makeButton(editActions, "Apply Position + Size", 38)
applyButton.BackgroundColor3 = COLORS.Good
applyButton.Size = UDim2.new(0.62, -4, 1, 0)
local lockButton = makeButton(editActions, "Unlock", 38)
lockButton.Size = UDim2.new(0.38, -4, 1, 0)

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundColor3 = COLORS.Panel
status.BorderSizePixel = 0
status.Size = UDim2.new(1, 0, 0, 62)
status.Font = Enum.Font.Code
status.Text = "Ready."
status.TextColor3 = COLORS.Text
status.TextSize = 12
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Parent = content
rounded(status)
stroked(status)

local statusPadding = Instance.new("UIPadding")
statusPadding.PaddingTop = UDim.new(0, 8)
statusPadding.PaddingBottom = UDim.new(0, 8)
statusPadding.PaddingLeft = UDim.new(0, 8)
statusPadding.PaddingRight = UDim.new(0, 8)
statusPadding.Parent = status

local function showStatus(message: string, color: Color3?)
	status.Text = message
	status.TextColor3 = color or COLORS.Text
end

local function findCategoryFolder(category)
	for _, container in { ReplicatedStorage, Workspace } do
		for _, folderName in category.FolderNames do
			local folder = container:FindFirstChild(folderName)
			if folder then
				return folder
			end
		end

		for _, child in container:GetChildren() do
			for _, folderName in category.FolderNames do
				if string.lower(child.Name) == string.lower(folderName) then
					return child
				end
			end
		end
	end

	return nil
end

local function getRelativeName(instance: Instance, folder: Instance): string
	local names = { instance.Name }
	local ancestor = instance.Parent
	while ancestor and ancestor ~= folder do
		table.insert(names, 1, ancestor.Name)
		ancestor = ancestor.Parent
	end
	return table.concat(names, " / ")
end

local function disconnectProxyConnections()
	for _, connection in proxyConnections do
		connection:Disconnect()
	end
	table.clear(proxyConnections)
end

local function destroyProxies()
	disconnectProxyConnections()
	for proxy in sourceByProxy do
		categoryByPart[proxy] = nil
	end
	if proxyFolder then
		proxyFolder:Destroy()
		proxyFolder = nil
	end
	table.clear(sourceByProxy)
	table.clear(proxyBySource)
end

local function createProxy(source: BasePart, category, parent: Instance): BasePart?
	local cloneOk, proxy = pcall(function()
		return source:Clone()
	end)
	if not cloneOk or not proxy or not proxy:IsA("BasePart") then
		return nil
	end

	proxy:ClearAllChildren()
	proxy.Name = source.Name
	proxy.Anchored = true
	proxy.Archivable = false
	proxy.CanCollide = false
	proxy.CanQuery = false
	proxy.CanTouch = false
	proxy.CastShadow = false
	proxy.Color = category.Color
	proxy.Locked = false
	proxy.Material = Enum.Material.ForceField
	proxy.Transparency = if guidesEnabled then 0.72 else 1
	proxy.Parent = parent

	sourceByProxy[proxy] = source
	proxyBySource[source] = proxy
	categoryByPart[proxy] = category

	local syncing = false
	local function syncToSource()
		if syncing or not source:IsDescendantOf(game) or not proxy:IsDescendantOf(game) then
			return
		end
		syncing = true
		source.CFrame = proxy.CFrame
		source.Size = proxy.Size
		syncing = false
	end

	local function syncToProxy()
		if syncing or not source:IsDescendantOf(game) or not proxy:IsDescendantOf(game) then
			return
		end
		syncing = true
		proxy.CFrame = source.CFrame
		proxy.Size = source.Size
		syncing = false
	end

	table.insert(proxyConnections, proxy:GetPropertyChangedSignal("CFrame"):Connect(syncToSource))
	table.insert(proxyConnections, proxy:GetPropertyChangedSignal("Size"):Connect(syncToSource))
	table.insert(proxyConnections, source:GetPropertyChangedSignal("CFrame"):Connect(syncToProxy))
	table.insert(proxyConnections, source:GetPropertyChangedSignal("Size"):Connect(syncToProxy))

	return proxy
end

local function createProxies()
	destroyProxies()
	if not widget.Enabled then
		return
	end

	proxyFolder = Instance.new("Folder")
	proxyFolder.Name = "_SamuraiRegionEditorVolumes"
	proxyFolder.Archivable = false
	proxyFolder.Parent = Workspace

	for _, category in CATEGORIES do
		local categoryFolder = Instance.new("Folder")
		categoryFolder.Name = category.Key
		categoryFolder.Archivable = false
		categoryFolder.Parent = proxyFolder

		for _, source in partsByCategory[category.Key] or {} do
			createProxy(source, category, categoryFolder)
		end
	end
end

local function getSourcePart(part: BasePart): BasePart
	return sourceByProxy[part] or part
end

local function getSelectedRegionParts(): { BasePart }
	local selected = {}
	for _, instance in Selection:Get() do
		if instance:IsA("BasePart") and categoryByPart[instance] then
			table.insert(selected, instance)
		end
	end
	return selected
end

local function getSingleSelectedPart(): BasePart?
	local selected = getSelectedRegionParts()
	return if #selected == 1 then selected[1] else nil
end

local function destroyGuides()
	if guideFolder then
		guideFolder:Destroy()
		guideFolder = nil
	end
end

local function refreshGuides()
	destroyGuides()
	if not guidesEnabled or not widget.Enabled then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	guideFolder = Instance.new("Folder")
	guideFolder.Name = ADORNMENT_FOLDER_NAME
	guideFolder.Archivable = false
	guideFolder.Parent = camera

	local selectedSet = {}
	for _, selected in Selection:Get() do
		selectedSet[selected] = true
	end

	for part in sourceByProxy do
		local category = categoryByPart[part]
		if not category or not part:IsDescendantOf(game) then
			continue
		end

		local guide = Instance.new("SelectionBox")
		guide.Name = category.Key
		guide.Adornee = part
		guide.Archivable = false
		guide.Color3 = if selectedSet[part] then Color3.new(1, 1, 1) else category.Color
		guide.LineThickness = if selectedSet[part] then 0.08 else 0.035
		guide.SurfaceColor3 = category.Color
		guide.SurfaceTransparency = if selectedSet[part] then 0.82 else 0.93
		guide.Parent = guideFolder
	end
end

local function updateGuideButton()
	guidesButton.Text = if guidesEnabled then "Guides: ON" else "Guides: OFF"
	guidesButton.BackgroundColor3 = if guidesEnabled then COLORS.Good else COLORS.PanelAlt
	for proxy in sourceByProxy do
		proxy.Transparency = if guidesEnabled then 0.72 else 1
	end
end

local function updateCategoryButtons()
	for _, category in CATEGORIES do
		local parts = partsByCategory[category.Key] or {}
		local button = categoryButtons[category.Key]
		button.Text = string.format("%s (%d)", category.DisplayName, #parts)
		button.BackgroundColor3 = if selectedCategoryKey == category.Key then category.Color else COLORS.PanelAlt
		button.TextColor3 = if selectedCategoryKey == category.Key then Color3.fromRGB(20, 22, 26) else COLORS.Text
	end
end

local function refreshPartRows()
	for _, row in partRows do
		row:Destroy()
	end
	table.clear(partRows)

	local category = categoryByKey[selectedCategoryKey]
	local folder = foldersByCategory[selectedCategoryKey]
	local parts = partsByCategory[selectedCategoryKey] or {}
	local filter = string.lower(trim(searchBox.Text))

	if folder then
		folderLabel.Text = folder:GetFullName() .. string.format("  |  %d parts", #parts)
	else
		folderLabel.Text = "Missing folder: ReplicatedStorage." .. category.FolderNames[1]
	end

	for _, part in parts do
		local relativeName = getRelativeName(part, folder)
		if filter ~= "" and not string.find(string.lower(relativeName), filter, 1, true) then
			continue
		end

		local row = makeButton(partList, relativeName, 30)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextSize = 12
		table.insert(partRows, row)

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = row

		row.MouseButton1Click:Connect(function()
			Selection:Set({ proxyBySource[part] or part })
			showStatus("Selected " .. part:GetFullName())
		end)
	end
end

local function refreshData()
	local selectedSources = {}
	for _, selected in Selection:Get() do
		if selected:IsA("BasePart") then
			local source = sourceByProxy[selected] or selected
			if categoryByPart[source] then
				table.insert(selectedSources, source)
			end
		end
	end

	destroyProxies()
	table.clear(foldersByCategory)
	table.clear(partsByCategory)
	table.clear(categoryByPart)

	for _, category in CATEGORIES do
		local folder = findCategoryFolder(category)
		foldersByCategory[category.Key] = folder
		local parts = {}

		if folder then
			if folder:IsA("BasePart") then
				table.insert(parts, folder)
			end
			for _, descendant in folder:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
					categoryByPart[descendant] = category
				end
			end
		end

		table.sort(parts, function(a, b)
			return string.lower(getRelativeName(a, folder)) < string.lower(getRelativeName(b, folder))
		end)
		partsByCategory[category.Key] = parts
	end

	createProxies()
	if #selectedSources > 0 then
		local restoredSelection = {}
		for _, source in selectedSources do
			local proxy = proxyBySource[source]
			if proxy then
				table.insert(restoredSelection, proxy)
			end
		end
		Selection:Set(restoredSelection)
	end

	updateCategoryButtons()
	refreshPartRows()
	refreshGuides()
end

local function disconnectSelectionConnections()
	for _, connection in selectionConnections do
		connection:Disconnect()
	end
	table.clear(selectionConnections)
end

local function setBoxText(box: TextBox, value: number)
	if not box:IsFocused() then
		box.Text = string.format("%.3f", value)
	end
end

local function clearVectorBoxes()
	for _, box in positionBoxes do
		if not box:IsFocused() then
			box.Text = ""
		end
	end
	for _, box in sizeBoxes do
		if not box:IsFocused() then
			box.Text = ""
		end
	end
end

local function updateSelectionFields()
	disconnectSelectionConnections()
	local selected = getSelectedRegionParts()
	local part = if #selected == 1 then selected[1] else nil

	if not part then
		selectionLabel.Text = if #selected == 0 then "Selection: none" else string.format("Selection: %d region parts", #selected)
		lockButton.Text = "Unlock"
		clearVectorBoxes()
		return
	end

	local source = getSourcePart(part)
	selectionLabel.Text = "Selection: " .. source:GetFullName()
	setBoxText(positionBoxes[1], part.Position.X)
	setBoxText(positionBoxes[2], part.Position.Y)
	setBoxText(positionBoxes[3], part.Position.Z)
	setBoxText(sizeBoxes[1], part.Size.X)
	setBoxText(sizeBoxes[2], part.Size.Y)
	setBoxText(sizeBoxes[3], part.Size.Z)
	lockButton.Text = if source.Locked then "Unlock" else "Lock"

	table.insert(selectionConnections, part:GetPropertyChangedSignal("CFrame"):Connect(updateSelectionFields))
	table.insert(selectionConnections, part:GetPropertyChangedSignal("Size"):Connect(updateSelectionFields))
	table.insert(selectionConnections, source:GetPropertyChangedSignal("Locked"):Connect(updateSelectionFields))
end

local function onSelectionChanged()
	local part = getSingleSelectedPart()
	local category = part and categoryByPart[part]
	if category and category.Key ~= selectedCategoryKey then
		selectedCategoryKey = category.Key
		plugin:SetSetting("SelectedCategory", selectedCategoryKey)
		updateCategoryButtons()
		refreshPartRows()
	end

	updateSelectionFields()
	refreshGuides()
end

local function parseBox(box: TextBox, label: string): number
	local value = tonumber(trim(box.Text))
	if not value or value ~= value or math.abs(value) == math.huge then
		error(label .. " must be a valid number.")
	end
	return value
end

local function readVector(boxes, label: string): Vector3
	return Vector3.new(
		parseBox(boxes[1], label .. " X"),
		parseBox(boxes[2], label .. " Y"),
		parseBox(boxes[3], label .. " Z")
	)
end

local function applyPositionAndSize()
	local part = getSingleSelectedPart()
	if not part then
		showStatus("Select exactly one region part first.", COLORS.Warning)
		return
	end

	local parseOk, positionOrError, size = pcall(function()
		return readVector(positionBoxes, "Position"), readVector(sizeBoxes, "Size")
	end)
	if not parseOk then
		showStatus(tostring(positionOrError), COLORS.Warning)
		return
	end

	local position = positionOrError
	if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
		showStatus("Every Size value must be greater than zero.", COLORS.Warning)
		return
	end

	local ok, result = beginChange("Edit region position and size", function()
		part.CFrame = CFrame.new(position) * part.CFrame.Rotation
		part.Size = size
	end)
	if not ok then
		showStatus(result, COLORS.Warning)
		return
	end

	updateSelectionFields()
	showStatus("Applied Position and Size. Use Ctrl+Z to undo.", COLORS.Good)
end

local function focusSelection()
	local selected = getSelectedRegionParts()
	if #selected == 0 then
		showStatus("Select one or more region parts first.", COLORS.Warning)
		return
	end

	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in selected do
		local radius = Vector3.new(part.Size.Magnitude, part.Size.Magnitude, part.Size.Magnitude) * 0.5
		minimum = minimum:Min(part.Position - radius)
		maximum = maximum:Max(part.Position + radius)
	end

	local center = (minimum + maximum) * 0.5
	local extent = maximum - minimum
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local direction = camera.CFrame.Position - center
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(1, 0.7, 1)
	end
	direction = direction.Unit
	local distance = math.max(extent.Magnitude * 1.1, 16)
	camera.CFrame = CFrame.lookAt(center + direction * distance, center)
	camera.Focus = CFrame.new(center)
	showStatus(string.format("Focused %d region part(s).", #selected), COLORS.Good)
end

for _, category in CATEGORIES do
	categoryButtons[category.Key].MouseButton1Click:Connect(function()
		selectedCategoryKey = category.Key
		plugin:SetSetting("SelectedCategory", selectedCategoryKey)
		updateCategoryButtons()
		refreshPartRows()
	end)
end

refreshButton.MouseButton1Click:Connect(function()
	refreshData()
	updateSelectionFields()
	showStatus("Refreshed region folders and guides.", COLORS.Good)
end)

guidesButton.MouseButton1Click:Connect(function()
	guidesEnabled = not guidesEnabled
	plugin:SetSetting("GuidesEnabled", guidesEnabled)
	updateGuideButton()
	refreshGuides()
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(refreshPartRows)

selectAllButton.MouseButton1Click:Connect(function()
	local parts = partsByCategory[selectedCategoryKey] or {}
	local proxies = {}
	for _, part in parts do
		local proxy = proxyBySource[part]
		if proxy then
			table.insert(proxies, proxy)
		end
	end
	Selection:Set(proxies)
	showStatus(string.format("Selected %d part(s).", #proxies), COLORS.Good)
end)

focusButton.MouseButton1Click:Connect(focusSelection)
applyButton.MouseButton1Click:Connect(applyPositionAndSize)

lockButton.MouseButton1Click:Connect(function()
	local selected = getSelectedRegionParts()
	if #selected == 0 then
		showStatus("Select one or more region parts first.", COLORS.Warning)
		return
	end

	local shouldLock = false
	for _, part in selected do
		if not getSourcePart(part).Locked then
			shouldLock = true
			break
		end
	end

	local ok, result = beginChange(if shouldLock then "Lock regions" else "Unlock regions", function()
		for _, part in selected do
			getSourcePart(part).Locked = shouldLock
		end
	end)
	if not ok then
		showStatus(result, COLORS.Warning)
		return
	end
	updateSelectionFields()
	showStatus(if shouldLock then "Locked selection." else "Unlocked selection.", COLORS.Good)
end)

Selection.SelectionChanged:Connect(onSelectionChanged)

toolbarButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toolbarButton:SetActive(widget.Enabled)
	if widget.Enabled then
		refreshData()
		updateSelectionFields()
	else
		destroyGuides()
		destroyProxies()
	end
end)

plugin.Unloading:Connect(function()
	disconnectSelectionConnections()
	destroyGuides()
	destroyProxies()
end)

updateGuideButton()
refreshData()
updateSelectionFields()
