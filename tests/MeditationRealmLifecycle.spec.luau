return function(CreateCase: (boolean, boolean) -> any, Flush: () -> ()): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function CheckStopped(Case: any, Message: string)
		Flush()
		Check(Case.Character:GetAttribute("Meditating") == false, Message .. ": clear meditation state")
		Check(Case.Character:GetAttribute("TargetWalkSpeed") == 16, Message .. ": restore movement")
		Check(Case.State.AnimationStops == 1, Message .. ": stop the animation once")
		Check(Case.State.MenuCloses == 1, Message .. ": close the meditation menu once")
	end

	local Case = CreateCase(true, false)
	Case.Character:SetAttribute("Meditating", false)
	CheckStopped(Case, "Server ends meditation after teleport")
	Check(Case.State.RemoteCalls == 0, "Server cancellation must not echo another request")
	Case.Action.Stop()
	Check(Case.State.AnimationStops == 1, "Stopping again is idempotent")
	Case.Destroy()

	Case = CreateCase(true, false)
	Case.Character:SetAttribute("RealmTeleporting", true)
	Case.Character:SetAttribute("InRealm", true)
	CheckStopped(Case, "Entering the realm")
	Check(Case.State.RemoteCalls == 1 and Case.State.LastEnabled == false, "Entering also clears the server meditation session")
	Case.Destroy()

	Case = CreateCase(true, true)
	Case.Character:SetAttribute("RealmTeleporting", true)
	Case.Character:SetAttribute("InRealm", false)
	CheckStopped(Case, "Returning to the game world")
	Case.Destroy()

	Case = CreateCase(true, true)
	Case.Character:SetAttribute("Meditating", false)
	Case.Action.callback(Enum.UserInputState.Begin)
	CheckStopped(Case, "Exit input after server cancellation")
	Case.Destroy()

	Case = CreateCase(true, true)
	Case.Character:SetAttribute("Meditating", false)
	Flush()
	Case.Character:SetAttribute("InRealm", false)
	CheckStopped(Case, "Server cancellation followed by realm state replication")
	Case.Destroy()

	Case = CreateCase(true, false)
	Case.Action.callback(Enum.UserInputState.Begin)
	CheckStopped(Case, "Normal meditation exit")
	Check(Case.State.RemoteCalls == 1, "Normal exit sends one stop request")
	Case.Destroy()

	Case = CreateCase(false, false)
	Case.Character:SetAttribute("InRealm", true)
	Flush()
	Check(Case.State.AnimationStops == 0 and Case.State.MenuCloses == 0, "An idle character changing realms does not close unrelated UI")
	Case.Destroy()

	Case = CreateCase(false, true)
	Case.Character:SetAttribute("RealmEditing", true)
	Case.Action.callback(Enum.UserInputState.Begin)
	Flush()
	Check(not Case.Character:GetAttribute("Meditating") and Case.State.RemoteCalls == 0,
		"Direct meditation actions cannot start while editing the realm")
	Case.Destroy()

	return tostring(Checks) .. " meditation realm lifecycle checks passed"
end
