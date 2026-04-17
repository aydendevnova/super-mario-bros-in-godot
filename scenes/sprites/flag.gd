extends Node2D

const POLE_TOP_Y := 8.0
const POLE_BOTTOM_Y := 136.0
const FLAG_BOTTOM_Y := 128.0
const SLIDE_SPEED := 120.0
const BOTTOM_PAUSE := 0.5
const HOP_DURATION := 0.25
const HOP_HEIGHT := 12.0

@onready var flag_sprite: Sprite2D = $FlagSprite
@onready var pole_area: Area2D = $PoleArea

const HIDE_DISTANCE := 96.0-32

var _triggered := false
var _player: Player
var _walking := false
var _walk_start_x := 0.0
var _countdown_done := false
var _advancing := false

func _on_pole_area_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not body is Player:
		return

	_triggered = true
	_player = body
	_player.freeze_camera()
	_player.lock_player()
	_player.set_collision_layer_value(2, false)
	_player.set_collision_mask_value(1, false)

	Game.level_complete()

	_run_sequence()

func _run_sequence() -> void:
	AudioSystem.stop_music()
	AudioSystem.play_sfx("down_the_flagpole")
	var pole_x := global_position.x
	var grab_y := clampf(_player.global_position.y, global_position.y + POLE_TOP_Y, global_position.y + POLE_BOTTOM_Y)

	_player.global_position = Vector2(pole_x - 8, grab_y)
	_player.sprite.flip_h = false
	_player.sprite.play("Flagpole")

	var slide_dist := (global_position.y + POLE_BOTTOM_Y) - grab_y
	var slide_duration := slide_dist / SLIDE_SPEED
	var flag_dist := FLAG_BOTTOM_Y - flag_sprite.position.y
	var flag_duration := flag_dist / SLIDE_SPEED

	var tween := create_tween()

	tween.set_parallel(true)
	tween.tween_property(_player, "global_position:y", global_position.y + POLE_BOTTOM_Y, slide_duration)
	tween.tween_property(flag_sprite, "position:y", FLAG_BOTTOM_Y, flag_duration)

	tween.set_parallel(false)
	tween.tween_callback(_at_pole_bottom)
	tween.tween_interval(BOTTOM_PAUSE)
	tween.tween_callback(_hop_off)

func _at_pole_bottom() -> void:
	_player.sprite.offset.x = 16
	_player.sprite.flip_h = true
	_player.sprite.play("BottomFlagpole")

func _hop_off() -> void:
	_player.sprite.offset.x = 16
	_player.sprite.flip_h = false
	_player.sprite.play("Jump")

	var start_pos := _player.global_position
	var end_x := global_position.x + 16
	var end_y := start_pos.y

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_player, "global_position:x", end_x, HOP_DURATION)
	tween.tween_method(func(t: float):
		_player.global_position.y = start_pos.y - sin(t * PI) * HOP_HEIGHT
	, 0.0, 1.0, HOP_DURATION)

	tween.set_parallel(false)
	tween.tween_callback(_start_walk)

func _process(_delta: float) -> void:
	if _walking and _player.visible:
		if _player.global_position.x - _walk_start_x >= HIDE_DISTANCE:
			_player.visible = false
			Game.countdown_time_to_score(_on_countdown_finished)

	if _countdown_done and not _advancing and not AudioSystem.is_music_playing():
		_advancing = true
		_do_advance()

func _start_walk() -> void:
	_player.unfreeze_camera()
	var fanfare := "world_clear_fanfare" if Game.level == 4 else "course_clear_fanfare"
	AudioSystem.play_music(fanfare)
	_player.sprite.play("Walk")
	_player.sprite.flip_h = false
	_player.is_facing_left = false
	_player.auto_walk_right = true
	_player.set_collision_mask_value(1, true)
	_walk_start_x = _player.global_position.x
	_walking = true

func _on_countdown_finished() -> void:
	_countdown_done = true

func _do_advance() -> void:
	await get_tree().create_timer(0.5).timeout
	_player.sprite.offset.x = 0
	Game.advance_level()
