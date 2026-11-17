local FirstPersonVisibilityController = {}

type Visual = BasePart | Decal
export type State = {
	Character: Model,
	FaceHead: Instance?,
	Targets: { [Visual]: number },
	Connections: { RBXScriptConnection },
	FaceConnections: { RBXScriptConnection },
	Dirty: boolean,
	Active: boolean,
}

local HeadTypes = { Hat = true, Hair = true, Face = true, Eyebrow = true, Eyelash = true }
local HeadAttachments = { HatAttachment = true, HairAttachment = true, FaceFrontAttachment = true, FaceCenterAttachment = true }
local HeadSlots = { Head = true, Face = true, Eyes = true }

local function IsHeadAccessory(Accessory: Accessory, Head: BasePart?): boolean
	if HeadTypes[Accessory.AccessoryType.Name] or Accessory.Name == "Hair" then
		return true
	end
	for _, Attachment in Accessory:QueryDescendants("Attachment") do
		if HeadAttachments[Attachment.Name] then
			return true
		end
	end
	for _, Joint in Accessory:QueryDescendants("JointInstance") :: { JointInstance } do
		if Head and (Joint.Part0 == Head or Joint.Part1 == Head) then
			return true
		end
	end
	for _, Weld in Accessory:QueryDescendants("WeldConstraint") :: { WeldConstraint } do
		if Head and (Weld.Part0 == Head or Weld.Part1 == Head) then
			return true
		end
	end

	return false
end

local function IsHeadVisual(State: State, Object: Visual, Head: BasePart?): boolean
	if Object == Head or (Head and Object:IsDescendantOf(Head)) then
		return true
	end
	if State.FaceHead and (Object == State.FaceHead or Object:IsDescendantOf(State.FaceHead)) then
		return true
	end

	local Ancestor: Instance? = Object
	while Ancestor and Ancestor ~= State.Character do
		if Ancestor:IsA("Accessory") and IsHeadAccessory(Ancestor, Head) then
			return true
		end
		if Ancestor.Name == "Hair" or Ancestor.Name == "FacialHair" or Ancestor.Name == "FaceHead" then
			return true
		end
		local Parent = Ancestor.Parent
		if HeadSlots[Ancestor.Name] and Parent and Parent.Name == "Equipables" then
			return true
		end
		Ancestor = Parent
	end

	return false
end

local function Watch(State: State, Root: Instance, Connections: { RBXScriptConnection })
	table.insert(Connections, Root.DescendantAdded:Connect(function()
		State.Dirty = true
	end))
	table.insert(Connections, Root.DescendantRemoving:Connect(function()
		State.Dirty = true
	end))
end

function FirstPersonVisibilityController.Create(Character: Model): State
	local State: State = {
		Character = Character, Targets = {}, Connections = {}, FaceConnections = {}, Dirty = true, Active = false,
	}
	Watch(State, Character, State.Connections)

	return State
end

function FirstPersonVisibilityController.Refresh(State: State)
	local Head = State.Character:FindFirstChild("Head") :: BasePart?
	local Folder = workspace:FindFirstChild("FaceHeadFolder")
	local FaceHead = if Folder then Folder:FindFirstChild(State.Character.Name .. "FaceHead") else nil
	if FaceHead then
		local Weld = FaceHead:FindFirstChild("FaceHeadWeld") :: WeldConstraint?
		if not Weld or not Head or (Weld.Part0 ~= Head and Weld.Part1 ~= Head) then
			FaceHead = nil
		end
	end
	if FaceHead ~= State.FaceHead then
		for _, Connection in State.FaceConnections do
			Connection:Disconnect()
		end
		table.clear(State.FaceConnections)
		State.FaceHead = FaceHead
		State.Dirty = true
		if FaceHead then
			Watch(State, FaceHead, State.FaceConnections)
		end
	end
	if not State.Dirty then
		return
	end
	State.Dirty = false

	local Desired: { [Visual]: boolean } = {}
	local Roots: { Instance } = { State.Character }
	if FaceHead then
		table.insert(Roots, FaceHead)
	end
	for _, Root in Roots do
		if Root:IsA("BasePart") and IsHeadVisual(State, Root, Head) then
			Desired[Root] = true
		end
		for _, Class in { "BasePart", "Decal" } do
			for _, Object in Root:QueryDescendants(Class) :: { Visual } do
				if IsHeadVisual(State, Object, Head) then
					Desired[Object] = true
				end
			end
		end
	end
	for Object, Original in State.Targets do
		if not Desired[Object] then
			Object.LocalTransparencyModifier = Original
			State.Targets[Object] = nil
		end
	end
	for Object in Desired do
		if State.Targets[Object] == nil then
			State.Targets[Object] = Object.LocalTransparencyModifier
		end
	end
end

function FirstPersonVisibilityController.Update(State: State, Active: boolean)
	if not Active and not State.Active then
		return
	end
	State.Active = Active
	for Object, Original in State.Targets do
		Object.LocalTransparencyModifier = if Active then 1 else Original
	end
end

function FirstPersonVisibilityController.Destroy(State: State)
	FirstPersonVisibilityController.Update(State, false)
	for _, Connection in State.Connections do
		Connection:Disconnect()
	end
	for _, Connection in State.FaceConnections do
		Connection:Disconnect()
	end
	table.clear(State.Targets)
end

return FirstPersonVisibilityController
