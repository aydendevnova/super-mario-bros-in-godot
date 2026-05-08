extends PlayerMovementState

const PHASE_SLIDE := &"slide"
const PHASE_BOTTOM := &"bottom"
const PHASE_WALK := &"walk"

var _flag: Node2D
var _flag_sprite: Sprite2D
var _phase: StringName = PHASE_SLIDE
var _walking := false
var _walk_start_x := 0.0
var _hide_distance := 64.0
var _countdown_done := false
var _advancing := false
var _sequence_tween: Tween
var _top_y := 8.0
var _bottom_y := 136.0
var _flag_bottom_y := 128.0
var _slide_speed := 120.0
var _bottom_pause := 0.5

func enter(_previous_state: StringName) -> void:
	var data: Dictionary = player._flag_pole_data
	_flag = data.get("flag", null) as Node2D
	_flag_sprite = data.get("flag_sprite", null) as Sprite2D
	_hide_distance = float(data.get("hide_distance", 64.0))
	_top_y = float(data.get("pole_top_y", 8.0))
	_bottom_y = float(data.get("pole_bottom_y", 136.0))
	_flag_bottom_y = float(data.get("flag_bottom_y", 128.0))
	_slide_speed = float(data.get("slide_speed", 120.0))
	_bottom_pause = float(data.get("bottom_pause", 0.5))
	player._flag_pole_data.clear()
	if not _flag:
		machine.transition_to(&"idle")
		return

	player.freeze_camera()
	player.set_collision_layer_value(2, false)
	player.set_collision_mask_value(1, false)
	player.velocity = Vector2.ZERO
	player.input_axis = Vector2.ZERO
	player.set_crouching(false)
	_phase = PHASE_SLIDE
	_walking = false
	_countdown_done = false
	_advancing = false

	AudioSystem.stop_music()
	AudioSystem.play_sfx("down_the_flagpole")

	var pole_x := _flag.global_position.x
	var grab_y := clampf(player.global_position.y, _flag.global_position.y + _top_y, _flag.global_position.y + _bottom_y)
	player.global_position = Vector2(pole_x - 8, grab_y)

	var slide_dist := (_flag.global_position.y + _bottom_y) - grab_y
	var slide_duration := slide_dist / _slide_speed
	var flag_duration := 0.0
	if _flag_sprite:
		flag_duration = (_flag_bottom_y - _flag_sprite.position.y) / _slide_speed

	_sequence_tween = player.create_tween()
	_sequence_tween.set_parallel(true)
	_sequence_tween.tween_property(player, "global_position:y", _flag.global_position.y + _bottom_y, slide_duration)
	if _flag_sprite:
		_sequence_tween.tween_property(_flag_sprite, "position:y", _flag_bottom_y, flag_duration)
	_sequence_tween.set_parallel(false)
	_sequence_tween.tween_callback(_at_pole_bottom)
	_sequence_tween.tween_interval(_bottom_pause)
	_sequence_tween.tween_callback(_start_walk)

func exit(_next_state: StringName) -> void:
	if _sequence_tween and _sequence_tween.is_valid():
		_sequence_tween.kill()
		_sequence_tween = null

func physics_update(_delta: float) -> void:
	if _phase == PHASE_BOTTOM or _phase == PHASE_WALK:
		player.apply_gravity(_delta, false)
	if _walking:
		player.velocity.x = player.auto_walk_speed
		if player.visible and player.global_position.x - _walk_start_x >= _hide_distance:
			player.visible = false
			Game.countdown_time_to_score(_on_countdown_finished)
	if _countdown_done and not _advancing and not AudioSystem.is_music_playing():
		_advancing = true
		_do_advance()

func update_animation() -> bool:
	match _phase:
		PHASE_SLIDE:
			player.sprite.offset.x = 0
			player.sprite.flip_h = false
			player.sprite.speed_scale = 1.0
			player.sprite.play("Flagpole")
		PHASE_BOTTOM:
			player.sprite.offset.x = 16
			player.sprite.flip_h = true
			player.sprite.speed_scale = 0.0
			player.sprite.play("BottomFlagpole")
			player.sprite.frame = 0
			player.sprite.frame_progress = 0.0
		PHASE_WALK:
			player.sprite.offset.x = 0

			player.sprite.flip_h = false
			player.sprite.speed_scale = 1.0
			player.sprite.play("Walk")
	return true

func _at_pole_bottom() -> void:
	_phase = PHASE_BOTTOM
	player.set_collision_layer_value(2, true)
	player.set_collision_mask_value(1, true)

func _start_walk() -> void:
	_phase = PHASE_WALK
	_walking = true
	player.global_position.x += 16
	player.unfreeze_camera()
	player.is_facing_left = false
	_walk_start_x = player.global_position.x
	var fanfare := "world_clear_fanfare" if Game.level == 4 else "course_clear_fanfare"
	AudioSystem.play_music(fanfare)

func _on_countdown_finished() -> void:
	_countdown_done = true

func _do_advance() -> void:
	await player.get_tree().create_timer(0.5).timeout
	player.sprite.offset.x = 0
	Game.advance_level()
