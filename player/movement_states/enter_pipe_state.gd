extends PlayerMovementState

var _direction: int = 0 # 0 = DOWN, 1 = RIGHT
var _sink_distance: float = 34.0
var _sink_duration: float = 0.5
var _tween: Tween
var _done := false

func enter(_previous_state: StringName) -> void:
	var data: Dictionary = player._enter_pipe_data
	_direction = int(data.get("direction", 0))
	_sink_distance = float(data.get("sink_distance", 34.0))
	_sink_duration = float(data.get("sink_duration", 0.5))
	var show_mask: Callable = data.get("show_mask", Callable())
	player._enter_pipe_data.clear()
	_done = false

	player.velocity = Vector2.ZERO
	player.input_axis = Vector2.ZERO
	player.set_crouching(false)
	player._update_tree()
	player.set_collision_layer_value(2, false)
	player.set_collision_mask_value(1, false)

	match _direction:
		0: # DOWN
			player.sprite.play("Idle")
		1: # RIGHT
			player.sprite.play("Walk")
			player.sprite.speed_scale = 1
			player.sprite.flip_h = false
			if show_mask.is_valid():
				show_mask.call()

	var sink_offset := Vector2.ZERO
	match _direction:
		0:
			sink_offset = Vector2(0, _sink_distance)
		1:
			sink_offset = Vector2(_sink_distance-2, 0)

	_tween = player.create_tween()
	_tween.tween_property(player, "global_position", player.global_position + sink_offset, _sink_duration)
	_tween.tween_callback(_on_sink_complete)

func exit(_next_state: StringName) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null

func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO

func get_next_state() -> StringName:
	if _done:
		return &"locked"
	return StringName()

func _on_sink_complete() -> void:
	player.sprite.pause()
	_done = true
