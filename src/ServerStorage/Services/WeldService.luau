local Knit = require(game.ReplicatedStorage.Packages.Knit)
local WeldService = Knit.CreateService({
    Name = "WeldService",
    Client = {}
})


function WeldService:WeldPartsWithMotor6D(part0,part1,c0,c1, name : string?)
    local weld = Instance.new("Motor6D")
    weld.Name = name or "Weld"
    weld.Part0 = part0
    weld.Part1 = part1
    weld.C0 = c0
    weld.C1 = c1
    weld.Parent = part0
    return weld
end

function WeldService.KnitInit() end

function WeldService.KnitStart() end

return WeldService