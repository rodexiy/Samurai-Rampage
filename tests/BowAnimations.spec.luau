-- CreateHarness loads the current BowController source with isolated dependencies.
return function(CreateHarness: (any) -> any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end

	local Playing = {}
	local Animator = {
		GetPlayingAnimationTracks = function(): { any }
			local Active = {}
			for _, Track in Playing do
				if Track.IsPlaying then
					table.insert(Active, Track)
				end
			end
			return Active
		end,
	}
	local Humanoid = { FindFirstChildWhichIsA = function(): any
		return Animator
	end }
	local Character = { FindFirstChildWhichIsA = function(): any
		return Humanoid
	end }
	local Harness = CreateHarness({ Character = Character })
	local function Track(Id: string, Tagged: boolean?): any
		local Value = {
			IsPlaying = true, Destroyed = false, Stopped = false,
			DestroyCount = 0, DestroyedWhilePlaying = false,
			Animation = { AnimationId = Id },
			GetAttribute = function(_Self: any, Name: string): boolean
				return Name == "RangedWeaponAnimation" and Tagged == true
			end,
		}
		function Value:Stop(Fade: number)
			self.Stopped = true
			self.IsPlaying = false
			self.Fade = Fade
		end
		function Value:Destroy()
			self.DestroyedWhilePlaying = self.DestroyedWhilePlaying or self.IsPlaying
			self.Destroyed = true
			self.DestroyCount += 1
			-- Match the bug: destroying the handle does not itself stop Animator playback.
		end
		return Value
	end

	local PoseId = Harness.GetId("Bow", "Pose")
	local AimId = Harness.GetId("Bow", "Hold")
	local MusketId = Harness.GetId("Tanegashima", "Pose")
	local Pose = Track(PoseId)
	local Aim = Track(AimId)
	local Sword = Track("rbxassetid://999999999")
	Playing = { Pose, Aim, Sword }
	Harness.SetTracks({ Pose = Pose, Hold = Aim })
	Harness.Stop(Character)
	Check(Pose.Stopped and Pose.Destroyed and Aim.Stopped and Aim.Destroyed, "Stop and destroy tracked bow animations")
	Check(not Pose.DestroyedWhilePlaying and not Aim.DestroyedWhilePlaying, "Stop playback before destroying the track handle")
	Check(Pose.Fade == 0 and Aim.Fade == 0, "Remove ranged animation weight immediately")
	Check(Pose.DestroyCount == 1 and Aim.DestroyCount == 1, "Do not destroy the same tracked/playing animation twice")
	Check(Harness.IsEmpty(), "Clear tracked references after stopping them")
	Check(Sword.IsPlaying and not Sword.Destroyed, "Preserve unrelated sword animation playback")

	local Orphan = Track(PoseId)
	Orphan:Destroy()
	local MusketOrphan = Track(MusketId)
	Playing = { Orphan, MusketOrphan, Sword }
	Harness.Stop(Character)
	Check(not Orphan.IsPlaying and Orphan.Stopped, "Recover a playing bow pose whose track reference was already destroyed")
	Check(MusketOrphan.Stopped and MusketOrphan.Destroyed, "Recover untracked Tanegashima animations too")
	Check(Sword.IsPlaying and not Sword.Stopped, "Orphan cleanup must leave the sword animation alone")

	local Tagged = Track("rbxassetid://888888888", true)
	local Normalized = Track("https://www.roblox.com/asset/?id=" .. assert(PoseId:match("%d+")))
	Playing = { Tagged, Normalized, Sword }
	Harness.Stop(Character)
	Check(Tagged.Stopped and Tagged.Destroyed, "Recover tagged ranged tracks even if their configured asset changed")
	Check(Normalized.Stopped and Normalized.Destroyed, "Match asset IDs across Roblox URL formats")
	Check(Sword.IsPlaying, "Keep unrelated animations after repeated cleanup")

	local PreviousCharacterPose = Track(PoseId)
	Harness.SetTracks({ Pose = PreviousCharacterPose })
	Harness.Stop(nil)
	Check(PreviousCharacterPose.Stopped and PreviousCharacterPose.Destroyed, "Clean tracked animations even after losing the character reference")
	Harness.Stop(Character)
	Check(Harness.IsEmpty() and Sword.IsPlaying, "Repeated cleanup is safe")

	return string.format("Bow animation lifecycle: %d checks passed", Checks)
end
