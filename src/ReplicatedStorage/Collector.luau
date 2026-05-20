local Collector = {}
Collector.__index = Collector

function Collector.new()
	return setmetatable({
		Connections = {},
	}, Collector)
end

function Collector:Add(connection)
	table.insert(self.Connections, connection)
end

function Collector:DisconnectAll()
	if not self.Connections then
		return
	end
	for _, connection in self.Connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		elseif typeof(connection) == "thread" then
			task.cancel(connection)
		end
		self.Connections[_] = nil
	end
end

function Collector:Destroy()
	self:DisconnectAll()
	setmetatable(self, nil)
	self = nil
end

return Collector
