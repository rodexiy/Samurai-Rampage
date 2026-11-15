-- Production drag controller with isolated mouse/touch signals and server responses.
return function(Controller: any, Context: any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	Context.Reset(2, 97)
	Context.Begin(false)
	Context.Move(Vector3.new(150, 50, 0))
	Check(
		Controller:IsDragging() and Context.Target.Stroke.Color == Color3.fromRGB(65, 220, 100),
		"Compatible stacks must show a valid existing green stroke"
	)
	Context.Release()
	local Request = Context.Sent[1]
	Check(
		Request and Request.Kind == "Merge" and Request.Name == "Source" and Request.Target == "Target",
		"Dragging a stack onto another must request a merge by identity"
	)
	Check(
		Request.Stack == 2 and Request.TargetStack == 97 and Request.Revision == 7,
		"Merge requests must include both observed quantities and the layout revision"
	)
	Check(Context.Placements == 0, "Merging must not optimistically move a stack into the occupied slot")
	Check(
		Controller:ConsumesClick(Context.Source) and Controller:ConsumesClick(Context.Target),
		"Releasing a merge drag must suppress selection clicks on both buttons"
	)
	Check(
		Context.Source.Visible
			and Context.Target.Stroke.Color == Context.OriginalColor
			and not Context.Target.Stroke.Enabled,
		"Finishing a drag must restore source visibility and the existing stroke"
	)

	Context.Reset(97, 5)
	Context.Begin(true)
	Context.Move(Vector3.new(150, 50, 0))
	Context.Release()
	Check(#Context.Sent == 1 and Context.Sent[1].Kind == "Merge", "Touch dragging must support partial stack merges")
	Check(
		Context.Sent[1].Stack == 97 and Context.Sent[1].TargetStack == 5,
		"Partial merges must send quantities for authoritative capacity calculation"
	)
	Context.Reset(2, 99)
	Context.Begin(false)
	Context.Move(Vector3.new(150, 50, 0))
	Check(Context.Target.Stroke.Color == Color3.fromRGB(240, 65, 65), "A full destination must show invalid feedback")
	Context.Release()
	Check(#Context.Sent == 0 and Context.Source.Visible, "Dropping onto a full stack must preserve the source")
	Context.Reset(2, 97, true)
	Context.Begin(false)
	Context.Move(Vector3.new(150, 50, 0))
	Context.Release()
	Check(#Context.Sent == 0, "Different persistent metadata must not merge despite matching item names")

	Context.Reset(2, 97)
	Context.Begin(false)
	Context.Move(Vector3.new(150, 50, 0))
	Context.UpdateTarget(99)
	Context.Release()
	Check(#Context.Sent == 0, "A destination filled during dragging must become invalid")
	Context.Reset(2, 97)
	Context.Begin(false)
	Context.Move(Vector3.new(150, 50, 0))
	Context.Move(Vector3.new(350, 150, 0))
	Context.Release()
	Check(
		#Context.Sent == 1 and Context.Sent[1].Kind == "Move" and Context.Sent[1].Target == nil,
		"Moving away from a merge target must preserve normal grid movement"
	)
	return tostring(Checks) .. " inventory merge mouse/touch checks passed"
end
