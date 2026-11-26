-- Context supplies the service dependencies and records its private Cut signal.
return function(Service: any, Context: any): string
	local Folder = Instance.new("Folder")
	Folder.Name = "TreeCuttingServiceTest"
	Folder.Parent = workspace
	local Checks = 0
	local Falls = {}
	local OriginalFell = Service.Fell

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Character(X: number): Model
		local Model = Instance.new("Model")
		local Root = Instance.new("Part")
		Root.Anchored = true
		Root.CFrame = CFrame.new(X, 1003, 20000)
		Root.Parent = Model
		Model.PrimaryPart = Root
		Model.Parent = Folder

		return Model
	end

	local function Tree(Diameter: number, Z: number): (Model, Part)
		local Model = Instance.new("Model")
		local Trunk = Instance.new("Part")
		Trunk.Shape = Enum.PartType.Cylinder
		Trunk.Name = "Trunk_99"
		Trunk.Size = Vector3.new(30, Diameter, Diameter)
		Trunk.Anchored = true
		Trunk.CFrame = CFrame.new(20000, 1015, Z) * CFrame.Angles(0, 0, math.pi * 0.5)
		Trunk.Parent = Model
		Model.PrimaryPart = Trunk
		Model.Parent = Folder

		return Model, Trunk
	end

	Service.Fell = function(_Self: any, _Player: any, Target: Model, _State: any, Direction: Vector3)
		Target:SetAttribute("Broken", true)
		table.insert(Falls, Direction)
	end
	local A = { Character = Character(20002) }
	local B = { Character = Character(19998) }
	local Thin, Trunk = Tree(2, 20000)

	local Success, Error = pcall(function()
		Context.SetAllowed(false)
		Check(not Service:Hit(A, Thin, Trunk, Vector3.new(20001, 1003, 20000)), "Reject unauthorized hits")
		Context.SetAllowed(true)
		A.Character.PrimaryPart.Position = Vector3.new(20002, 1019, 20000)
		Check(not Service:Hit(A, Thin, Trunk, Vector3.new(20001, 1019, 20000)), "Reject hits above 18 studs")
		Check(Thin:GetAttribute("Health") == nil, "Invalid hits do not damage the tree")
		A.Character.PrimaryPart.Position = Vector3.new(20002, 1003, 20000)
		Check(Service:Hit(A, Thin, Trunk, Vector3.new(20001, 1003, 20000)), "Accept a base hit")
		Check(Thin:GetAttribute("MaxHealth") == 3 and Thin:GetAttribute("Health") == 2, "Thin tree needs 3 hits")
		Check(#Context.Sent == 1 and Context.Sent[1].Player == A, "Only A receives A's cut")
		Check(Service:Hit(B, Thin, Trunk, Vector3.new(19999, 1003, 20000)), "Accept an opposing hit")
		Check(#Context.Sent == 2 and Context.Sent[2].Player == B, "Only B receives B's cut")
		Check(not Thin:GetAttribute("Broken") and Thin:GetAttribute("Health") == 1, "Opposing cuts cannot fell early")
		Check(Service:Hit(A, Thin, Trunk, Vector3.new(20001, 1003, 20000)), "Accept the final hit")
		Check(#Falls == 1 and Falls[1].X > 0.99, "Fall toward the more damaged side")
		Check(not Service:Hit(B, Thin, Trunk, Vector3.new(19999, 1003, 20000)), "Reject hits after falling")

		local Thick, BigTrunk = Tree(14, 20100)
		A.Character.PrimaryPart.Position = Vector3.new(20008, 1003, 20100)
		for Index = 1, 6 do
			Check(Service:Hit(A, Thick, BigTrunk, Vector3.new(20007, 1003, 20100)), "Accept a thick trunk hit")
			if Index < 6 then
				Check(not Thick:GetAttribute("Broken"), "Thick tree must remain standing")
			end
		end
		Check(Thick:GetAttribute("MaxHealth") == 6 and #Falls == 2, "Thick tree needs 6 hits")
	end)

	Service.Fell = OriginalFell
	Folder:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " tree cutting service checks passed"
end
