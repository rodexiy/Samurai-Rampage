local Grapple = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DebounceService = Knit.GetService("DebounceService")
local StaminaService = Knit.GetService("StaminaService")
local RenderService = Knit.GetService("RenderService")

function Grapple.Grapple(Attacker: Model, Data: { any })
	local MouseHit = Data.MouseHit or Data.MouseCast

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Attacker, workspace.FaceHeadFolder }

	local Distance = (Attacker:GetPivot().Position - MouseHit.Position).Magnitude
	local Cast: RaycastResult = workspace:Raycast(
		Attacker:GetPivot().Position,
		CFrame.new(Attacker:GetPivot().Position, MouseHit.Position).LookVector * 100,
		Params
	)

	if not Cast then
		return
	end

	local GrappleCFrame = CFrame.new(Cast.Position, Cast.Position + Cast.Normal)

	StaminaService:RemoveStamina(Attacker, 10)
	DebounceService:AddDebounce(Attacker, "GrappleDebounce", 7.5, true)

	RenderService:RenderForAllPlayers("Grapple", "Grapple", { Character = Attacker, GrappleCFrame = GrappleCFrame })
end

function Grapple.Caller(Attacker: Model, Data: { any })
	if
		(not Data.MouseHit and not Data.MouseCast)
		or Attacker:GetAttribute("Stamina") < 10
		or DebounceService:HaveDebounce(Attacker, "GrappleDebounce")
	then
		return
	end

	Grapple.Grapple(Attacker, Data)
end

function Grapple.Start() end

return Grapple
