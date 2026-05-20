
local RealmControl = {};
RealmControl.__index = RealmControl;

function RealmControl.new(Realm : Model) 
    assert(Realm:FindFirstChild("Players"), string.format("Realm %s doesnt have a player folder", Realm.Name))
	local self = setmetatable({}, RealmControl);
    self.PlayersFolder = Realm:FindFirstChild("Players") :: Folder
    self.PlayerInRealm = 0
    self.PlayerChanged = Instance.new("BindableEvent")
    self.connections = {}

    table.insert(self.connections, self.PlayersFolder.ChildAdded:Connect(function()
        self.PlayerInRealm = #self.PlayersFolder:GetChildren()
        self.PlayerChanged:Fire(#self.PlayersFolder:GetChildren())
    end))

    table.insert(self.connections, self.PlayersFolder.ChildRemoved:Connect(function()
        self.PlayerInRealm = #self.PlayersFolder:GetChildren()
        self.PlayerChanged:Fire(#self.PlayersFolder:GetChildren())
    end))

    table.insert(self.connections, Realm.Destroying:Connect(function()
        self:Destroy()
        Realm = nil
    end))
    
	return self;
end

function RealmControl:Destroy()
    for _, conn : RBXScriptConnection in pairs(self.connections) do
        if conn and conn.Disconnect then
		    conn:Disconnect()
	    end
    end
    table.clear(self.connections)
end

return RealmControl;