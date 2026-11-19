return function(Service: any): string
	local Checks = 0
	local Player, OtherPlayer = {}, {}
	local Realm, Replacement = Instance.new("Model"), Instance.new("Model")
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Counts(Undo: number, Redo: number)
		local ActualUndo, ActualRedo = Service:GetCounts(Player, Realm)
		Check(ActualUndo == Undo and ActualRedo == Redo, "History counts must match the cursor")
		Check(ActualUndo + ActualRedo <= 100, "Undo and redo share one 100-action limit")
	end

	local Success, Error = pcall(function()
		Counts(0, 0)
		Check(not Service:Apply(Player, Realm, "Undo", function(): (boolean, string?)
			error("Empty history must not invoke replay")
		end), "Reject empty undo")
		Check(not Service:Apply(Player, Realm, "Invalid", function(): (boolean, string?)
			error("Invalid direction must not invoke replay")
		end), "Reject invalid directions")

		local Original = { Id = 1, Record = { Name = "original" } }
		Service:Record(Player, Realm, Original)
		Original.Record.Name = "mutated"
		Check(Service:Apply(Player, Realm, "Undo", function(Action: any, Undo: boolean): (boolean, string?)
			Check(Undo and Action.Record.Name == "original", "Record an independent snapshot")
			return true
		end), "Undo the latest action")
		Counts(0, 1)
		Check(not Service:Apply(Player, Realm, "Redo", function(): (boolean, string?)
			return false, "blocked"
		end), "Replay can reject a transaction")
		Counts(0, 1)
		Check(Service:Apply(Player, Realm, "Redo", function(_Action: any, Undo: boolean): (boolean, string?)
			Check(not Undo, "Redo uses the forward direction")
			return true
		end), "Retry a failed redo")
		Counts(1, 0)

		for Id = 2, 101 do
			Service:Record(Player, Realm, { Id = Id })
		end
		Counts(100, 0)
		for Id = 101, 2, -1 do
			Check(Service:Apply(Player, Realm, "Undo", function(Action: any): (boolean, string?)
				Check(Action.Id == Id, "Undo in reverse order and discard the oldest action")
				return true
			end), "Undo each retained action")
		end
		Counts(0, 100)
		for Id = 2, 101 do
			Check(Service:Apply(Player, Realm, "Redo", function(Action: any): (boolean, string?)
				Check(Action.Id == Id, "Redo preserves original order")
				return true
			end), "Redo each retained action")
		end
		Counts(100, 0)
		Service:Apply(Player, Realm, "Undo", function(): (boolean, string?)
			return true
		end)
		Service:Record(Player, Realm, { Id = "branch" })
		Counts(100, 0)
		Check(not Service:Apply(Player, Realm, "Redo", function(): (boolean, string?)
			return true
		end),
			"A new action discards the redo branch")
		Check(Service:GetCounts(OtherPlayer, Realm) == 0, "Players have separate histories")
		Check(Service:GetCounts(Player, Replacement) == 0, "Reloading the realm clears its old history")
	end)

	Realm:Destroy()
	Replacement:Destroy()
	assert(Success, Error)

	return tostring(Checks) .. " realm history checks passed"
end
