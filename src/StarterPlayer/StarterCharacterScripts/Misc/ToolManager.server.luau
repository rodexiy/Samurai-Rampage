local Character = script.Parent.Parent.Parent

local CurrentTool = nil
local ActivatedConnection = nil

function toolEquipped(tool)
	if tool:GetAttribute("LeftHanded") then
		local RightGrip = Character:FindFirstChild("RightGrip", true)
		if RightGrip then
			RightGrip.Part0 = Character["Left Arm"]
		end
	end
end

function ToolUnequipped(tool) end

function toolActivated(tool) end

function unbindTool()
	if CurrentTool then
		if ActivatedConnection then
			ActivatedConnection:Disconnect()
		end
	end
end

function bindTool(tool)
	if CurrentTool then
		unbindTool()
	end

	CurrentTool = tool
	ActivatedConnection = tool.Activated:Connect(function()
		toolActivated(tool)
	end)
end

Character.ChildAdded:Connect(function(child)
	if not child:IsA("Tool") then
		return
	end

	toolEquipped(child)
	bindTool(child)
end)

Character.ChildRemoved:Connect(function(child)
	if not child:IsA("Tool") then
		return
	end
	ToolUnequipped(child)
	unbindTool()
end)
