local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.DoorConfig)

local DoorController = Knit.CreateController({ Name = "DoorController" })

type DoorRecord = {
	Motion: string?,
	StartedAt: number?,
	Tween: Tween?,
	StateConnection: RBXScriptConnection?,
	BrokenConnection: RBXScriptConnection?,
}

type DoorMotion = {
	Start: CFrame,
	Target: CFrame,
	StartedAt: number,
	Duration: number,
}

local PANEL_TAG = "DoorPanel"
local Doors: { [Model]: DoorRecord } = {}

local function DecodeMotion(Motion: string): DoorMotion?
	local Success, Result = pcall(function(): DoorMotion
		local Data = HttpService:JSONDecode(Motion)
		assert(type(Data.StartedAt) == "number" and type(Data.Duration) == "number", "Invalid door motion timing")

		return {
			Start = CFrame.new(table.unpack(Data.Start)),
			Target = CFrame.new(table.unpack(Data.Target)),
			StartedAt = Data.StartedAt,
			Duration = Data.Duration,
		}
	end)

	return if Success then Result else nil
end

function DoorController:BindDoor(Object: Instance): DoorRecord?
	if not Object:IsA("Model") or Object:GetAttribute("DoorBroken") then
		return nil
	end

	if Doors[Object] then
		return Doors[Object]
	end

	local Record: DoorRecord = {}
	Doors[Object] = Record
	Record.BrokenConnection = Object:GetAttributeChangedSignal("DoorBroken"):Connect(function()
		if Object:GetAttribute("DoorBroken") then
			self:RemoveDoor(Object)
		end
	end)
	Record.StateConnection = Object:GetAttributeChangedSignal("DoorMotion"):Connect(function()
		local Motion = Object:GetAttribute("DoorMotion")
		if typeof(Motion) == "string" then
			self:ApplyMotion(Object, Motion, true)
		end
	end)

	local Motion = Object:GetAttribute("DoorMotion")
	if typeof(Motion) == "string" then
		self:ApplyMotion(Object, Motion, false)
	end

	return Record
end

function DoorController:ApplyMotion(Door: Model?, Motion: string, Animate: boolean)
	if not Door or not Door.Parent or Door:GetAttribute("DoorBroken") then
		return
	end

	local Record = Doors[Door] or self:BindDoor(Door)
	if not Record or Record.Motion == Motion then
		return
	end

	local State = DecodeMotion(Motion)
	if not State or (Record.StartedAt and State.StartedAt < Record.StartedAt) then
		return
	end

	Record.Motion = Motion
	Record.StartedAt = State.StartedAt
	self:AnimateDoor(Door, State.Start, State.Target, State.StartedAt, if Animate then State.Duration else 0)
end

function DoorController:RemoveDoor(Object: Instance)
	if not Object:IsA("Model") then
		return
	end

	local Record = Doors[Object]
	if not Record then
		return
	end

	Doors[Object] = nil
	if Record.Tween then
		Record.Tween:Cancel()
	end

	-- Streaming out can remove the tag before the instance is destroyed.
	if Record.StateConnection then
		Record.StateConnection:Disconnect()
	end
	if Record.BrokenConnection then
		Record.BrokenConnection:Disconnect()
	end
end

function DoorController:PlayBreakEffect(Door: Model?)
	if not Door or not Door.Parent then
		return
	end

	self:RemoveDoor(Door)
	local Root = Door.PrimaryPart or Door:FindFirstChildWhichIsA("BasePart", true)
	if not Root then
		return
	end

	local Sound = Instance.new("Sound")
	Sound.Name = "DoorBreakSound"
	Sound.SoundId = Config.BreakSound
	Sound.Volume = 1
	Sound.RollOffMinDistance = 5
	Sound.RollOffMaxDistance = 100
	Sound.Parent = Root
	Sound.Ended:Once(function()
		Sound:Destroy()
	end)
	Debris:AddItem(Sound, 15)
	Sound:Play()
end

local function PlaySound(Door: Model)
	local Part = Door.PrimaryPart or Door:FindFirstChildWhichIsA("BasePart", true)
	if not Part then
		return
	end

	local Sound = Part:FindFirstChild("DoorSound") :: Sound?
	if not Sound then
		Sound = Instance.new("Sound")
		Sound.Name = "DoorSound"
		Sound.Parent = Part
	end

	Sound.RollOffMaxDistance = 100
	Sound.Volume = 0.3
	Sound.SoundId = "rbxassetid://115359467353541"
	Sound:Play()
end

function DoorController:AnimateDoor(
	Door: Model?,
	StartCFrame: CFrame,
	TargetCFrame: CFrame,
	StartedAt: number,
	Duration: number
)
	-- Streamed-out doors restore their saved target when their tag loads again.
	if not Door or not Door.Parent or Door:GetAttribute("DoorBroken") then
		return
	end

	local Record = self:BindDoor(Door)
	if not Record then
		return
	end

	if Record.Tween then
		Record.Tween:Cancel()
	end

	if Duration <= 0 then
		Door:PivotTo(TargetCFrame)
		return
	end

	local Elapsed = math.clamp(workspace:GetServerTimeNow() - StartedAt, 0, Duration)
	if Elapsed >= Duration then
		Door:PivotTo(TargetCFrame)
		return
	end

	local Alpha = TweenService:GetValue(Elapsed / Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	Door:PivotTo(StartCFrame:Lerp(TargetCFrame, Alpha))

	local Progress = Instance.new("NumberValue")
	Progress.Value = Elapsed / Duration
	local Info = TweenInfo.new(Duration - Elapsed, Enum.EasingStyle.Linear)
	local Tween = TweenService:Create(Progress, Info, { Value = 1 })
	Record.Tween = Tween
	Progress.Changed:Connect(function(Value: number)
		if Door.Parent then
			local Eased = TweenService:GetValue(Value, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			Door:PivotTo(StartCFrame:Lerp(TargetCFrame, Eased))
		else
			Tween:Cancel()
		end
	end)
	Tween.Completed:Once(function()
		if Record.Tween == Tween then
			Record.Tween = nil
		end

		Progress:Destroy()
	end)

	Tween:Play()
	PlaySound(Door)
end

function DoorController.KnitStart()
	local DoorService = Knit.GetService("DoorService")
	DoorService.Moved:Connect(function(Door: Model?, Motion: string)
		DoorController:ApplyMotion(Door, Motion, true)
	end)
	DoorService.Broken:Connect(function(Door: Model?)
		DoorController:PlayBreakEffect(Door)
	end)

	CollectionService:GetInstanceAddedSignal(PANEL_TAG):Connect(function(Object: Instance)
		DoorController:BindDoor(Object)
	end)
	CollectionService:GetInstanceRemovedSignal(PANEL_TAG):Connect(function(Object: Instance)
		DoorController:RemoveDoor(Object)
	end)

	for _, Object in CollectionService:GetTagged(PANEL_TAG) do
		DoorController:BindDoor(Object)
	end
end

return DoorController
