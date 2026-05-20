local Knit = require(game.ReplicatedStorage.Packages.Knit)

local AlertService = Knit.CreateService({
	Name = "AlertService",
	Client = { Alerted = Knit.CreateSignal() },
})

--[[
    Mostrar mensagens de normal, erro, sucesso e aviso.
]]

function AlertService:AlertPlayer(Player: Player, Message: string, MessageType: string)
	AlertService.Client.Alerted:Fire(Player, Message, MessageType)
end

function AlertService:AlertPlayers(Players: { Player }, Message: string, MessageType: string)
	for _, Player in Players do
		AlertService.Client.Alerted:Fire(Player, Message, MessageType)
	end
end

function AlertService:AlertAll(Message: string, MessageType: string)
	AlertService.Client.Alerted:FireAll(Message, MessageType)
end

return AlertService
