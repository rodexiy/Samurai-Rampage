-- Run in Studio Edit with the production controller source.
return function(ProductionSource: string): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Checks = 0
	local function Signal(): any
		local Callbacks = {}
		return {
			Connect = function(_Self: any, Callback: any): any
				Callbacks[Callback] = true
				return { Disconnect = function()
					Callbacks[Callback] = nil
				end }
			end,
			Fire = function(_Self: any, ...: any)
				for Callback in Callbacks do
					Callback(...)
				end
			end,
		}
	end
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Folder = Instance.new("Folder")
	Folder.Name = "SwordClothValidation"
	Folder.Parent = workspace
	local Character = Instance.new("Model")
	Character.Parent = Folder
	local OtherCharacter = Instance.new("Model")
	OtherCharacter.Parent = Folder
	local Handle = Instance.new("Part")
	Handle.Anchored = true
	Handle.Parent = Character
	local Base, Tip = Instance.new("Attachment"), Instance.new("Attachment")
	Base.Position, Tip.Position = Vector3.new(0, -1, 0), Vector3.new(0, 1, 0)
	Base.Parent, Tip.Parent = Handle, Handle

	local Attributes = {}
	local SettingChanged = Signal()
	local Player = {
		Character = Character, CharacterRemoving = Signal(),
		GetAttribute = function(_Self: any, Name: string): any return Attributes[Name] end,
		GetAttributeChangedSignal = function(_Self: any, _Name: string): any return SettingChanged end,
	}
	local Remote, PreRender = Signal(), Signal()
	local Clock = 100
	local Calls = {}
	local Commits = {}
	local Dependencies = {
		Players = { LocalPlayer = Player },
		RunService = { PreRender = PreRender },
		Workspace = { GetServerTimeNow = function(): number return Clock end },
		Knit = {
			CreateController = function(Controller: any): any return Controller end,
			GetService = function(_Name: string): any return { Swing = Remote } end,
			GetController = function(_Name: string): any
				return {
					CollectBladeCuts = function(_Self: any, Batch: any, A: Vector3, B: Vector3, C: Vector3, D: Vector3)
						table.insert(Calls, { A, B, C, D })
						Batch.Marked = true
					end,
					CommitBladeCuts = function(_Self: any, Batch: any)
						if Batch.Marked then
							table.insert(Commits, Batch)
						end
					end,
				}
			end,
		},
	}
	local Source = string.gsub(ProductionSource, "local Knit = require%(ReplicatedStorage%.Packages%.Knit%)", "local Knit = Dependencies.Knit")
	Source = string.gsub(Source, 'local Players = game:GetService%("Players"%)', "local Players = Dependencies.Players")
	Source = string.gsub(Source, 'local RunService = game:GetService%("RunService"%)', "local RunService = Dependencies.RunService")
	local Module = Instance.new("ModuleScript")
	Module.Name = "SwordClothControllerValidation"
	Module.Source = "return function(Dependencies)\nlocal workspace=Dependencies.Workspace\n" .. Source .. "\nend"
	Module.Parent = ReplicatedStorage
	local Controller = require(ReplicatedStorage.SwordClothControllerValidation)(Dependencies)
	Controller.KnitInit()
	Controller.KnitStart()
	local Blades = { { Base = Base, Tip = Tip } }
	local Success, Error = pcall(function()
		Remote:Fire("Start", 1, OtherCharacter, 101, Blades)
		Handle.CFrame += Vector3.xAxis
		PreRender:Fire()
		Check(#Calls == 0, "Another character's swing must not cut this client's cloth")
		Remote:Fire("Start", 2, Character, 99, Blades)
		PreRender:Fire()
		Check(#Calls == 0, "Expired swing windows must not begin cutting")

		local PreviousBase, PreviousTip = Base.WorldPosition, Tip.WorldPosition
		Remote:Fire("Start", 3, Character, 101, Blades)
		Handle.CFrame += Vector3.zAxis
		PreRender:Fire()
		Check(#Calls == 1 and Calls[1][1] == PreviousBase and Calls[1][2] == PreviousTip,
			"The owner's swing must retain the previous blade endpoints")
		Check(Calls[1][3] == Base.WorldPosition and Calls[1][4] == Tip.WorldPosition,
			"The blade sweep must end at the current endpoints")
		Check(#Commits == 0, "Frames must only collect cuts without editing the mesh")
		Remote:Fire("Stop", 2, Character)
		PreRender:Fire()
		Check(#Calls == 2, "A delayed stop from an older attack must not cancel the active swing")
		Remote:Fire("Stop", 3, Character)
		PreRender:Fire()
		Check(#Calls == 2, "The server's stop must end local cutting")
		Check(#Commits == 1, "The completed swing must commit its accumulated cuts exactly once")

		Remote:Fire("Start", 4, Character, 101, Blades)
		Clock = 102
		PreRender:Fire()
		Check(#Calls == 2, "The local window must expire even before a stop event arrives")
		Remote:Fire("Start", 5, Character, 103, Blades)
		Player.CharacterRemoving:Fire(Character)
		PreRender:Fire()
		Check(#Calls == 2, "Respawning must disconnect the active blade sweep")
		Remote:Fire("Start", 6, Character, 104, Blades)
		PreRender:Fire()
		Attributes.ClothCut = false
		SettingChanged:Fire()
		PreRender:Fire()
		Check(#Commits == 1 and #Calls == 3, "Disabling Cloth Cut must discard the pending swing")
		Remote:Fire("Start", 7, Character, 104, Blades)
		PreRender:Fire()
		Check(#Calls == 3, "Disabled Cloth Cut must ignore new swings")
	end)

	Player.CharacterRemoving:Fire(Character)
	Folder:Destroy()
	Module:Destroy()
	assert(Success, tostring(Error))
	return string.format("Sword cloth controller: %d checks passed", Checks)
end
