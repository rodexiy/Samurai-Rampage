-- Real spatial queries, with deterministic pre-impact motion and no running game required.
return function(Source: string, Config: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Fixture = Instance.new("Folder")
	Fixture.Parent = workspace
	local Ground = Instance.new("Part")
	Ground.Anchored = true
	Ground.Size = Vector3.new(30, 1, 30)
	Ground.Position = Vector3.new(30000, 20000, 30000)
	Ground.Parent = Fixture
	local Character = Instance.new("Model")
	Character.Parent = Fixture
	local Root = Instance.new("Part")
	Root.Anchored = true
	Root.CanCollide = false
	Root.Position = Ground.Position + Vector3.new(0, 5, 0)
	Root.Parent = Character
	Character.PrimaryPart = Root
	local Body = Instance.new("Part")
	Body.CanCollide = false
	Body.Size = Vector3.new(2, 2, 1)
	Body.Position = Root.Position
	Body.Parent = Character
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local Signal = {
		Connect = function(): any
			return { Disconnect = function() end }
		end,
	}
	local Added: ((Instance) -> ())?
	local Removed: ((Instance) -> ())?
	local AddedSignal = {
		Connect = function(_Self: any, Callback: (Instance) -> ())
			Added = Callback
		end,
	}
	local RemovedSignal = {
		Connect = function(_Self: any, Callback: (Instance) -> ())
			Removed = Callback
		end,
	}
	local Dependencies = {
		CollectionService = {
			GetTagged = function(): { Model }
				return { Character }
			end,
			GetInstanceAddedSignal = function(): any
				return AddedSignal
			end,
			GetInstanceRemovedSignal = function(): any
				return RemovedSignal
			end,
		},
		Config = Config,
		Knit = {
			CreateController = function(Controller: any): any
				return Controller
			end,
		},
		RunService = { PreSimulation = Signal, PostSimulation = Signal },
	}
	Source =
		Source:gsub('local RunService = game:GetService%("RunService"%)', "local RunService = Dependencies.RunService")
	Source = Source:gsub(
		'local CollectionService = game:GetService%("CollectionService"%)',
		"local CollectionService = Dependencies.CollectionService"
	)
	Source = Source:gsub("local Knit = require%(ReplicatedStorage%.Packages%.Knit%)", "local Knit = Dependencies.Knit")
	Source = Source:gsub(
		"local Config = require%(ReplicatedStorage%.Shared%.RagdollConfig%)",
		"local Config = Dependencies.Config"
	)
	local Module = Instance.new("ModuleScript")
	Module.Source = "return function(Dependencies)\n" .. Source .. "\nend"
	Module.Parent = ReplicatedStorage
	local Controller = require(Module)(Dependencies)
	local function Prepare(Velocity: Vector3)
		Controller:Stop(Character)
		for _, Child in Body:GetChildren() do
			Child:Destroy()
		end
		Character:SetAttribute("Ragdoll", true)
		Body.Position = Ground.Position + Vector3.new(0, 4, 0)
		Body.AssemblyLinearVelocity = Velocity
		Controller:Start(Character)
		Controller:CaptureMotion()
		Body.Position = Ground.Position + Vector3.new(0, 1.5, 0)
	end
	local Success, Failure = pcall(function()
		Prepare(Vector3.new(0, -35, 0))
		Controller:Step()
		local Sound = Body:FindFirstChild("RagdollGroundImpact") :: Sound?
		Check(
			Sound ~= nil and table.find(Config.ImpactSounds, Sound.SoundId) ~= nil,
			"A falling ragdoll plays one of the four requested sounds on floor contact"
		)
		Controller:Step()
		Check(#Body:GetChildren() == 1, "Multiple body contacts in the cooldown do not stack sounds")
		Prepare(Vector3.zero)
		Controller:Step()
		Check(#Body:GetChildren() == 0, "A resting ragdoll stays silent")
		Prepare(Vector3.new(0, 20, 0))
		Controller:Step()
		Check(#Body:GetChildren() == 0, "Moving upward does not count as landing")
		Prepare(Vector3.new(0, -35, 0))
		Body.Position = Ground.Position + Vector3.new(0, 12, 0)
		Controller:CaptureMotion()
		Controller:Step()
		Check(#Body:GetChildren() == 0, "A falling body away from the floor stays silent")
		Prepare(Vector3.new(0, -35, 0))
		Character:SetAttribute("Ragdoll", false)
		Controller:Step()
		Check(#Body:GetChildren() == 0, "Getting up stops impact playback")

		Controller:Stop(Character)
		Character:SetAttribute("Ragdoll", true)
		Controller.KnitStart()
		local Add = assert(Added, "Entity additions must be observed")
		local Remove = assert(Removed, "Entity removals must be observed")
		local function Drop()
			for _, Child in Body:GetChildren() do
				Child:Destroy()
			end
			Body.Position = Ground.Position + Vector3.new(0, 4, 0)
			Body.AssemblyLinearVelocity = Vector3.new(0, -35, 0)
			Controller:CaptureMotion()
			Body.Position = Ground.Position + Vector3.new(0, 1.5, 0)
			Controller:Step()
		end
		Drop()
		Check(#Body:GetChildren() == 1, "An existing ragdolled Entity is tracked without being a Player")
		Remove(Character)
		Drop()
		Check(#Body:GetChildren() == 0, "Removing or streaming out an Entity stops its impact sounds")
		Add(Character)
		Drop()
		Check(#Body:GetChildren() == 1, "An Entity added or streamed back in resumes impact sounds")
		Remove(Character)
		Character:SetAttribute("Ragdoll", false)
		Add(Character)
		Character:SetAttribute("Ragdoll", true)
		task.wait()
		Drop()
		Check(#Body:GetChildren() == 1, "A future ragdoll on a tagged Entity also triggers sound")
	end)
	Controller:UnbindCharacter(Character)
	Fixture:Destroy()
	Module:Destroy()
	assert(Success, Failure)
	return "RagdollImpact: " .. Checks .. " checks passed"
end
