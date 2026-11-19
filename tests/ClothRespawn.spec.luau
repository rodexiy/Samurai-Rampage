-- Exercise production loading with a one-mesh memory budget and deterministic tasks.
return function(ProductionSource: string): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Checks = 0
	local function Signal(): any
		local Listeners = {}
		return {
			Connect = function(_Self: any, Callback: any): any
				Listeners[Callback] = true
				return { Disconnect = function()
					Listeners[Callback] = nil
				end }
			end,
			Fire = function(_Self: any, ...: any)
				for Callback in Listeners do
					Callback(...)
				end
			end,
		}
	end
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local Tasks = {}
	local function Queue(Callback: any)
		table.insert(Tasks, Callback)
	end
	local function Flush()
		local Count = 0
		while #Tasks > 0 do
			Count += 1
			assert(Count < 100, "Cloth preparation must not enter an endless retry loop")
			table.remove(Tasks, 1)()
		end
	end
	local function Character(Position: Vector3, Loaded: boolean): any
		local Changed = Signal()
		local Object = { PrimaryPart = { Position = Position }, Loaded = Loaded }
		function Object:GetAttribute(_Name: string): boolean
			return self.Loaded
		end
		function Object:GetAttributeChangedSignal(_Name: string): any
			return Changed
		end
		function Object:Ready()
			self.Loaded = true
			Changed:Fire()
		end

		return Object
	end
	local Live = 0
	local MemoryLimit = 1
	local Attempts = {}
	local function Mesh(Name: string, Position: Vector3): any
		local Object = {
			Name = Name, Position = Position, Size = Vector3.one, MeshSize = Vector3.one, MeshContent = Name,
			TextureContent = "OriginalTexture", Restores = 0, Parent = true, AncestryChanged = Signal(),
			DescendantAdded = Signal(), DescendantRemoving = Signal(),
		}
		function Object:IsA(Class: string): boolean
			return Class == "MeshPart"
		end
		function Object:IsDescendantOf(_Parent: any): boolean
			return true
		end
		function Object:QueryDescendants(_Class: string): { any }
			return {}
		end
		function Object:GetFullName(): string
			return self.Name
		end
		function Object:Clone(): any
			return { ClearAllChildren = function() end, Destroy = function() end }
		end
		function Object:ApplyMesh(_Original: any)
			self.Restores += 1
			self.TextureContent = "ChangedByApplyMesh"
		end

		return Object
	end
	local Near = Mesh("Near", Vector3.xAxis * 10)
	local Far = Mesh("Far", Vector3.xAxis * 20)
	local Distant = Mesh("Distant", Vector3.xAxis * 2000)
	local Roots = { Distant, Far, Near }
	local Added = Signal()
	local Player = { Character = Character(Vector3.zero, true), CharacterAdded = Signal() }
	function Player:GetAttribute(_Name: string): boolean
		return true
	end
	function Player:GetAttributeChangedSignal(_Name: string): any
		return Signal()
	end
	local Heartbeat = Signal()
	local Dependencies = {
		Players = { LocalPlayer = Player },
		RunService = { Heartbeat = Heartbeat },
		CollectionService = {
			GetTagged = function(): { any } return Roots end,
			GetInstanceAddedSignal = function(): any return Added end,
			GetInstanceRemovedSignal = function(): any return Signal() end,
		},
		AssetService = {
			CreateEditableMeshAsync = function(_Self: any, Content: string): any
				table.insert(Attempts, Content)
				assert(Live < MemoryLimit, "EditableMesh memory budget exhausted")
				Live += 1
				return {
					GetBones = function(): { any } return {} end,
					GetVertices = function(): { any } return {} end,
					GetFaces = function(): { any } return {} end,
					Destroy = function() Live -= 1 end,
				}
			end,
			CreateMeshPartAsync = function(): any return { Destroy = function() end } end,
		},
		Knit = { CreateController = function(Object: any): any return Object end },
		Geometry = { GetConnectedComponents = function(): { any } return {} end },
		Task = { spawn = Queue, defer = Queue },
	}
	local Source = ProductionSource
	for _, Name in { "AssetService", "CollectionService", "Players", "RunService" } do
		Source = string.gsub(Source, 'local ' .. Name .. ' = game:GetService%("' .. Name .. '"%)', "local " .. Name .. " = Dependencies." .. Name)
	end
	Source = string.gsub(Source, "local Knit = require%(ReplicatedStorage%.Packages%.Knit%)", "local Knit = Dependencies.Knit")
	Source = string.gsub(Source, "local ClothGeometry = require%(ReplicatedStorage%.Shared%.Utils%.ClothGeometry%)", "local ClothGeometry = Dependencies.Geometry")
	Source = string.gsub(Source, "Content.fromObject%(Editable%)", "Editable")
	Source = string.gsub(Source, "return ClothController%s*$", "return { Controller=ClothController, States=States, Failed=Failed, Distant=DistantMeshes }")
	local Module = Instance.new("ModuleScript")
	Module.Name = "ClothRespawnValidation"
	Module.Source = "return function(Dependencies)\nlocal task=Dependencies.Task\n" .. Source .. "\nend"
	Module.Parent = ReplicatedStorage
	local Test = require(ReplicatedStorage.ClothRespawnValidation)(Dependencies)
	local Success, Error = pcall(function()
		Test.Controller.KnitStart()
		Flush()
		Check(Attempts[1] == "Near" and Test.States[Near] ~= nil, "Prepare nearby cloth before farther meshes consume the memory budget")
		Check(Test.Failed[Far] == true and Test.States[Far] == nil, "Reproduce a cloth preparation failure with the initial character")
		Check(not table.find(Attempts, "Distant"), "Do not allocate buffers for distant cloth")
		local ExhaustedAttempts = #Attempts
		for _ = 1, 5 do
			Heartbeat:Fire(1)
			Flush()
		end
		Check(#Attempts == ExhaustedAttempts, "Memory exhaustion pauses allocation instead of repeating failing requests")
		Player.Character = Character(Vector3.xAxis * 19, true)
		Player.CharacterAdded:Fire(Player.Character)
		Flush()
		Check(Test.States[Far] ~= nil and not Test.Failed[Far], "Respawn retries the failed cloth using the new character position")
		Check(Test.States[Near] == nil and Live == 1, "Release unused old preparation buffers before preparing the new area")
		local CutState = Test.States[Far]
		CutState.Applied = true
		Player.Character = Character(Vector3.xAxis * 19, true)
		Player.CharacterAdded:Fire(Player.Character)
		Flush()
		Check(Test.States[Far] == CutState and Far.Restores == 0, "Respawn preserves existing nearby cloth cuts")
		Player.Character.PrimaryPart.Position = Vector3.xAxis * 1950
		Heartbeat:Fire(1)
		Flush()
		Check(Test.States[Far] == nil and Far.Restores == 1 and Far.TextureContent == "OriginalTexture",
			"Normal distance regeneration restores the cut mesh and its texture")
		Check(Test.States[Distant] ~= nil and Live == 1, "Freed memory prepares cloth in the new area")
		local Waiting = Character(Vector3.zero, false)
		Player.Character = Waiting
		Player.CharacterAdded:Fire(Waiting)
		Flush()
		Check(Test.States[Distant] ~= nil, "Wait until the replacement character finishes loading")
		Waiting:Ready()
		Flush()
		Check(Test.States[Near] ~= nil and Test.States[Distant] == nil, "Rebind cloth preparation when the new character becomes ready")
		Check(Live == 1, "Repeated respawns do not leak editable mesh buffers")
		MemoryLimit = 100
		for Index = 1, 20 do
			local Extra = Mesh("Extra" .. tostring(Index), Vector3.xAxis * (25 + Index))
			table.insert(Roots, Extra)
			Added:Fire(Extra)
		end
		Player.Character = Character(Vector3.zero, true)
		Player.CharacterAdded:Fire(Player.Character)
		Flush()
		Check(Live == 3, "A dense group of cloth does not allocate one editable mesh for every tagged object")
		Check(Test.States[Near] and Test.States[Far] and Test.States[Roots[4]], "The preparation cache contains the three nearest cloth meshes")
		local PreparedAttempts = #Attempts
		Heartbeat:Fire(1)
		Flush()
		Check(#Attempts == PreparedAttempts and Live == 3, "A full preparation cache does not keep requesting more buffers")
		Player.Character.PrimaryPart.Position = Vector3.xAxis * 800
		Heartbeat:Fire(1)
		Flush()
		Check(Live == 0, "Leaving a cloth cluster releases unused buffers well before the cut regeneration distance")
	end)
	Module:Destroy()
	assert(Success, tostring(Error))

	return tostring(Checks) .. " cloth respawn checks passed"
end
