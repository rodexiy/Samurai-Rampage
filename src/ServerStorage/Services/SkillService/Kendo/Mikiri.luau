local Mikiri = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

function Mikiri.Caller(Attacker: Model, Data: { any })
	print(Attacker, Data)
end

function Mikiri.Start() end

return Mikiri
