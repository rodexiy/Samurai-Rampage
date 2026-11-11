local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BowConfig = require(ReplicatedStorage.Shared.BowConfig)

-- Share focus settings with the bow; firearm settings live here.
local TanegashimaConfig: any = table.clone(BowConfig)
TanegashimaConfig.WeaponName = "Tanegashima"
TanegashimaConfig.IsFirearm = true
TanegashimaConfig.Ammunition = { Gunpowder = 1, IronBullet = 1 }
TanegashimaConfig.AmmoWarning = "You need gunpowder and an iron bullet to fire the Tanegashima."
TanegashimaConfig.ShotCooldown = 7
TanegashimaConfig.MinDrawTime = 0
TanegashimaConfig.AimTransitionTime = 0.12
TanegashimaConfig.MinSpeed = 2400
TanegashimaConfig.MaxSpeed = 2400
TanegashimaConfig.MinDamage = 3
TanegashimaConfig.MaxDamage = 65
-- Damage stays low nearby, then rises to full power over this distance range (studs).
TanegashimaConfig.CloseRangeDistance = 15
TanegashimaConfig.FullDamageDistance = 100
TanegashimaConfig.MaxDistance = 6000
TanegashimaConfig.MaxFlightTime = 8
TanegashimaConfig.SpreadDegrees = 0.75
TanegashimaConfig.FocusedSpreadDegrees = 0.375
TanegashimaConfig.SwayMaximumDegrees = 4
TanegashimaConfig.SwayHorizontalFrequency = 1.4
TanegashimaConfig.SwayVerticalFrequency = 1.1
TanegashimaConfig.CameraSwayScale = 0
TanegashimaConfig.ShotSound = "rbxassetid://258905365"
TanegashimaConfig.AimSound = "rbxassetid://619578856"
TanegashimaConfig.StopAimSound = "rbxassetid://619576578"
TanegashimaConfig.ReadySound = "rbxassetid://160608684"
TanegashimaConfig.MuzzleLightDuration = 0.08
TanegashimaConfig.DefaultEmitCount = 10
TanegashimaConfig.TracerLifetime = 0.3
TanegashimaConfig.TracerLength = 180
TanegashimaConfig.TracerWidth = 0.06
TanegashimaConfig.TracerColor = Color3.fromRGB(255, 230, 170)

-- Motor6D C0, relative to Right Arm while held and Torso while stowed.
TanegashimaConfig.HandPart = "Right Arm"
TanegashimaConfig.HandPosition = Vector3.zero
TanegashimaConfig.HandRotationDegrees = Vector3.zero
TanegashimaConfig.BackPart = "Torso"
TanegashimaConfig.BackPosition = Vector3.new(0.8, 1.5, 0.85)
TanegashimaConfig.BackRotationDegrees = Vector3.new(0, 0, 90)

TanegashimaConfig.Animations = {
	Pose = { Name = "Tanegashima Idle", Id = "rbxassetid://74556246588821" },
	Hold = { Name = "Tanegashima Aim Idle", Id = "rbxassetid://101002976026315" },
	Shot = { Name = "Tanegashima Shot", Id = "rbxassetid://72976780845517" },
}

local function GetOffset(Position: Vector3, Rotation: Vector3): CFrame
	return CFrame.new(Position)
		* CFrame.Angles(math.rad(Rotation.X), math.rad(Rotation.Y), math.rad(Rotation.Z))
end

function TanegashimaConfig.GetHandOffset(): CFrame
	return GetOffset(TanegashimaConfig.HandPosition, TanegashimaConfig.HandRotationDegrees)
end

function TanegashimaConfig.GetBackOffset(): CFrame
	return GetOffset(TanegashimaConfig.BackPosition, TanegashimaConfig.BackRotationDegrees)
end

function TanegashimaConfig.GetOrigin(Character: Model): Vector3?
	local Model = Character:FindFirstChild("BowModel")
	local Muzzle = Model and Model:FindFirstChild("Muzzle", true)
	return if Muzzle and Muzzle:IsA("Attachment") then Muzzle.WorldPosition else nil
end

function TanegashimaConfig.GetSway(Elapsed: number, Seed: number): Vector2
	local Phase = Seed * 0.017
	return Vector2.new(
		math.sin(Elapsed * TanegashimaConfig.SwayHorizontalFrequency + Phase),
		math.sin(Elapsed * TanegashimaConfig.SwayVerticalFrequency + Phase * 1.3)
	) * math.rad(TanegashimaConfig.SwayMaximumDegrees)
end

function TanegashimaConfig.GetCharge(Elapsed: number): number
	return math.clamp(Elapsed / TanegashimaConfig.FullChargeTime, 0, 1)
end

function TanegashimaConfig.GetDrawCameraSway(_Elapsed: number, _Seed: number): CFrame
	return CFrame.identity
end

function TanegashimaConfig.GetAimTarget(Origin: Vector3, AimPoint: Vector3, Elapsed: number, Seed: number): Vector3
	local Offset = AimPoint - Origin
	local Direction = if Offset.Magnitude > 0.01 then Offset.Unit else -Vector3.zAxis
	local Up = if math.abs(Direction:Dot(Vector3.yAxis)) > 0.999 then Vector3.zAxis else Vector3.yAxis
	local Sway = TanegashimaConfig.GetSway(Elapsed, Seed)
	local Aim = CFrame.lookAt(Vector3.zero, Direction, Up) * CFrame.Angles(Sway.Y, Sway.X, 0)

	return Origin + Aim.LookVector * math.clamp(Offset.Magnitude, 1, TanegashimaConfig.MaxDistance)
end

function TanegashimaConfig.GetSpreadDegrees(Focused: boolean?): number
	return if Focused then TanegashimaConfig.FocusedSpreadDegrees else TanegashimaConfig.SpreadDegrees
end

function TanegashimaConfig.GetVelocity(Origin: Vector3, AimPoint: Vector3, Elapsed: number, Seed: number, Focused: boolean?, SwaySeed: number?): Vector3
	local Direction = (TanegashimaConfig.GetAimTarget(Origin, AimPoint, Elapsed, SwaySeed or Seed) - Origin).Unit
	local Generator = Random.new(Seed)
	local Radius = math.sqrt(Generator:NextNumber()) * math.tan(math.rad(TanegashimaConfig.GetSpreadDegrees(Focused)))
	local Angle = Generator:NextNumber(0, math.pi * 2)
	local Up = if math.abs(Direction:Dot(Vector3.yAxis)) > 0.999 then Vector3.zAxis else Vector3.yAxis
	local Aim = CFrame.lookAt(Vector3.zero, Direction, Up)
	local Spread = Aim:VectorToWorldSpace(Vector3.new(math.cos(Angle) * Radius, math.sin(Angle) * Radius, -1))

	return Spread.Unit * TanegashimaConfig.MaxSpeed
end

function TanegashimaConfig.GetDamage(_Charge: number, Distance: number): number
	local Progress = math.clamp((Distance - TanegashimaConfig.CloseRangeDistance)
		/ (TanegashimaConfig.FullDamageDistance - TanegashimaConfig.CloseRangeDistance), 0, 1)
	local DamageScale = Progress * Progress * (3 - 2 * Progress)

	return TanegashimaConfig.MinDamage + (TanegashimaConfig.MaxDamage - TanegashimaConfig.MinDamage) * DamageScale
end

return TanegashimaConfig
