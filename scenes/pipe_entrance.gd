extends Area2D

class_name PipeEntrance

enum Direction { DOWN, RIGHT }

@export var exit_point_path: NodePath
@export var direction: Direction = Direction.DOWN
@export var exit_from_pipe: bool = false
@export var exit_direction: Direction = Direction.DOWN
@export var dest_palette: Palette.WorldTheme = Palette.WorldTheme.UNDERGROUND
@export var dest_scenery: Palette.SceneryType = Palette.SceneryType.DEFAULT
@export var dest_top_y: float = -128.0
@export var dest_bottom_y: float = 0
@export var dest_is_sub_area: bool = true
@export var use_longer_loading_time: bool = false
@export var auto_enter: bool = false
@export var auto_walk_speed_divisor: float = 2.4

const SINK_DISTANCE_ENTER_V := 32.0
const SINK_DISTANCE_ENTER_H := 18.0
const SINK_DISTANCE_EXIT := 16.0
const SINK_DURATION := 0.5
const RISE_DURATION := 0.5
const PAUSE_AFTER_SINK := 0.35
const PAUSE_BEFORE_RISE := 1.5
const PAUSE_BLACKOUT := 0.3

var _exit_point: Node2D
var _triggered := false
var _player_ref: Player
var _player_inside: Player
var _auto_enter_ready := false
@onready var _mask: Sprite2D = $Mask

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if exit_point_path:
		_exit_point = get_node_or_null(exit_point_path)
	_hide_mask()
	if direction == Direction.RIGHT:
		$CollisionShape2D.position.x -= 4

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = body
		if auto_enter and not _triggered:
			body.auto_walk_right = false
			_player_ref = body
			_triggered = true
			_enter_pipe()

func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null

func _physics_process(_delta: float) -> void:
	if auto_enter and not _auto_enter_ready and not _triggered:
		var auto_player := get_tree().root.find_child("Player", true, false) as Player
		if auto_player and not auto_player.is_dead:
			_auto_enter_ready = true
			Game.timer_paused = true
			auto_player.auto_walk_speed = auto_player.MAX_WALK_SPEED / auto_walk_speed_divisor
			auto_player.auto_walk_right = true
			auto_player.lock_player()

	if _triggered or not _exit_point or not _player_inside:
		return

	var player := _player_inside
	if player.is_dead or player.is_locked:
		return
	if _is_pressing_entry(player):
		_player_ref = player
		_triggered = true
		_enter_pipe()

func _is_pressing_entry(player: Player) -> bool:
	if not player.is_on_floor():
		return false
	match direction:
		Direction.DOWN:
			return Input.is_action_pressed("crouch") \
				and not Input.is_action_pressed("move_left") \
				and not Input.is_action_pressed("move_right")
		Direction.RIGHT:
			return Input.is_action_pressed("move_right")
	return false

func _enter_pipe() -> void:
	var player := _player_ref
	AudioSystem.play_sfx("pipe")
	Game.timer_paused = true

	var sink_dist := SINK_DISTANCE_ENTER_V if direction == Direction.DOWN else SINK_DISTANCE_ENTER_H
	player.start_enter_pipe({
		"direction": direction,
		"sink_distance": sink_dist,
		"sink_duration": SINK_DURATION,
		"show_mask": _show_mask,
	})

	var total_sink := SINK_DURATION
	if use_longer_loading_time:
		total_sink += PAUSE_AFTER_SINK * 5.4
	total_sink += PAUSE_AFTER_SINK

	var tween := create_tween()
	tween.tween_interval(total_sink)
	tween.tween_callback(func(): SignalBus.pipe_blackout.emit(true))
	tween.tween_interval(PAUSE_BLACKOUT)
	tween.tween_callback(_teleport_to_exit)

	if exit_from_pipe:
		tween.tween_callback(func(): SignalBus.pipe_blackout.emit(false))
		tween.tween_interval(PAUSE_BEFORE_RISE)
		tween.tween_callback(_rise_from_exit)
	else:
		tween.tween_callback(func(): SignalBus.pipe_blackout.emit(false))
		tween.tween_callback(_finish_transition)
		

func _teleport_to_exit() -> void:
	var player := _player_ref
	var target := _exit_point.global_position
	player.visible = not exit_from_pipe
	player.scale.y = 1.0
	player.sprite.offset.y = 0
	player.sprite.flip_h = false
	_hide_mask()
	Game.lvl_palette = dest_palette
	Game.lvl_scenery_palette = dest_scenery

	Game.bottom_of_map_y = dest_bottom_y
	SignalBus.game_palette_updated.emit()

	if exit_from_pipe:
		var rise_offset := Vector2.ZERO
		match exit_direction:
			Direction.DOWN:
				rise_offset = Vector2(-8, SINK_DISTANCE_EXIT)
			Direction.RIGHT:
				rise_offset = Vector2(-SINK_DISTANCE_EXIT, 0)
		player.global_position = target + rise_offset
	else:
		player.global_position = target + Vector2(-8, 0)

	player.camera.drag_horizontal_enabled = dest_is_sub_area
	player.snap_camera()

func _rise_from_exit() -> void:
	var player := _player_ref
	var target := _exit_point.global_position + Vector2(-8, -16)
	player.start_exit_pipe({
		"target": target,
		"rise_duration": RISE_DURATION,
	})
	_triggered = false

func _finish_transition() -> void:
	var player := _player_ref
	player.sprite.flip_h = false
	player.is_facing_left = false
	player.set_collision_layer_value(2, true)
	player.set_collision_mask_value(1, true)
	player.unlock_player()
	Game.timer_paused = false
	_triggered = false

func _show_mask() -> void:
	_mask.modulate = Palette.CLEAR_COLOR[Game.lvl_palette]
	_mask.visible = true

func _hide_mask() -> void:
	_mask.visible = false
