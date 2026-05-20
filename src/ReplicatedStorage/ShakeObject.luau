	local RunService = game:GetService("RunService")

	return function(Object: Model)

		local originalPivot = Object:GetPivot()
		local _, size = Object:GetBoundingBox()
		local height = size.Y

		local magnitude = math.clamp(height * 0.03, 0.15, 0.4)

		local duration = 0.2
		local frequency = 30
		local elapsed = 0

		if Object:GetAttribute("Shaking") then return end
		Object:SetAttribute("Shaking", true)

		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if not Object:IsDescendantOf(workspace) then
				conn:Disconnect()
				return
			end

			elapsed += dt
			if elapsed >= duration then
				conn:Disconnect()
				Object:PivotTo(originalPivot)
				Object:SetAttribute("Shaking", nil)
				return
			end

			local t = elapsed * frequency
			local offset = Vector3.new(
				math.sin(t * 13) * magnitude,
				0,
				math.cos(t * 11) * magnitude
			)

			Object:PivotTo(originalPivot * CFrame.new(offset))
		end)
	end