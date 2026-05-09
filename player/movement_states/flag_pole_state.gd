extends PlayerMovementState

const PHASE_SLIDE := &"slide"
const PHASE_BOTTOM := &"bottom"
const PHASE_TURN := &"turn"
const PHASE_WALK := &"walk"

const POINTS_POPUP := preload("res://scenes/sprites/points_popup.tscn")
const POLE_SCORE_ZONES := [
	[16.0, 5000],
	[48.0, 2000],
	[80.0, 800],
	[112.0, 400],
	[128.0, 100],
]

var _flag: Node2D
var _flag_sprite: Sprite2D
var _phase: StringName = PHASE_SLIDE
var _walking := false
var _walk_start_x := 0.0
var _hide_x := 0.0
var _countdown_done := false
var _advancing := false
var _sequence_tween: Tween
var _top_y := 8.0
var _bottom_y := 136.0
var _flag_bottom_y := 128.0
var _slide_speed := 120.0
var _bottom_pause := 0.25
var _turn_pause := 0.6
var _mario_reached_bottom := false

func enter(_previous_state: StringName) -> void:
	var data: Dictionary = player._flag_pole_data
	_flag = data.get("flag", null) as Node2D
	_flag_sprite = data.get("flag_sprite", null) as Sprite2D
	_hide_x = float(data.get("hide_x", 0.0))
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
	_mario_reached_bottom = false

	AudioSystem.stop_music()
	AudioSystem.play_sfx("down_the_flagpole")

	var pole_x := _flag.global_position.x
	var grab_y := clampf(player.global_position.y, _flag.global_position.y + _top_y, _flag.global_position.y + _bottom_y)
	player.global_position = Vector2(pole_x - 5, grab_y)

	_award_flagpole_score(grab_y - (_flag.global_position.y + _top_y))

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
	_sequence_tween.tween_callback(_at_turn)
	_sequence_tween.tween_interval(_turn_pause)
	_sequence_tween.tween_callback(_start_walk)

func exit(_next_state: StringName) -> void:
	if _sequence_tween and _sequence_tween.is_valid():
		_sequence_tween.kill()
		_sequence_tween = null

func physics_update(_delta: float) -> void:
	if _phase == PHASE_SLIDE and not _mario_reached_bottom:
		var target_y := _flag.global_position.y + _bottom_y
		if player.global_position.y >= target_y - 1.0:
			_mario_reached_bottom = true
	if _phase in [PHASE_BOTTOM, PHASE_TURN, PHASE_WALK]:
		player.apply_gravity(_delta, false)
	if _walking:
		player.velocity.x = player.auto_walk_speed
		if player.visible and player.global_position.x >= _hide_x - 16:
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
			if _mario_reached_bottom:
				player.sprite.speed_scale = 0.0
				player.sprite.play("Flagpole")
				player.sprite.frame = 0
				player.sprite.frame_progress = 0.0
			else:
				player.sprite.speed_scale = 1.0
				player.sprite.play("Flagpole")
		PHASE_BOTTOM:
			player.sprite.offset.x = 0
			player.sprite.flip_h = false
			player.sprite.speed_scale = 0.0
			player.sprite.play("Flagpole")
			player.sprite.frame = 0
			player.sprite.frame_progress = 0.0
		PHASE_TURN:
			player.sprite.offset.x = 14
			player.sprite.flip_h = true
			player.sprite.speed_scale = 0.0
			player.sprite.play("Flagpole")
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

func _at_turn() -> void:
	_phase = PHASE_TURN

func _start_walk() -> void:
	_phase = PHASE_WALK
	_walking = true
	player.global_position.x += 16
	player.sprite.offset.x = 0
	player.sprite.flip_h = false
	player.sprite.speed_scale = 1.0
	player.sprite.play("Walk")
	player.unfreeze_camera()
	player.is_facing_left = false
	_walk_start_x = player.global_position.x
	var fanfare := "world_clear_fanfare" if Game.level == 4 else "course_clear_fanfare"
	AudioSystem.play_music(fanfare)

func _on_countdown_finished() -> void:
	_countdown_done = true

func _award_flagpole_score(height_from_top: float) -> void:
	var points := 100
	for zone in POLE_SCORE_ZONES:
		if height_from_top <= zone[0]:
			points = zone[1]
			break
	Game.up_score(points)
	var popup := POINTS_POPUP.instantiate()
	popup.static_mode = true
	var flag_local: Vector2 = Game.current_level.to_local(_flag.global_position)
	var spawn_pos := Vector2(flag_local.x, flag_local.y + _bottom_y - 16)
	if points > 1000:
		spawn_pos.x += 8
	else:
		spawn_pos.x += 12
	popup.position = spawn_pos
	popup.points = points
	popup.static_mode = true
	Game.current_level.add_child(popup)
	var target_y: float = flag_local.y + _top_y + 8
	var rise_dist: float = spawn_pos.y - target_y
	var rise_duration: float = rise_dist / (_slide_speed * 0.9)
	var tween := popup.create_tween()
	tween.tween_property(popup, "position:y", target_y, rise_duration)

func _do_advance() -> void:
	await player.get_tree().create_timer(1.5).timeout
	player.sprite.offset.x = 0
	TransitionManager.request_level_advance()
