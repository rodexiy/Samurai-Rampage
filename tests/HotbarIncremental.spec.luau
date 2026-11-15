-- Run with the production controller, cloned hotbar, and isolated player tools.
return function(Controller: any, Background: Frame, Context: any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local Apple = Context.AddTool("Apple", 0, 3)
	local Wood = Context.AddTool("WoodLog", 1, 2)
	task.wait(0.03)
	local Zero, One = Background["0"], Background["1"]
	local Cooldowns, Slots, Properties, Reconciles =
		Context.Cooldowns, Context.Slots, Context.Properties, Context.Reconciles
	Controller:LoadHotbar(false, false)
	Controller:LoadHotbar(false, false)
	Check(Context.Cooldowns == Cooldowns, "Unchanged slots must retain their cooldown listeners and animation")
	Check(Context.Properties == Properties, "Unchanged hotbar refreshes must not rewrite UI properties")
	Check(Background["0"] == Zero and Background["1"] == One, "Refreshing must retain slot instances")

	Slots = Context.Slots
	Apple:SetAttribute("Stack", 4)
	task.wait(0.03)
	Check(Zero.ItemAmount.Text == "x4", "Stack changes must update the affected label")
	Check(Context.Slots == Slots + 1, "A stack change must refresh only its slot")
	Check(One.ItemAmount.Text == "x2", "A stack change must preserve other slots")
	Check(Context.Cooldowns == Cooldowns, "A stack change must not rebind cooldown events")

	Context.Character:SetAttribute("AppleDebounceEndTick", workspace:GetServerTimeNow() + 1)
	task.wait(0.04)
	Check(Zero.Cooldown.Visible, "Cooldown events must animate their own slot")
	local EndTick = Zero.Cooldown:GetAttribute("EndTick")
	Cooldowns = Context.Cooldowns
	Controller:LoadHotbar(false, false)
	Check(
		Context.Cooldowns == Cooldowns and Zero.Cooldown:GetAttribute("EndTick") == EndTick,
		"Unrelated refreshes must not restart an active cooldown"
	)

	Apple.Parent = Context.Character
	task.wait(0.03)
	Check(
		Zero.HotbarIndex.TextColor3 == Color3.fromRGB(255, 183, 0),
		"Equipping must update the existing slot highlight"
	)
	Check(
		Context.Cooldowns == Cooldowns,
		"Moving a tool between backpack and character must preserve cooldown bindings"
	)
	Check(One.ItemAmount.Text == "x2", "Equipping must preserve the other slot")

	Reconciles = Context.Reconciles
	Apple:SetAttribute("HotbarIndex", 1)
	Wood:SetAttribute("HotbarIndex", 0)
	task.wait(0.03)
	Check(Context.Reconciles == Reconciles + 1, "A two-slot swap must batch its replicated attribute events")
	Check(Zero.ItemName.Text == "WoodLog" and One.ItemName.Text == "Apple", "Swapping must update both affected slots")
	Check(Background["0"] == Zero and Background["1"] == One, "Swapping must preserve slot instances")

	Slots = Context.Slots
	Wood:SetAttribute("Stack", 5)
	task.wait(0.03)
	Check(
		Zero.ItemAmount.Text == "x5" and Context.Slots == Slots + 1,
		"A moved tool must retain exactly one binding to its new slot"
	)
	Check(Context.Created == 0 and Context.Removed == 0, "Gameplay updates must never recreate hotbar buttons")
	return tostring(Checks) .. " incremental hotbar checks passed"
end
