local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local HitboxService = Knit.CreateService({
	Name = "HitboxService",
	Client = {},
})

local WeaponService
local DebounceService

function HitboxService:GetHumanoidsInTable(tabela)
	local Characters = {}

	for i, v: BasePart in tabela do
		local Character = v:FindFirstAncestorWhichIsA("Model")
		if not Character then
			continue
		end
		if not Character:FindFirstChild("Humanoid") then
			continue
		end
		if table.find(Characters, Character) then
			continue
		end

		table.insert(Characters, Character)
	end

	return Characters
end
function HitboxService.Client:GetHumanoidsInTable(_, table)
	return self.Server:GetHumanoidsInTable(table)
end

function HitboxService:GetCharactersInBoxArea(cframe, size, Params)
	local Params = Params or OverlapParams.new()

	if not cframe then
		return print("CFrame is nil")
	end
	if not size then
		return print("Size is nil")
	end

	local Parts = game.Workspace:GetPartBoundsInBox(cframe, size, Params)

	local Characters = HitboxService:GetHumanoidsInTable(Parts)

	return Characters
end
function HitboxService:GetCharactersInPart(part: Part, Params: OverlapParams)
	local Params = Params or OverlapParams.new()
	local Parts = game.Workspace:GetPartsInPart(part, Params)
	local Characters = HitboxService:GetHumanoidsInTable(Parts)
	return Characters
end

function HitboxService.Client:GetCharactersInBoxArea(player, cframe, size, Params)
	return self.Server:GetCharactersInRoundArea(cframe, size, Params)
end

function HitboxService:LoadR6Hitbox(Character: Model)
	local R6Hitbox = ServerStorage.ServerAssets.Hitboxes.R6Hitbox:Clone()

	for _, Part in Character:GetChildren() do
		if Part.Name == "Hitbox" then
			Part:Destroy()
		else
			Part:RemoveTag("HitboxDetectable")
		end
	end

	R6Hitbox:PivotTo(Character.HumanoidRootPart.CFrame)

	local Weld = Instance.new("Weld")
	Weld.Part0 = Character.HumanoidRootPart
	Weld.Part1 = R6Hitbox.Root
	Weld.Name = "HitboxWeld"
	Weld.Parent = R6Hitbox.Root

	for _, Part in R6Hitbox:GetChildren() do
		Part.Name = "Hitbox"
		Part.Parent = Character
	end

	R6Hitbox:Destroy()
end

local Params = OverlapParams.new()
Params.FilterType = Enum.RaycastFilterType.Include
function HitboxService:GetCharactersInCircleArea(position, radius)
	Params.FilterDescendantsInstances = { CollectionService:GetTagged("HitboxDetectable") }

	if not position then
		return print("Position is nil")
	end
	if not radius then
		return print("Radius is nil")
	end

	local Parts = game.Workspace:GetPartBoundsInRadius(position, radius, Params)

	local Characters = HitboxService:GetHumanoidsInTable(Parts)

	return Characters
end
function HitboxService.Client:GetCharactersInCircleArea(player, position, radius, Params)
	return self.Server:GetCharactersInCircleArea(position, radius, Params)
end

type HitboxData = {
	Size: Vector3,
	Radius: number,
	CFrame: CFrame,
	Frames: number,
	DontWeld: boolean,
	IgnoreCheck: boolean,
}

function HitboxService:CreateHitbox(Character: Model, HitboxSize: Vector3, CheckFrames: number, callback)
	local Hitted = {}
	local RootPart = Character:WaitForChild("HumanoidRootPart")

	Params.FilterDescendantsInstances = { CollectionService:GetTagged("HitboxDetectable") }

	task.spawn(function()
		for _ = 0, CheckFrames or 16, 1 do
			local Hitbox = HitboxService:GetCharactersInBoxArea(
				RootPart.CFrame * CFrame.new(0, 0, -(HitboxSize.Z / 2)),
				HitboxSize,
				Params
			)

			for i, char in ipairs(Hitbox) do
				if char == Character then
					continue
				end
				if table.find(Hitted, char) then
					continue
				end
				table.insert(Hitted, char)

				local response = callback(char)
				if response == false then
					break
				end
			end

			task.wait()
		end
	end)
