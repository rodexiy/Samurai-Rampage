-- Run the controllers with isolated services, input, and render-step dependencies.
return function(Transform: any, Deletion: any, Mobile: any, Context: any): string
	local Checks = 0
	local Service = Context.Service
	local Gizmo = Context.Gizmo
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local First = Context.CreateObject("First", 0)
	local Second = Context.CreateObject("Second", 12)
	local Success, Error = pcall(function()
		Transform:Toggle()
		Check(Transform:Start(First), "Select an object after explicitly activating Transform")
		Transform:SetMode("Rotate")
		Gizmo.Began:Fire(2)
		Gizmo.Dragged:Fire(2, 15)
		Check(Transform:Apply() and Transform:IsPending(), "Apply a changed object")
		Service.TransformResult:Fire(Context.TransformRequest.Id, true)
		Check(Transform:IsActive() and not Transform:IsPending() and Transform:GetAnchor() == nil,
			"A successful transform returns to selection without disabling the tool")
		Check(First.LocalTransparencyModifier == 0, "Restore the edited object's visibility")
		Check(Transform:Start(Second) and Transform:GetMode() == "Rotate", "Select the next object and preserve Rotate mode")
		local LastRequest = Context.TransformRequest
		Check(Transform:Apply() and Transform:IsActive() and Transform:GetAnchor() == nil
			and Context.TransformRequest == LastRequest, "Applying an unchanged object stays in selection without a request")
		Transform:Start(First)
		Transform:SetMode("Move")
		Gizmo.Began:Fire(1)
		Gizmo.Dragged:Fire(1, 1)
		Transform:Apply()
		Service.TransformResult:Fire(Context.TransformRequest.Id, false, "Blocked")
		Check(Transform:IsActive() and Transform:GetAnchor() ~= nil and not Transform:IsPending(), "A rejected edit remains editable")
		Transform:Cancel()
		Check(not Transform:IsActive() and First.LocalTransparencyModifier == 0, "Explicit cancellation still leaves the tool")

		Deletion:Toggle()
		Check(Deletion:IsActive() and Deletion:Delete(First), "Start deleting on desktop")
		First:Destroy()
		Service.DeletionResult:Fire(Context.DeleteRequest.Id, true)
		Check(Deletion:IsActive() and not Deletion:IsPending(), "A successful deletion keeps Delete active")
		Context.Target = Second
		Context.Input.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.None }, false)
		Check(Deletion:IsPending() and Context.DeleteRequest.PlacementId == "Second", "The next click deletes another object")
		Second:Destroy()
		Service.DeletionResult:Fire(Context.DeleteRequest.Id, true)
		Deletion:Stop()
		Check(not Deletion:IsActive(), "Delete can still be explicitly disabled")

		Context.Touch = true
		local Third = Context.CreateObject("Third", 24)
		local Fourth = Context.CreateObject("Fourth", 36)
		Check(Deletion:Start() and Mobile:Select(Third), "Activate Delete and select an object on touch")
		local Billboard = Context.PlayerGui:FindFirstChild("RealmMobileBillboard")
		Check(Billboard ~= nil and Billboard.Apply.Visible and not Billboard.Delete.Visible, "Touch selection stays in Delete confirmation mode")
		Deletion:Delete(Third)
		Third:Destroy()
		Service.DeletionResult:Fire(Context.DeleteRequest.Id, true)
		task.wait()
		Check(Deletion:IsActive() and Context.PlayerGui:FindFirstChild("RealmToolSelection") ~= nil,
			"After touch deletion, keep the tool and show how to select another object or close")
		Check(Mobile:Select(Fourth), "Select another touch deletion target")
		Billboard = Context.PlayerGui:FindFirstChild("RealmMobileBillboard")
		Check(Billboard ~= nil and Billboard.Apply.Visible and not Billboard.Delete.Visible, "The next touch target retains Delete mode")
		Mobile:Close()
		Check(not Deletion:IsActive() and Context.PlayerGui:FindFirstChild("RealmToolSelection") == nil, "Touch Close disables the persistent tool")

		Transform:Toggle()
		task.wait()
		Check(Context.PlayerGui:FindFirstChild("RealmToolSelection") ~= nil, "Touch Transform selection has an exit control")
		Check(Transform:Start(Fourth), "Select a touch transform target")
		task.wait()
		Transform:SetMode("Rotate")
		Gizmo.Began:Fire(2)
		Gizmo.Dragged:Fire(2, 15)
		Transform:Apply()
		Service.TransformResult:Fire(Context.TransformRequest.Id, true)
		task.wait()
		Check(Transform:IsActive() and Transform:GetAnchor() == nil
			and Context.PlayerGui:FindFirstChild("RealmTransformControls") == nil
			and Context.PlayerGui:FindFirstChild("RealmToolSelection") ~= nil,
			"After Apply on touch, replace object controls with persistent tool selection")
		local Fifth = Context.CreateObject("Fifth", 48)
		Check(Transform:Start(Fifth) and Transform:GetMode() == "Rotate", "The next touch transform retains Rotate mode")
		task.wait()
		Mobile:Close()
		Check(not Transform:IsActive() and Fifth.LocalTransparencyModifier == 0, "Touch Close cancels the edit and restores visibility")

		Deletion:Start()
		Context.Open = false
		Context.Editor.Changed:Fire(false)
		task.wait()
		Check(not Deletion:IsActive() and Context.PlayerGui:FindFirstChild("RealmToolSelection") == nil, "Closing the editor clears persistent Delete")
		Context.Open = true
		Transform:Toggle()
		Transform:Start(Fifth)
		Context.Open = false
		Context.Editor.Changed:Fire(false)
		task.wait()
		Check(not Transform:IsActive() and Fifth.LocalTransparencyModifier == 0, "Closing the editor clears persistent Transform")
	end)

	Transform:Cancel()
	Deletion:Stop()
	Mobile:Close()
	assert(Success, Error)

	return tostring(Checks) .. " realm tool lifecycle checks passed"
end
