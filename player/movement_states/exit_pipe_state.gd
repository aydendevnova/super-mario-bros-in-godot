extends PlayerMovementState

var _target: Vector2
var _rise_duration: float = 0.5
var _delay: float = 0.0
var _tween: Tween
var _done := false

func enter(_previous_state: StringName) -> void:
	var data: Dictionary = player._exit_pipe_data
	_target = data.get("target", player.global_position) as Vector2
	_rise_duration = float(data.get("rise_duration", 0.5))
	_delay = float(data.get("delay", 0.0))
	player._exit_pipe_data.clear()
	_done = false

	player.velocity = Vector2.ZERO
	player.input_axis = Vector2.ZERO
	player.sprite.play("Idle")
	player.sprite.flip_h = false

	_tween = player.create_tween()
	if _delay > 0.0:
		_tween.tween_interval(_delay)
		_tween.tween_callback(func(): player.visible = true)
	else:
		player.visible = true
	_tween.tween_property(player, "global_position", _target, _rise_duration)
	_tween.tween_callback(_on_rise_complete)

func exit(_next_state: StringName) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null

func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO

func get_next_state() -> StringName:
	if _done:
		return &"idle"
	return StringName()

func _on_rise_complete() -> void:
	player.sprite.flip_h = false
	player.is_facing_left = false
	player.set_collision_layer_value(2, true)
	player.set_collision_mask_value(1, true)
	player.auto_walk_right = false
	player.reset_auto_walk_speed()
	player.camera_frozen = false
	Game.level_timer_paused = false
	_done = true
