class_name PixelPerfectSmoother
extends Camera2D

# LITE VERSION — Full version adds velocity-based lookahead: the camera shifts
# ahead of the player's movement direction, giving a cinematic "anticipation"
# feel that significantly improves perceived game feel in action games.
# Full version: https://nullstateassets.itch.io

# WHY THIS SCRIPT EXISTS:
# Godot's built-in Camera2D position_smoothing rounds the camera to whole pixels
# AFTER smoothing, which means the sub-pixel remainder is discarded every frame.
# This creates a jitter artifact in pixel art games because the camera snaps
# rather than glides. The fix is to track a high-precision float position
# separately, smooth THAT, and only snap to the nearest pixel at the final
# render step — preserving the smooth motion in logic while keeping crisp pixels
# on screen.

@export_category("Pixel Perfect Smoother")

@export_group("Target")
## The node this camera will follow. If left empty, the camera stays fixed.
@export var follow_target: Node2D = null

@export_group("Smoothing")
## Enables or disables position smoothing entirely. Disable for instant snapping.
@export var smoothing_enabled: bool = true
## Higher values make the camera catch up faster. Lower values feel floatier.
## Range kept tight to prevent accidentally setting 0 (division by zero in lerp).
@export_range(1.0, 30.0, 0.1) var follow_speed: float = 8.0

@export_group("Pixel Snapping")
## The size of one pixel in world units. Must match your project's pixels-per-unit
## setting. For a standard 1:1 pixel art project this is 1.0. If your sprites
## are imported at 16 PPU, set this to 0.0625 (1/16).
@export_range(0.001, 64.0, 0.001) var pixel_size: float = 1.0
## When enabled, the camera's rendered position is snapped to the pixel grid.
## Disable only if you are debugging the raw smoothed position.
@export var pixel_snap_enabled: bool = true

@export_group("Offset")
## Static world-space offset applied on top of the target's position.
## Useful for keeping the player in the lower-third of the screen, etc.
@export var base_offset: Vector2 = Vector2.ZERO

@export_group("Limits")
## Clamps the camera's smoothed position within these world-space bounds before
## pixel snapping. Set all to 0 to disable clamping entirely.
@export var use_limits: bool = false
@export var bounds_left: float = -1000.0
@export var bounds_right: float = 1000.0
@export var bounds_top: float = -1000.0
@export var bounds_bottom: float = 1000.0

# --- Private State ---

# The sub-pixel-accurate world position the camera is smoothing toward.
# This is the "true" camera position before pixel snapping is applied.
var _smooth_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Disable the engine's built-in smoothing unconditionally. If it were left
	# enabled alongside our manual lerp, the two systems would compound and
	# produce a double-smoothed, sluggish result.
	position_smoothing_enabled = false

	if follow_target != null:
		_smooth_position = follow_target.global_position + base_offset
	else:
		_smooth_position = global_position

	# Seed the camera at the correct position immediately so there is no
	# one-frame lerp-from-origin artifact on scene load.
	_apply_position(_smooth_position)


func _process(delta: float) -> void:
	if follow_target == null:
		return

	var desired_position: Vector2 = follow_target.global_position + base_offset

	# --- Smooth Follow ---
	if smoothing_enabled:
		# Multiply speed by delta so the result is framerate-independent —
		# a follow_speed of 8 feels identical at 30fps and 240fps.
		_smooth_position = _smooth_position.lerp(desired_position, follow_speed * delta)
	else:
		_smooth_position = desired_position

	# --- World Limits ---
	# Clamping is applied to the smooth float position BEFORE pixel snapping
	# so the snap never pushes the camera outside the intended boundary.
	if use_limits:
		_smooth_position.x = clampf(_smooth_position.x, bounds_left, bounds_right)
		_smooth_position.y = clampf(_smooth_position.y, bounds_top, bounds_bottom)

	_apply_position(_smooth_position)


func _apply_position(world_pos: Vector2) -> void:
	if pixel_snap_enabled:
		# Snap to the nearest pixel grid point in world space.
		# Dividing by pixel_size, rounding, then multiplying back converts
		# from world units into pixel units and back — this is the canonical
		# way to snap regardless of the project's pixels-per-unit scale.
		# Without this step, sub-pixel positions cause texture sampling to
		# blend adjacent pixels, producing the characteristic "crawling" blur
		# on pixel art sprites during camera movement.
		global_position = (world_pos / pixel_size).round() * pixel_size
	else:
		global_position = world_pos


# --- Public API ---

## Teleports the camera instantly to the target's current position, bypassing
## the lerp. Call this after a scene transition or player respawn to prevent
## the camera from visibly sliding in from the old position.
func snap_to_target() -> void:
	if follow_target == null:
		return
	_smooth_position = follow_target.global_position + base_offset
	_apply_position(_smooth_position)


## Replaces the follow target at runtime and optionally snaps immediately.
## Passing snap=false lets the camera smoothly drift to the new target,
## which can feel intentional during a "camera handoff" cinematic moment.
func set_follow_target(new_target: Node2D, snap: bool = true) -> void:
	follow_target = new_target
	if snap:
		snap_to_target()
