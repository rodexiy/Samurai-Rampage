local Players = game:GetService("Players")

local BlinkClient = {}

local function getCharacter()
	local Character = script:FindFirstAncestorOfClass("Model")
	if Character then
		return Character
	end

	return Players.LocalPlayer.Character
end

function BlinkClient.Start()
	local Character = getCharacter()
	if not Character then
		return
	end

	local Folder = workspace:WaitForChild("FaceHeadFolder", 10)
	if not Folder then
		warn("[BlinkClient] FaceHeadFolder was not available.")
		return
	end

	local FaceHead = Folder:WaitForChild(Character.Name .. "FaceHead", 10)
	if not FaceHead then
		warn("[BlinkClient] FaceHead was not available for " .. Character.Name .. ".")
		return
	end

	local FaceHeadWeld = FaceHead:WaitForChild("FaceHeadWeld", 10)
	if not FaceHeadWeld then
		warn("[BlinkClient] FaceHeadWeld was not available for " .. Character.Name .. ".")
		return
	end

	FaceHead:GetPropertyChangedSignal("Parent"):Connect(function()
		if FaceHead.Parent and FaceHead.Parent ~= Folder then
			FaceHead.Parent = Folder
		end
	end)

	FaceHeadWeld:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not FaceHeadWeld.Enabled then
			FaceHeadWeld.Enabled = true
		end
	end)
end

return BlinkClient
