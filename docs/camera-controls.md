# Camera and movement controls

`CameraController:IsFacingCamera()` supplies the facing state used by dash. It includes
melee attack/block, ranged aim and target lock on T. Cursor position
alone does not determine whether the character is facing the camera.

Shift lock centers the cursor and applies the shoulder camera without forcing body
rotation toward the camera. The character keeps facing movement, and shift lock alone
uses the Forward dash animation. The native camera's rotation mode is overridden to
MovementRelative for this state so it cannot independently turn the character toward aim.

Free-camera dashes always use the Forward animation and follow movement, or the current
body heading when stationary. With facing locked, dash animation follows camera-relative
movement. The same world direction drives normal movement, lightning dash and wall checks.
Target lock disables Humanoid movement auto-rotation while it owns body facing.

First person captures the body heading and holds it while walking or looking around.
Attack, block, ranged aim and target lock can still turn the body to aim; ending those actions
holds the resulting heading. Leaving first person restores normal movement rotation.

Third-person free camera clears a stale LockCenter left by temporary camera owners.
First person, target lock, explicit mouse lock and ranged aim retain intentional locking;
right mouse camera dragging retains LockCurrentPosition. T unlock restores cursor state
from the previous lock mode instead of restoring a stale mouse behavior snapshot.

# Cloth preparation budget

`ClothController` prepares editable meshes one at a time, within 120 studs, prioritizing
the closest cloth. At most three uncut meshes are prepared at once. Unused preparation
buffers are released when leaving that radius; existing cuts retain their original
1,000-stud regeneration distance.

An exhausted EditableMesh budget pauses new preparation requests until buffers are
released or the character respawns. It does not issue a failing allocation for every
remaining cloth on every refresh. Nearby prepared cloth remains available for cutting.
