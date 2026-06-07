local Knit = require(game.ReplicatedStorage.Packages.Knit)

local AlertService = Knit.CreateService({
	Name = "AlertService",
	Client = { Alerted = Knit.CreateSignal() },
})

--[[
    Mostrar mensagens de normal, erro, sucesso e aviso.
]]

function AlertService:AlertPlayer(Player: Player, Message: string, MessageType: string?, Options: { [string]: any }?)
	AlertService.Client.Alerted:Fire(Player, Message, MessageType, Options)
end

function AlertService:AlertPlayers(Players: { Player }, Message: string, MessageType: string?, Options: { [string]: any }?)
	for _, Player in Players do
		AlertService.Client.Alerted:Fire(Player, Message, MessageType, Options)
	end
end

function AlertService:AlertAll(Message: string, MessageType: string?, Options: { [string]: any }?)
	AlertService.Client.Alerted:FireAll(Message, MessageType, Options)
end

return AlertService
