local Debris = game:GetService("Debris")
local Knit = require(game.ReplicatedStorage.Packages.Knit)


local CarryService = Knit.CreateService({
    Name = "CarryService",
    Client = {Carry = Knit.CreateSignal(), Release = Knit.CreateSignal()}
})


local CharacterService
local WeldService

function CarryService:Carry(Carrier : Model, Carried : Model)
    local Offset = CFrame.new(0, 0, 1)
    local CarriedOBV = Instance.new("ObjectValue", Carrier)
    CarriedOBV.Name = "Carried"
    CarriedOBV.Value = Carried
    local CarrierPlayer = game.Players:GetPlayerFromCharacter(Carrier)
    Carried.PrimaryPart.CFrame = Carrier.Torso.CFrame * Offset
    Carried:SetAttribute("Carried", true)
    Carried.Humanoid.PlatformStand = true
    --CharacterService:RemoveCollision(Carried)
	WeldService:WeldPartsWithMotor6D(Carrier.Torso, Carried.PrimaryPart, Offset, CFrame.new(0, 0, 0),"CarryWeld")

    if CarrierPlayer then
        self.Client.Carry:Fire(CarrierPlayer)
    end
end

function CarryService:Release(Carrier)
    local CarriedOBV = Carrier:FindFirstChild("Carried")
    if CarriedOBV then
        local Carried = CarriedOBV.Value
        if Carried then
            Carried.Humanoid.PlatformStand = false
            Carried:SetAttribute("Carried", false)
            CarriedOBV:Destroy()
            Carrier.Torso.CarryWeld:Destroy()
            local BodyVelocity = Instance.new("BodyVelocity", Carried.PrimaryPart)
            BodyVelocity.Velocity = Carrier.PrimaryPart.Velocity
            BodyVelocity.MaxForce = Vector3.new(10000, 10000, 10000)
            Debris:AddItem(BodyVelocity, 0.1)
        end
    end
end


function CarryService.KnitInit() 
    CharacterService = Knit.GetService("CharacterService")
    WeldService = Knit.GetService("WeldService")
    
    CarryService.Client.Release:Connect(function(Player : Player)
        local Character = Player.Character or Player.CharacterAdded:Wait()
        CarryService:Release(Character)
    end)
end

function CarryService.KnitStart() 
    
end

return CarryService