end

local Params = OverlapParams.new()
Params.FilterType = Enum.RaycastFilterType.Include

local function Check(Character: Model)
	if
		Character:GetAttribute("Died")
		or Character:GetAttribute("Downed")
		or Character:GetAttribute("Ragdoll")
		or Character:GetAttribute("Hitted")
		or Character:GetAttribute("Clashed")
		or Character:GetAttribute("BeenDeflected")
	then
		return false
	end
	return true
end

function HitboxService:CreatePartHitbox(Character: Model, HitboxData: HitboxData, callback)
	local HitboxData = HitboxData or {}
	local RootPart = Character:WaitForChild("HumanoidRootPart")

	local Hitbox = Instance.new("Part")
	Hitbox.Name = "Hitbox"
	Hitbox.Anchored = true
	Hitbox.CanCollide = false
	Hitbox.Massless = true
	Hitbox.Size = HitboxData.Size or Vector3.new(7.5, 7.5, 7.5)
	Hitbox.Transparency = HitboxData.Visible and 0 or 1
	Hitbox.Parent = workspace
	Hitbox.CFrame = HitboxData.CFrame or RootPart.CFrame * CFrame.new(0, 0, -Hitbox.Size.Z / 2)

	local Hitted = HitboxData.Hitted or {}

	Params.FilterDescendantsInstances = { CollectionService:GetTagged("HitboxDetectable") }

	DebounceService:AddDebounce(Character, "HitboxStart", 0.05)

	task.spawn(function()
		for i = 0, HitboxData.Frames or 12, 1 do
			if not HitboxData.DontWeld then
				if HitboxData.CFrame then
					Hitbox.CFrame = HitboxData.CFrame
				else
					Hitbox.CFrame = RootPart.CFrame * CFrame.new(0, 0, -Hitbox.Size.Z / 2)
				end
			end
			local CharactersInside = HitboxService:GetCharactersInPart(Hitbox, Params)

			for _, char in CharactersInside do
				if char == Character then
					continue
				end
				if table.find(Hitted, char) then
					continue
				end

				if not HitboxData.IgnoreCheck then
					if not Check(Character) then
						break
					end
				end

				if char:GetAttribute("IsAI") then
					char.HitboxDetected:Fire(Character, HitboxData.Data or {})
				end

				table.insert(Hitted, char)
				local response = callback(char)
				if response == false then
					break
				end
			end
			task.wait()
		end

		Hitbox:Destroy()
	end)
end

function HitboxService:CreateCircleHitbox(Character: Model, HitboxData: HitboxData, callback)
	local HitboxData = HitboxData or {}
	local RootPart = Character:WaitForChild("HumanoidRootPart")
	local Hitted = HitboxData.Hitted or {}

	local Visual
	if HitboxData.Visible then
		Visual = Instance.new("Part")
		Visual.Anchored = true
		Visual.CanCollide = false
		Visual.CanQuery = false
		Visual.CanTouch = false
		Visual.Shape = Enum.PartType.Ball
		Visual.Size = Vector3.new(HitboxData.Radius * 2, HitboxData.Radius * 2, HitboxData.Radius * 2)
		Visual.Transparency = 0.5
		Visual.Material = Enum.Material.Neon
		Visual.Color = Color3.fromRGB(0, 255, 0)
		Visual.Parent = workspace
	end

	DebounceService:AddDebounce(Character, "HitboxStart", 0.05)

	task.spawn(function()
		for i = 0, HitboxData.Frames or 12, 1 do
			local HitboxCFrame = HitboxData.CFrame or (RootPart.CFrame * CFrame.new(0, 0, -HitboxData.Radius / 2))
			local Position = HitboxCFrame.Position

			if Visual then
				Visual.CFrame = CFrame.new(Position)
				Visual.Size = Vector3.new(HitboxData.Radius * 2, HitboxData.Radius * 2, HitboxData.Radius * 2)
			end

			local CharactersInside = HitboxService:GetCharactersInCircleArea(Position, HitboxData.Radius)

			for _, char in CharactersInside do
				if char == Character then
					continue
				end
				if table.find(Hitted, char) then
					continue
				end
				if not HitboxData.IgnoreCheck then
					if not Check(Character) then
						break
					end
				end
				if char:GetAttribute("IsAI") then
					char.HitboxDetected:Fire(Character, HitboxData.Data or {})
				end
				table.insert(Hitted, char)
				local response = callback(char)
				if response == false then
					break
				end
			end
			task.wait()
		end

		if Visual then
			Visual:Destroy()
		end
	end)
