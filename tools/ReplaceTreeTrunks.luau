-- Paste into Studio's Command Bar in Edit mode.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")

-- All 12 imported trunks are rotated 180 degrees around local Y relative to Export.
local MeshRotation = CFrame.Angles(0, math.pi, 0)
local RotationAttribute = "TreeTrunkAppliedMeshRotation"

assert(not RunService:IsRunning(), "Execute na Command Bar em modo de edicao.")

local SourceFolder = workspace:FindFirstChild("TreesToExport")
local Imported = SourceFolder and SourceFolder:FindFirstChild("Imported")
assert(Imported, "Workspace.TreesToExport.Imported nao foi encontrada.")

local Templates: { [string]: MeshPart } = {}
for _, Part in Imported:QueryDescendants("MeshPart") :: { MeshPart } do
	if Part.Name:match("^Trunk_%d+$") then
		assert(not Templates[Part.Name], "Tronco novo duplicado: " .. Part.Name)
		Templates[Part.Name] = Part
	end
end

local Targets: { MeshPart } = {}
for _, Part in workspace:QueryDescendants("MeshPart") :: { MeshPart } do
	if Part.Name:match("^Trunk_%d+$") and not Part:IsDescendantOf(SourceFolder) then
		assert(Templates[Part.Name], "Falta um tronco novo para " .. Part:GetFullName())
		table.insert(Targets, Part)
	end
end
assert(#Targets > 0, "Nenhum Trunk_xx encontrado fora de TreesToExport.")

local function ReplaceTrunk(Trunk: MeshPart, Template: MeshPart)
	local PreviousRotation = Trunk:GetAttribute(RotationAttribute) or CFrame.identity
	assert(typeof(PreviousRotation) == "CFrame", "Rotacao registrada invalida em " .. Trunk:GetFullName())
	local Alignment = if PreviousRotation == MeshRotation then CFrame.identity else PreviousRotation:Inverse() * MeshRotation
	local Size = Trunk.Size
	local Frame = Trunk.CFrame * Alignment
	local PivotOffset = Alignment:Inverse() * Trunk.PivotOffset
	local Color = Trunk.Color
	local Texture = Trunk.TextureContent
	local RenderFidelity = Trunk.RenderFidelity

	-- Keep the existing instance, including SurfaceAppearance, children and references.
	Trunk:ApplyMesh(Template)
	Trunk.Size = Size
	Trunk.PivotOffset = PivotOffset
	Trunk.CFrame = Frame
	Trunk.Color = Color
	Trunk.TextureContent = Texture
	Trunk.RenderFidelity = RenderFidelity
	Trunk:SetAttribute(RotationAttribute, MeshRotation)
end

local Recording = ChangeHistoryService:TryBeginRecording("ReplaceTreeTrunks", "Substituir troncos das arvores")
local Backups: { [MeshPart]: MeshPart } = {}

local Success, Error = pcall(function()
	for _, Trunk in Targets do
		local Backup = Trunk:Clone()
		assert(Backup, "Nao foi possivel copiar " .. Trunk:GetFullName())
		Backups[Trunk] = Backup

		ReplaceTrunk(Trunk, Templates[Trunk.Name])
	end
end)

if not Success then
	-- The Command Bar may already own the recording, so restore our changes ourselves.
	for Trunk, Backup in Backups do
		Trunk:ApplyMesh(Backup)
		Trunk.Size = Backup.Size
		Trunk.PivotOffset = Backup.PivotOffset
		Trunk.CFrame = Backup.CFrame
		Trunk.Color = Backup.Color
		Trunk.TextureContent = Backup.TextureContent
		Trunk.RenderFidelity = Backup.RenderFidelity
		Trunk:SetAttribute(RotationAttribute, Backup:GetAttribute(RotationAttribute))
	end
end

for _, Backup in Backups do
	Backup:Destroy()
end

if Recording then
	ChangeHistoryService:FinishRecording(
		Recording,
		if Success then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
elseif Success then
	-- Command Bar executions can use Studio's existing undo recording.
	pcall(function()
		ChangeHistoryService:SetWaypoint("Substituir troncos das arvores")
	end)
end

assert(Success, tostring(Error))

print(string.format("%d troncos substituidos. Rotacao da malha corrigida; posicao, pivot, tamanho e aparencia preservados.", #Targets))
