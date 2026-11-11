local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BowCursorController = Knit.CreateController({ Name = "BowCursorController" })

local Gui: ScreenGui
local Ring: Frame
local Outline: UIStroke
local ChargeBar: Frame
local Status: TextLabel
local Ammo: TextLabel

function BowCursorController:SetVisible(Visible: boolean)
	if Gui then
		Gui.Enabled = Visible
	end
end

function BowCursorController:Update(Position: Vector2, Elapsed: number?, ArrowCount: number, Config: any, AmmoCounts: { [string]: number }, Focused: boolean?)
	if not Gui then
		return
	end

	local Charge = Config.GetCharge(Elapsed or 0)
	local Exhaustion = math.clamp(((Elapsed or 0) - Config.FullChargeTime) / (Config.MaxHoldTime - Config.FullChargeTime), 0, 1)
	local Size = 22 - Charge * 7 + Exhaustion * 5
	if Config.IsFirearm then
		local Camera = workspace.CurrentCamera
		local FocalLength = Camera.ViewportSize.Y / (2 * math.tan(math.rad(Camera.FieldOfView * 0.5)))
		Size = 2 * FocalLength * math.tan(math.rad(Config.GetSpreadDegrees(Focused)))
		Exhaustion = 0
	end
	Ring.Position = UDim2.fromOffset(Position.X, Position.Y)
	Ring.Size = UDim2.fromOffset(Size, Size)
	Outline.Color = if ArrowCount <= 0 then Color3.fromRGB(220, 85, 70)
		else Color3.fromRGB(235, 225, 200):Lerp(Color3.fromRGB(230, 100, 65), Exhaustion)
	ChargeBar.Size = UDim2.fromScale(Charge, 1)
	local ChargeFrame = ChargeBar.Parent :: Frame
	ChargeFrame.Visible = not Config.IsFirearm
	ChargeBar.BackgroundColor3 = Outline.Color
	Status.Text = if Elapsed then (if Charge < 1 then "DRAWING" else string.format("RELEASE  %.1fs", math.max(0, Config.MaxHoldTime - Elapsed))) else ""
	Ammo.Text = string.format("%d ARROWS", ArrowCount)
	if Config.IsFirearm then
		Status.Text = if Elapsed then "AIMING" else ""
		Ammo.Text = string.format("%d BULLETS / %d GUNPOWDER", AmmoCounts.IronBullet or 0, AmmoCounts.Gunpowder or 0)
	end
end

function BowCursorController.KnitStart()
	Gui = Instance.new("ScreenGui")
	Gui.Name = "BowCursor"
	Gui.IgnoreGuiInset = true
	Gui.ResetOnSpawn = false
	Gui.DisplayOrder = 20
	Gui.Enabled = false
	Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Ring = Instance.new("Frame")
	Ring.Name = "ImpactCursor"
	Ring.AnchorPoint = Vector2.new(0.5, 0.5)
	Ring.BackgroundTransparency = 1
	Ring.Size = UDim2.fromOffset(22, 22)
	Ring.Parent = Gui
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(1, 0)
	Corner.Parent = Ring
	Outline = Instance.new("UIStroke")
	Outline.Thickness = 1.5
	Outline.Parent = Ring

	local Bar = Instance.new("Frame")
	Bar.Name = "Charge"
	Bar.Position = UDim2.new(0.5, -25, 1, 12)
	Bar.Size = UDim2.fromOffset(50, 2)
	Bar.BackgroundColor3 = Color3.fromRGB(45, 42, 35)
	Bar.BorderSizePixel = 0
	Bar.Parent = Ring
	ChargeBar = Instance.new("Frame")
	ChargeBar.BorderSizePixel = 0
	ChargeBar.Size = UDim2.fromScale(0, 1)
	ChargeBar.Parent = Bar

	local function CreateLabel(Name: string, Y: number): TextLabel
		local Label = Instance.new("TextLabel")
		Label.Name = Name
		Label.AnchorPoint = Vector2.new(0.5, 0)
		Label.Position = UDim2.new(0.5, 0, 1, Y)
		Label.Size = UDim2.fromOffset(180, 16)
		Label.BackgroundTransparency = 1
		Label.FontFace = Font.fromId(12187366657)
		Label.TextSize = 10
		Label.TextColor3 = Color3.fromRGB(235, 225, 200)
		Label.TextStrokeTransparency = 0.5
		Label.Text = ""
		Label.Parent = Ring
		return Label
	end
	Status = CreateLabel("Status", 18)
	Ammo = CreateLabel("Ammo", 34)
end

return BowCursorController
