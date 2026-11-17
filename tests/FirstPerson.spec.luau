return function(Visibility: any, CameraController: any): string
	local Fixture = Instance.new("Folder")
	Fixture.Name = "FirstPersonTests"
	Fixture.Parent = workspace
	local Character = Instance.new("Model")
	Character.Name = "FirstPersonTestCharacter"
	Character.Parent = Fixture
	local Head = Instance.new("Part")
	Head.Name = "Head"
	Head.Parent = Character
	local Body = Instance.new("Part")
	Body.Name = "Torso"
	Body.Parent = Character
	local Face = Instance.new("Decal")
	Face.Parent = Head
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Parent = Character
	local Camera = Instance.new("Camera")
	Camera.CameraSubject = Humanoid
	Camera.CameraType = Enum.CameraType.Custom
	Camera.Focus = CFrame.new(0, 3, 0)
	Camera.CFrame = CFrame.new(0, 3, 0.5)
	local State = Visibility.Create(Character)
	local OwnedFaceFolder: Folder? = nil
	local OwnedFaceHead: BasePart? = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Accessory(Name: string, Kind: Enum.AccessoryType, AttachmentName: string?): (Accessory, Part)
		local Object = Instance.new("Accessory")
		Object.Name = Name
		Object.AccessoryType = Kind
		local Handle = Instance.new("Part")
		Handle.Name = "Handle"
		Handle.Parent = Object
		if AttachmentName then
			local Attachment = Instance.new("Attachment")
			Attachment.Name = AttachmentName
			Attachment.Parent = Handle
		end
		Object.Parent = Character

		return Object, Handle
	end

	local Success, Error = pcall(function()
		local Hair, HairHandle = Accessory("ImportedHair", Enum.AccessoryType.Unknown, "HairAttachment")
		local _, Hat = Accessory("Helmet", Enum.AccessoryType.Hat, nil)
		local _, Mask = Accessory("Mask", Enum.AccessoryType.Face, nil)
		local _, Backpack = Accessory("Backpack", Enum.AccessoryType.Back, "BodyBackAttachment")
		HairHandle.LocalTransparencyModifier = 0.3
		local Assets = Instance.new("Folder")
		Assets.Name = "Assets"
		Assets.Parent = Character
		local Equipables = Instance.new("Folder")
		Equipables.Name = "Equipables"
		Equipables.Parent = Assets
		local Slot = Instance.new("Folder")
		Slot.Name = "Face"
		Slot.Parent = Equipables
		local CustomMask = Instance.new("MeshPart")
		CustomMask.Parent = Slot
		Visibility.Refresh(State)
		Visibility.Update(State, true)
		for _, Object in { Head, Face, HairHandle, Hat, Mask, CustomMask } do
			Check(Object.LocalTransparencyModifier == 1, "Head, face, hair and head equipment must hide locally")
		end
		Check(Body.LocalTransparencyModifier == 0 and Backpack.LocalTransparencyModifier == 0,
			"Head visibility must not modify the body or back equipment")
		Check(Head.Transparency == 0 and Face.Transparency == 0, "Local hiding preserves the replicated appearance")
		Head.LocalTransparencyModifier = 0
		Visibility.Update(State, true)
		Check(Head.LocalTransparencyModifier == 1, "Native camera updates cannot reveal the hidden head")
		Check(CameraController.IsFirstPerson(Camera, Character), "Zooming close to the local subject enters first person")
		Camera.CFrame = CFrame.new(0, 3, 8)
		Check(not CameraController.IsFirstPerson(Camera, Character), "Zooming out leaves first person")
		Camera.CFrame = CFrame.new(0, 3, 0.5)
		Camera.CameraType = Enum.CameraType.Scriptable
		Check(not CameraController.IsFirstPerson(Camera, Character), "Cutscene cameras do not hide the local head")
		Camera.CameraType = Enum.CameraType.Custom
		Camera.CameraSubject = Body
		Character:SetAttribute("CameraCutscene", true)
		Check(not CameraController.IsFirstPerson(Camera, Character), "Character cutscene flags suspend first person")
		Character:SetAttribute("CameraCutscene", nil)
		Camera.CameraSubject = Instance.new("Part")
		Check(not CameraController.IsFirstPerson(Camera, Character), "Spectating another subject restores local visibility")
		Camera.CameraSubject:Destroy()

		local FaceFolder = workspace:FindFirstChild("FaceHeadFolder")
		if not FaceFolder then
			FaceFolder = Instance.new("Folder")
			FaceFolder.Name = "FaceHeadFolder"
			FaceFolder.Parent = Fixture
			-- The live game keeps this folder directly in workspace.
			FaceFolder.Parent = workspace
			OwnedFaceFolder = FaceFolder :: Folder
		end
		local FaceHead = Instance.new("Part")
		OwnedFaceHead = FaceHead
		FaceHead.Name = Character.Name .. "FaceHead"
		FaceHead.Transparency = 1
		local Weld = Instance.new("WeldConstraint")
		Weld.Name = "FaceHeadWeld"
		Weld.Part0 = Head
		Weld.Part1 = FaceHead
		Weld.Parent = FaceHead
		FaceHead.Parent = FaceFolder
		local Eyes = Instance.new("Decal")
		Eyes.Parent = FaceHead
		Visibility.Refresh(State)
		Visibility.Update(State, true)
		Check(FaceHead.LocalTransparencyModifier == 1 and Eyes.LocalTransparencyModifier == 1,
			"A FaceHead created outside the character after spawn must hide, including its decals")
		Eyes.Transparency = 0.6
		Visibility.Update(State, true)
		Check(Eyes.LocalTransparencyModifier == 1, "Blink changes cannot reveal a hidden face")
		local _, LateAccessory = Accessory("LateGlasses", Enum.AccessoryType.Unknown, "FaceFrontAttachment")
		task.wait()
		Visibility.Refresh(State)
		Visibility.Update(State, true)
		Check(LateAccessory.LocalTransparencyModifier == 1, "Equipment added during first person must hide")

		Hair.Parent = Fixture
		task.wait()
		Visibility.Refresh(State)
		Check(math.abs(HairHandle.LocalTransparencyModifier - 0.3) < 0.001, "Unequipping hair restores its previous local visibility")
		Visibility.Update(State, false)
		Check(Head.LocalTransparencyModifier == 0 and Face.LocalTransparencyModifier == 0
			and FaceHead.LocalTransparencyModifier == 0 and Eyes.LocalTransparencyModifier == 0,
			"Third person restores the head and the separate face")
		Check(math.abs(Eyes.Transparency - 0.6) < 0.001, "Leaving first person preserves the current blink transparency")
		Visibility.Update(State, true)
		Visibility.Destroy(State)
		Check(Head.LocalTransparencyModifier == 0, "Respawning restores old character visibility")
		FaceHead:Destroy()
	end)

	Visibility.Destroy(State)
	if OwnedFaceHead then
		OwnedFaceHead:Destroy()
	end
	if OwnedFaceFolder then
		OwnedFaceFolder:Destroy()
	end
	Camera:Destroy()
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("FirstPerson: %d checks passed", Checks)
end