end

local RaycastHitboxV4 = require(game.ReplicatedStorage.Assets.Libraries.RaycastHitboxV4)

function HitboxService:RaycastHitbox(Attacker: Model, Duration: number, callback, Data)
	local Model = Attacker.Assets.Weapon:FindFirstChild("Weapon")
	if not Model then
		return
	end

	local Hitbox = RaycastHitboxV4.new(Model)
	Hitbox:HitStart(Duration)

	Hitbox.OnHit:Connect(function(hit, humanoid)
		if humanoid.Parent == Attacker then
			return
		end

		if humanoid.Parent:GetAttribute("IsAI") then
			humanoid.Parent.HitboxDetected:Fire(Attacker, Data or {})
		end

		return callback(humanoid.Parent, hit)
	end)
end

local Rayparams = RaycastParams.new()
local Collector = require(game.ReplicatedStorage.Shared.Collector)
Rayparams.FilterType = Enum.RaycastFilterType.Include
Rayparams.FilterDescendantsInstances = { CollectionService:GetTagged("HitboxDetectable") }
function HitboxService:CharacterRaycastHitbox(Character: Model, Duration: number, callback, onDisconnect, Data)
	local Data = Data or {}
	local HandHitbox = Data.HandHitbox
	local WeaponFolder = Character.Assets.Weapon

	if Data.HandHitbox then
		Data.HandHitbox = nil
	end

	local PartHitbox = WeaponFolder:FindFirstChild("Weapon")
	if HandHitbox == "Left" then
		PartHitbox = WeaponFolder:FindFirstChild("LeftWeapon") or (PartHitbox and PartHitbox:FindFirstChild("Left Arm"))
	elseif HandHitbox == "Right" then
		PartHitbox = PartHitbox and (PartHitbox:FindFirstChild("Right Arm") or PartHitbox)
	end

	if not PartHitbox then
		return
	end

	local Hitbox = RaycastHitboxV4.new(PartHitbox)
	Rayparams.FilterDescendantsInstances = { CollectionService:GetTagged("HitboxDetectable") }
	Hitbox.RaycastParams = Rayparams
	Hitbox:HitStart()

	local Connections = Collector.new()

	local disconnected = false
	local function DisconnectAll(shouldfire)
		if disconnected then
			return
		end
		disconnected = true

		Connections:Destroy()

		if Hitbox.HitStop then
			Hitbox:HitStop()
		end

		if shouldfire and onDisconnect then
			onDisconnect()
		end
	end

	for _, Attribute in WeaponService.CancelM1Attributes do
		Connections:Add(Character:GetAttributeChangedSignal(Attribute):Connect(function()
			DisconnectAll(true)
		end))
	end

	Hitbox.OnHit:Connect(function(hit, humanoid, result)
		local CharacterHitted = humanoid.Parent
		if Character == CharacterHitted then
			return
		end

		if Character:GetAttribute("IsAI") and CharacterHitted:GetAttribute("IsAI") then
			return
		end

		if WeaponService:DidCancel(Character) then
			DisconnectAll(true)
			return
		end

		if CharacterHitted:GetAttribute("IsAI") then
			CharacterHitted.HitboxDetected:Fire(Character, Data or {})
		end

		callback(humanoid.Parent, hit, result)
	end)

	task.delay(Duration, function()
		DisconnectAll()
	end)
end

function HitboxService.KnitInit()
	for _, v in CollectionService:GetTagged("_RaycastHitboxV4Managed") do
		v:RemoveTag("_RaycastHitboxV4Managed")
	end

	WeaponService = Knit.GetService("WeaponService")
	DebounceService = Knit.GetService("DebounceService")
end

function HitboxService.KnitStart() end

return HitboxService
