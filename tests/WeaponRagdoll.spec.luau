-- ApplyRagdollMotors should run the motor-disable loop from the game's Ragdoll module.
return function(ServiceModule: ModuleScript, RigTemplate: Model, WeaponTemplate: Instance, ApplyRagdollMotors: (Model) -> ()): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local OriginalRequire = require
	local Run = assert(loadstring(ServiceModule.Source:gsub("return WeaponService%s*$",
		"return {Load = LoadWeaponModel, SetState = SetWeaponEquipState}")))
	setfenv(Run, setmetatable({
		require = function(Module: ModuleScript): any
			if Module == ReplicatedStorage.Packages.Knit then
				return { CreateService = function(Value: any): any
					return Value
				end }
			end

			return OriginalRequire(Module)
		end,
	}, { __index = getfenv() }))
	local Harness = Run()
	local Character = RigTemplate:Clone()
	Character:SetAttribute("WeaponEquipped", false)
	for _, Source in Character:QueryDescendants("LuaSourceContainer") do
		Source:Destroy()
	end
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end

	local Success, Failure = pcall(function()
		Harness.Load(Character, WeaponTemplate, "Weapon", "Sheath", "Right")
		Harness.Load(Character, WeaponTemplate, "LeftWeapon", "LeftSheath", "Left")
		local Attachments = {}
		for _, Motor: Motor6D in Character:QueryDescendants("Motor6D") do
			if Motor.Part1 and table.find({ "RightHand", "LeftHand", "SheathPart", "SheathPart2" }, Motor.Part1.Name) then
				table.insert(Attachments, Motor)
				Check(Motor:GetAttribute("NotRagdoll") == true, "Protect the attachment motor " .. Motor.Name)
			end
		end
		Check(#Attachments == 4, "Exercise both hands and both sheath anchors on the real rig")

		local WeaponFolder = Character.Assets.Weapon
		local Right = WeaponFolder:FindFirstChild("Weapon") :: Model
		local Left = WeaponFolder:FindFirstChild("LeftWeapon") :: Model
		Check(Right ~= nil and Left ~= nil, "Load both dual-wield slots")
		for _, Equipped in { true, false, true } do
			Harness.SetState(Right, Equipped)
			Harness.SetState(Left, Equipped)
			local WeldStates = {}
			for _, Weld: Weld in WeaponFolder:QueryDescendants("Weld") do
				WeldStates[Weld] = Weld.Enabled
			end

			ApplyRagdollMotors(Character)
			for _, Motor in Attachments do
				Check(Motor.Enabled and Motor.Part0 ~= nil and Motor.Part1 ~= nil, "Ragdoll must keep " .. Motor.Name .. " attached")
			end
			local Shoulder = Character.Torso:FindFirstChild("Left Shoulder") :: Motor6D
			Check(not Shoulder.Enabled, "The left arm must still enter body ragdoll")
			for Weld, Enabled in WeldStates do
				Check(Weld.Enabled == Enabled, "Ragdoll must preserve the active hand/sheath weld selection")
			end

			for _, Motor: Motor6D in Character:QueryDescendants("Motor6D") do
				Motor.Enabled = true
			end
		end
	end)

	Character:Destroy()
	assert(Success, Failure)
	return string.format("Dual wield ragdoll: %d checks passed", Checks)
end
