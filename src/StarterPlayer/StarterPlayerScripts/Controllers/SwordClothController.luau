local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local SwordClothController = Knit.CreateController({ Name = "SwordClothController" })

local Player = Players.LocalPlayer
local ClothController

type Blade = { Base: Attachment, Tip: Attachment, PreviousBase: Vector3, PreviousTip: Vector3 }
type Swing = { Id: number, Character: Model, EndsAt: number, Blades: { Blade }, Cuts: any }
local CurrentSwing: Swing?
local RenderConnection: RBXScriptConnection?

local function StopSwing(Apply: boolean?)
	local Swing = CurrentSwing
	CurrentSwing = nil
	if RenderConnection then
		RenderConnection:Disconnect()
		RenderConnection = nil
	end
	if Swing and Apply ~= false then
		ClothController:CommitBladeCuts(Swing.Cuts)
	end
end

local function StepSwing()
	local Swing = CurrentSwing
	if not Swing then
		return
	end
	if Swing.Character ~= Player.Character or not Swing.Character.Parent then
		StopSwing(false)
		return
	end
	if workspace:GetServerTimeNow() >= Swing.EndsAt then
		StopSwing()
		return
	end

	for _, Blade in Swing.Blades do
		if not Blade.Base:IsDescendantOf(Swing.Character) or not Blade.Tip:IsDescendantOf(Swing.Character) then
			continue
		end

		local Base, Tip = Blade.Base.WorldPosition, Blade.Tip.WorldPosition
		ClothController:CollectBladeCuts(Swing.Cuts, Blade.PreviousBase, Blade.PreviousTip, Base, Tip)
		Blade.PreviousBase, Blade.PreviousTip = Base, Tip
	end
end

function SwordClothController:StartSwing(Id: number, Character: Model, EndsAt: number, Blades: { { Base: Attachment, Tip: Attachment } })
	if Player:GetAttribute("ClothCut") == false or Character ~= Player.Character or EndsAt <= workspace:GetServerTimeNow() then
		return
	end

	StopSwing()
	local Active: { Blade } = {}
	for _, Blade in Blades do
		if Blade.Base and Blade.Tip and Blade.Base:IsDescendantOf(Character) and Blade.Tip:IsDescendantOf(Character) then
			table.insert(Active, {
				Base = Blade.Base, Tip = Blade.Tip,
				PreviousBase = Blade.Base.WorldPosition, PreviousTip = Blade.Tip.WorldPosition,
			})
		end
	end
	if #Active == 0 then
		return
	end

	CurrentSwing = { Id = Id, Character = Character, EndsAt = EndsAt, Blades = Active, Cuts = {} }
	RenderConnection = RunService.PreRender:Connect(StepSwing)
end

function SwordClothController.KnitInit()
	ClothController = Knit.GetController("ClothController")
end

function SwordClothController.KnitStart()
	Knit.GetService("ClothService").Swing:Connect(function(Action: string, Id: number, Character: Model, EndsAt: number?, Blades: any)
		if Action == "Start" and EndsAt and Blades then
			SwordClothController:StartSwing(Id, Character, EndsAt, Blades)
		elseif Action == "Stop" and CurrentSwing and CurrentSwing.Id == Id then
			StopSwing()
		end
	end)
	Player.CharacterRemoving:Connect(function()
		StopSwing(false)
	end)
	Player:GetAttributeChangedSignal("ClothCut"):Connect(function()
		if Player:GetAttribute("ClothCut") == false then
			StopSwing(false)
		end
	end)
end

return SwordClothController
