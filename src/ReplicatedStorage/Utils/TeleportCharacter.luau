local Players = game:GetService("Players")
return function(Character, Pivot: CFrame)
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player then
		Player:RequestStreamAroundAsync(Pivot.Position, 5)
	end
	Character:PivotTo(Pivot)
	local Head = Character:FindFirstChild("Head")
	local FaceHead = workspace.FaceHeadFolder:FindFirstChild(Character.Name .. "FaceHead")

	if FaceHead and Head then
		FaceHead:PivotTo(Head:GetPivot())
		local FaceHeadWeld = FaceHead:FindFirstChild("FaceHeadWeld")

		if FaceHeadWeld then
			FaceHeadWeld.Enabled = true
		end
	end

	Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
end
