local ContentProvider = game:GetService("ContentProvider")

repeat
	task.wait()
until game:IsLoaded()

local animations = {}

for _, v in game.ReplicatedStorage:GetDescendants() do
	if v:IsA("Animation") then
		table.insert(animations, v)
	end
end

ContentProvider:PreloadAsync(animations)
