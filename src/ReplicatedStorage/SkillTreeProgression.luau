local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatProgression = require(ReplicatedStorage.Shared.StatProgression)

local Progression = {}

export type Node = { [string]: any }
export type Profile = { [string]: any }

function Progression.Index(Trees: { [string]: any }): { [string]: Node }
	local Nodes = {}
	local function Add(Node: Node, Previous: string)
		assert(not Nodes[Node.Name], "Duplicate skill tree node: " .. Node.Name)
		local Info = table.clone(Node)
		Info.Previous = Previous
		Info.Branches = nil
		Nodes[Node.Name] = Info

		for _, Branch in Node.Branches or {} do
			Add(Branch, Node.Name)
		end
	end

	for _, Tree in Trees do
		for _, Branch in Tree.Branches or {} do
			Add(Branch, Tree.Name)
		end
	end

	return Nodes
end

function Progression.GetLevel(Data: Profile, Stat: string): number
	local Entry = Data.Stats and Data.Stats[Stat]
	local Level = Entry and Entry.Level or 0

	return if typeof(Level) == "number" and Level == Level then math.clamp(math.floor(Level), 0, StatProgression.MaxLevel) else 0
end

function Progression.GetEarnedPoints(Data: Profile, Stat: string): number
	return Progression.GetLevel(Data, Stat) * StatProgression.PointsPerLevel
end

function Progression.GetPoints(Data: Profile, Stat: string, Nodes: { [string]: Node }): number
	local Spent = 0
	local Seen = {}
	for _, Name in Data.UnlockedNodes or {} do
		local Node = Nodes[Name]
		if Node and Node.Stat == Stat and not Seen[Name] then
			Spent += Node.PointsRequired
			Seen[Name] = true
		end
	end

	return math.max(0, Progression.GetEarnedPoints(Data, Stat) - Spent)
end

function Progression.CanUnlock(Data: Profile, Name: any, Nodes: { [string]: Node }): (boolean, string?)
	local Node = if typeof(Name) == "string" then Nodes[Name] else nil
	if not Node then
		return false, "Invalid skill."
	end

	local Unlocked = Data.UnlockedNodes or {}
	if table.find(Unlocked, Name) then
		return false, "Skill already unlocked."
	end
	if Node.Previous ~= Node.Stat and not table.find(Unlocked, Node.Previous) then
		return false, "Unlock the previous skill first."
	end
	if Node.ChoiceGroup then
		for _, Other in Unlocked do
			if Nodes[Other] and Nodes[Other].ChoiceGroup == Node.ChoiceGroup then
				return false, "The other preference is already selected. Reset this tree to change it."
			end
		end
	end
	if Node.RequiresAny then
		local HasPreference = false
		for _, Required in Node.RequiresAny do
			HasPreference = HasPreference or table.find(Unlocked, Required) ~= nil
		end
		if not HasPreference then
			return false, "Choose a preference first."
		end
	end
	for _, Required in Node.RequiresAll or {} do
		if not table.find(Unlocked, Required) then
			return false, "Unlock " .. Required .. " first."
		end
	end
	if Progression.GetPoints(Data, Node.Stat, Nodes) < Node.PointsRequired then
		return false, "Not enough " .. Node.Stat .. " points."
	end

	return true
end

function Progression.Reconcile(Data: Profile, Nodes: { [string]: Node }, Version: number, PermanentSkills: { string }?)
	Data.UnlockedNodes = Data.UnlockedNodes or {}
	Data.OtherSkills = Data.OtherSkills or {}
	if Data.SkillTreeVersion ~= Version then
		for _, Name in PermanentSkills or {} do
			if table.find(Data.UnlockedNodes, Name) and not table.find(Data.OtherSkills, Name) then
				table.insert(Data.OtherSkills, Name)
			end
		end
		Data.LegacySkillTree = Data.LegacySkillTree or {
			UnlockedNodes = table.clone(Data.UnlockedNodes),
			FreePoints = Data.FreePoints or 0,
			LegacySkillPointCredits = Data.LegacySkillPointCredits or 0,
		}
		Data.UnlockedNodes = {}
		Data.SkillTreeVersion = Version
	end

	local Previous = Data.UnlockedNodes
	Data.UnlockedNodes = {}
	Data.RetiredSkillNodes = Data.RetiredSkillNodes or {}
	-- Layout changes can put saved children before their new prerequisites.
	local Pending = table.clone(Previous)
	local Progress = true
	while Progress do
		Progress = false
		local Remaining = {}
		for _, Name in Pending do
			if Progression.CanUnlock(Data, Name, Nodes) then
				table.insert(Data.UnlockedNodes, Name)
				Progress = true
			else
				table.insert(Remaining, Name)
			end
		end
		Pending = Remaining
	end
	for _, Name in Pending do
		if typeof(Name) == "string" and not table.find(Data.UnlockedNodes, Name) and not table.find(Data.RetiredSkillNodes, Name) then
			table.insert(Data.RetiredSkillNodes, Name)
		end
	end

	Data.FreePoints = 0
	if Data.LegacyProgression then
		Data.LegacyProgression.MigrateSkills = false
	end
end

return Progression
