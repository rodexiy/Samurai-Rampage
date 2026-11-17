return function(Service: any, Context: any): string
	local Players = game:GetService("Players")
	local Checks = 0
	local Owners = {}
	local Characters = {}
	local ActiveTemplate = Context.Template

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Player(Id: number): any
		local Character = Instance.new("Model")
		local Root = Instance.new("Part")
		Root.Anchored = true
		Root.Parent = Character
		Character.PrimaryPart = Root
		Character.Parent = workspace
		table.insert(Characters, Character)

		local Result = { UserId = Id, Parent = Players, Character = Character }
		function Result:GetAttribute(_Name: string): any
			return nil
		end
		function Result:RequestStreamAroundAsync(_Position: Vector3, _Timeout: number)
			assert(Service:GetRealm(self):GetAttribute("TerrainLoaded"), "Stream only after loading terrain")
		end
		table.insert(Owners, Result)

		return Result
	end

	local function Join(Actions: { () -> () })
		local Done = Instance.new("BindableEvent")
		local Remaining = #Actions
		local Failure: string?
		for _, Action in Actions do
			task.spawn(function()
				local Success, Error = pcall(Action)
				if not Success then
					Failure = tostring(Error)
				end
				Remaining -= 1
				if Remaining == 0 then
					Done:Fire()
				end
			end)
		end
		if Remaining > 0 then
			Done.Event:Wait()
		end
		Done:Destroy()
		assert(not Failure, Failure)
	end

	local Success, Error = pcall(function()
		local First = Player(-9001)
		local Second = Player(-9002)
		local Realm = Service:LoadRealm(First)
		assert(Realm, "Initial realm load failed")
		Check(Realm:GetAttribute("Loaded") and Realm:GetAttribute("TerrainLoaded"), "Realm readiness includes native terrain")
		Check(Service:LoadRealm(First) == Realm, "Reuse an already loaded realm")
		Check(Realm.PrimaryPart.Position == Realm:GetAttribute("TerrainCenter"), "Keep model and odd-sized terrain aligned")
		Check(Realm.Removable.Trees:FindFirstChild("Removed") == nil, "Apply saved resource removals after loading terrain")
		Check(Realm.Removable.Trees.Remaining:GetAttribute("RealmId") == First.UserId, "Preserve resource ownership")

		First.Character:SetAttribute("Meditating", true)
		Service:TeleportPlayer(First)
		Check(First.Character.Parent == Realm.Players and First.Character:GetAttribute("InRealm"), "Teleport only into a completed realm")
		Check(First.Character:GetAttribute("Meditating") == false, "Stop server meditation when entering the realm")
		Check(typeof(First.Character:GetAttribute("RealmMeditateCFrame")) == "CFrame", "Preserve the return position")
		First.Character:SetAttribute("Meditating", true)
		Service:TeleportPlayer(First)
		Check(First.Character:GetAttribute("InRealm") == false and First.Character.Parent == (workspace:FindFirstChild("Entity") or workspace), "Return the player outside the realm")
		Check(First.Character:GetAttribute("Meditating") == false, "Stop server meditation when returning to the world")
		Service:DestroyRealmByPlayer(First)
		Check(Service:GetRealm(First) == nil, "Unload terrain and release the realm")

		Realm = Service:LoadRealm(First)
		assert(Realm, "Realm reload failed")
		Join({
			function()
				Service:DestroyRealmByPlayer(First)
			end,
			function()
				local Other = Service:LoadRealm(Second)
				Check(Other ~= nil and Other:GetAttribute("PlotOffset") == 2, "Do not reuse a plot while its terrain is unloading")
			end,
		})
		Service:DestroyRealmByPlayer(Second)
		Realm = Service:LoadRealm(First)
		Check(Realm ~= nil and Realm:GetAttribute("PlotOffset") == 1, "Reuse a plot after terrain restoration finishes")
		Service:DestroyRealmByPlayer(First)

		local Departing = Player(-9003)
		Join({
			function()
				Check(Service:LoadRealm(Departing) == nil, "Cancel a realm load when its owner leaves")
			end,
			function()
				Departing.Parent = nil
				Service:DestroyRealmByPlayer(Departing)
			end,
		})
		Check(Service:GetRealm(Departing) == nil, "Remove cancelled realm bookkeeping")

		Context.Template:SetAttribute("TerrainPreset", "MissingPreset")
		Check(Service:LoadRealm(First) == nil, "A missing preset does not mark the realm loaded")
		Context.Template:SetAttribute("TerrainPreset", nil)
		Realm = Service:LoadRealm(First)
		Check(Realm ~= nil and Realm:GetAttribute("PlotOffset") == 1, "Failed setup does not leak the reserved plot")
		Service:DestroyRealmByPlayer(First)

		if Context.RealTemplate then
			local RealTemplate = Context.RealTemplate:Clone()
			ActiveTemplate.Parent = nil
			RealTemplate.Parent = Context.Assets
			ActiveTemplate = RealTemplate
			local Preset = RealTemplate:FindFirstChild("MentalRealm") :: TerrainRegion
			local Spawn = RealTemplate.Structures.Spawn:GetPivot()
			local SourceCenter = Preset:GetAttribute("SourceCenter") :: Vector3

			Realm = Service:LoadRealm(First)
			assert(Realm, "Embedded MentalRealm load failed")
			Check(Realm:GetAttribute("TerrainLoaded") == true, "Load the actual embedded MentalRealm preset")
			Check(Realm.PrimaryPart == nil, "Support a Folder template without a Baseplate")
			Check(Realm:FindFirstChildWhichIsA("TerrainRegion") == nil, "Keep native preset data in ServerStorage")
			local RelativeSpawn = Realm.Structures.Spawn:GetPivot().Position - Realm:GetAttribute("TerrainCenter")
			Check((RelativeSpawn - (Spawn.Position - SourceCenter)).Magnitude < 0.01, "Preserve source-space structure placement on the actual island")
			Service:DestroyRealmByPlayer(First)
			Check(Service:GetRealm(First) == nil, "Unload the actual chunked MentalRealm island")
		end
	end)

	Context.Template:SetAttribute("TerrainPreset", nil)
	for _, Owner in Owners do
		Service:DestroyRealmByPlayer(Owner)
	end
	for _, Character in Characters do
		Character:Destroy()
	end
	if ActiveTemplate ~= Context.Template then
		ActiveTemplate:Destroy()
		Context.Template.Parent = Context.Assets
	end
	assert(Success, tostring(Error))

	return tostring(Checks) .. " realm terrain integration checks passed"
end
