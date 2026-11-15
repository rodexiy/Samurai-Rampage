local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ClothService = Knit.CreateService({
	Name = "ClothService",
	Client = { Swing = Knit.CreateSignal() },
})

local WeaponService
local NextSwingId = 0
local ActiveSwings: { [Player]: () -> () } = {}

type Blade = { Base: Attachment, Tip: Attachment }

local function GetBlades(Character: Model, Side: string?): { Blade }
	local Assets = Character:FindFirstChild("Assets")
	local Weapons = Assets and Assets:FindFirstChild("Weapon")
	local Blades: { Blade } = {}
	if not Weapons then
		return Blades
	end

	for _, Name in { "Weapon", "LeftWeapon" } do
		if (Side == "Left" and Name == "Weapon") or (Side == "Right" and Name == "LeftWeapon") then
			continue
		end

		local Weapon = Weapons:FindFirstChild(Name)
		if not Weapon then
			continue
		end

		for _, Trail in Weapon:QueryDescendants("Trail") :: { Trail } do
			if Trail.Name == "SwordTrail" and Trail.Attachment0 and Trail.Attachment1 then
				table.insert(Blades, { Base = Trail.Attachment0, Tip = Trail.Attachment1 })
			end
		end
	end

	return Blades
end

function ClothService:StartSwing(Character: Model, Duration: number, Side: string?): (() -> ())?
	local Owner = Players:GetPlayerFromCharacter(Character)
	if not Owner or Duration <= 0 or WeaponService:DidCancel(Character) then
		return nil
	end

	local Blades = GetBlades(Character, Side)
	if #Blades == 0 then
		return nil
	end

	local Previous = ActiveSwings[Owner]
	if Previous then
		Previous()
	end

	NextSwingId += 1
	local Id = NextSwingId
	local Connections: { RBXScriptConnection } = {}
	local Stopped = false
	local function Stop()
		if Stopped then
			return
		end
		Stopped = true

		for _, Connection in Connections do
			Connection:Disconnect()
		end
		ActiveSwings[Owner] = nil
		if Owner.Parent == Players then
			ClothService.Client.Swing:Fire(Owner, "Stop", Id, Character)
		end
	end

	ActiveSwings[Owner] = Stop
	for _, Attribute in WeaponService.CancelM1Attributes do
		table.insert(Connections, Character:GetAttributeChangedSignal(Attribute):Connect(function()
			if WeaponService:DidCancel(Character) then
				Stop()
			end
		end))
	end
	table.insert(Connections, Character.Destroying:Connect(Stop))
	task.delay(Duration, Stop)

	self.Client.Swing:Fire(Owner, "Start", Id, Character, workspace:GetServerTimeNow() + Duration, Blades)
	return Stop
end

function ClothService.KnitInit()
	WeaponService = Knit.GetService("WeaponService")
end

function ClothService.KnitStart()
	Players.PlayerRemoving:Connect(function(Player: Player)
		local Stop = ActiveSwings[Player]
		if Stop then
			Stop()
		end
	end)
end

return ClothService
