extends Node

enum SpawnMode { DEFAULT, MARKER, PIPE, VINE }

var pending_spawn: Dictionary = {}

var _transition_tween: Tween

func request_pipe_transition(data: Dictionary) -> void:
	var scene_path: String = data.get("scene_path", "")
	if scene_path.is_empty():
		_do_same_scene_teleport(data)
	else:
		_do_cross_scene_transition(data)

func request_same_scene_teleport(data: Dictionary) -> void:
	_do_same_scene_teleport(data)

func request_level_advance() -> void:
	Game.advance_level()

func request_warp() -> void:
	Game._play_intro_scene = Game.LEVEL_INTRO_SCENES.has(Game.get_level_key())
	SignalBus.level_completed.emit()
	Game.state = Game.GameState.TRANSITION

func clear_spawn() -> void:
	pending_spawn.clear()

func _do_same_scene_teleport(data: Dictionary) -> void:
	var player: Player = data.get("player")
	var exit_point: Node2D = data.get("exit_point")
	var rise_from_pipe: bool = data.get("dest_rise_from_pipe", false)
	var exit_direction: int = data.get("dest_exit_direction", 0)
	var pause_before_rise: float = data.get("pause_before_rise", 1.5)
	var hide_mask: Callable = data.get("hide_mask", Callable())

	if not player or not exit_point:
		push_error("TransitionManager: missing player or exit_point for same-scene teleport")
		return

	SignalBus.pipe_blackout.emit(true)

	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = create_tween()
	_transition_tween.tween_interval(0.3)
	_transition_tween.tween_callback(func():
		if hide_mask.is_valid():
			hide_mask.call()
		_teleport_player(player, exit_point, rise_from_pipe, exit_direction)
	)
	_transition_tween.tween_callback(func(): SignalBus.pipe_blackout.emit(false))

	if rise_from_pipe:
		_transition_tween.tween_interval(pause_before_rise)
		_transition_tween.tween_callback(func():
			_rise_player_from_pipe(player, exit_point, data.get("rise_duration", 0.5))
		)
	else:
		_transition_tween.tween_callback(func():
			_finish_player_transition(player)
		)

func _do_cross_scene_transition(data: Dictionary) -> void:
	var scene_path: String = data.get("scene_path", "")
	var marker_name: String = data.get("marker_name", "")
	var rise_from_pipe: bool = data.get("dest_rise_from_pipe", true)
	var exit_direction: int = data.get("dest_exit_direction", 0)
	var is_bonus_room: bool = data.get("dest_is_bonus_room", false)

	pending_spawn = {
		"spawn_mode": SpawnMode.PIPE if rise_from_pipe else SpawnMode.MARKER,
		"marker_name": marker_name,
		"pipe_direction": exit_direction,
		"dest_is_bonus_room": is_bonus_room,
		"rise_duration": data.get("rise_duration", 0.5),
	}

	SignalBus.pipe_blackout.emit(true)

	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = create_tween()
	_transition_tween.tween_interval(0.3)
	_transition_tween.tween_callback(func():
		SignalBus.scene_transition_requested.emit(scene_path)
	)

func _teleport_player(player: Player, exit_point: Node2D,
		rise_from_pipe: bool, exit_direction: int) -> void:
	player.visible = not rise_from_pipe
	player.scale.y = 1.0
	player.sprite.offset.y = 0
	player.sprite.flip_h = false

	if rise_from_pipe:
		var rise_offset := Vector2.ZERO
		match exit_direction:
			0: rise_offset = Vector2(-8, 16.0)
			1: rise_offset = Vector2(-16.0, 0)
		player.global_position = exit_point.global_position + rise_offset
	else:
		player.global_position = exit_point.global_position + Vector2(-8, 0)

	player.snap_camera()

func _rise_player_from_pipe(player: Player, exit_point: Node2D,
		rise_duration: float) -> void:
	var target := exit_point.global_position + Vector2(-8, -16)
	player.start_exit_pipe({
		"target": target,
		"rise_duration": rise_duration,
	})

func _finish_player_transition(player: Player) -> void:
	player.sprite.flip_h = false
	player.is_facing_left = false
	player.set_collision_layer_value(2, true)
	player.set_collision_mask_value(1, true)
	player.unlock_player()
	Game.level_timer_paused = false

func on_scene_loaded_for_pipe(player: Player, level: Node) -> void:
	if pending_spawn.is_empty():
		return

	var marker_name: String = pending_spawn.get("marker_name", "")
	var exit_point: Node2D = null
	if not marker_name.is_empty():
		exit_point = level.find_child(marker_name, true, false) as Node2D

	if not exit_point:
		push_error("TransitionManager: could not find marker '%s' in loaded scene" % marker_name)
		SignalBus.pipe_blackout.emit(false)
		_finish_player_transition(player)
		pending_spawn.clear()
		return

	var spawn_mode = pending_spawn.get("spawn_mode", SpawnMode.DEFAULT)
	var exit_direction: int = pending_spawn.get("pipe_direction", 0)
	var rise_duration: float = pending_spawn.get("rise_duration", 0.5)

	var level_builder = level.get_node_or_null("LevelBuilder")
	if level_builder:
		Game.lvl_palette = level_builder.world_theme
		Game.lvl_scenery_palette = level_builder.scenery_type

	SignalBus.game_palette_updated.emit()

	player.snap_camera()

	if spawn_mode == SpawnMode.PIPE:
		var rise_offset := Vector2.ZERO
		match exit_direction:
			0: rise_offset = Vector2(-8, 16.0)
			1: rise_offset = Vector2(-16.0, 0)
		player.global_position = exit_point.global_position + rise_offset
		player.visible = false

		SignalBus.pipe_blackout.emit(false)

		var target := exit_point.global_position + Vector2(-8, -16)
		player.start_exit_pipe({
			"target": target,
			"rise_duration": rise_duration,
			"delay": 1.5,
		})
	else:
		player.global_position = exit_point.global_position + Vector2(-8, 0)
		player.visible = true
		SignalBus.pipe_blackout.emit(false)
		_finish_player_transition(player)

	pending_spawn.clear()
