local RootPart = script.Parent.Parent.Parent:WaitForChild("HumanoidRootPart")

local LookAttachment = Instance.new("Attachment")
LookAttachment.Name = "LookAttachment"
LookAttachment.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
LookAttachment.Parent = RootPart

local AlignOrientation = Instance.new("AlignOrientation")
AlignOrientation.Enabled = false
AlignOrientation.Name = "LookAtMouse"
AlignOrientation.AlignType = Enum.AlignType.PrimaryAxisLookAt
AlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
AlignOrientation.Attachment0 = LookAttachment
AlignOrientation.Responsiveness = 200
AlignOrientation.MaxTorque = 20000
AlignOrientation.MaxAngularVelocity = 30
AlignOrientation.Parent = RootPart

local AlignPosition = Instance.new("AlignPosition")
AlignPosition.Enabled = false
AlignPosition.Name = "LockCharacterMouse"
AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
AlignPosition.Attachment0 = LookAttachment
AlignPosition.RigidityEnabled = true
AlignPosition.Parent = RootPart
