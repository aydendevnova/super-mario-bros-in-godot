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
		var player := get_tree().root.find_child("Player", true, false) as Player
		if player and not player.is_dead:
			_auto_enter_ready = true
			Game.timer_paused = true
			player.is_locked = true
			player.auto_walk_right = true

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
	player.entering_pipe = true
	AudioSystem.play_sfx("pipe")

	Game.timer_paused = true
	player.is_crouching = false
	player.lock_player()
	player._update_tree()
	player.set_collision_layer_value(2, false)
	player.set_collision_mask_value(1, false)

	match direction:
		Direction.DOWN:
			player.sprite.play("Idle")
		Direction.RIGHT:
			player.sprite.play("Walk")
			player.sprite.speed_scale = 2.5
			player.sprite.flip_h = false
			_show_mask()

	var sink_offset := Vector2.ZERO
	match direction:
		Direction.DOWN:
			sink_offset = Vector2(0, SINK_DISTANCE_ENTER_V)
		Direction.RIGHT:
			sink_offset = Vector2(SINK_DISTANCE_ENTER_H, 0)

	var tween := create_tween()
	tween.tween_property(player, "global_position", player.global_position + sink_offset, SINK_DURATION)
	if direction == Direction.RIGHT:
		tween.parallel().tween_property(player, "scale:y", 0.8, SINK_DURATION)
	# intentional time increase - since it is loading the world
	if use_longer_loading_time:
		tween.tween_interval(PAUSE_AFTER_SINK*5.4)
	tween.tween_interval(PAUSE_AFTER_SINK)
	
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

	player.visible = true
	player.sprite.play("Idle")
	player.sprite.flip_h = false

	var target := _exit_point.global_position + Vector2(-8, -16)
	var tween := create_tween()
	tween.tween_property(player, "global_position", target, RISE_DURATION)
	tween.tween_callback(_finish_transition)

func _finish_transition() -> void:
	var player := _player_ref
	player.sprite.flip_h = false
	player.is_facing_left = false
	player.set_collision_layer_value(2, true)
	player.set_collision_mask_value(1, true)
	player.entering_pipe = false
	player.unlock_player()
	Game.timer_paused = false
	_triggered = false

func _show_mask() -> void:
	_mask.modulate = Palette.CLEAR_COLOR[Game.lvl_palette]
	_mask.visible = true

func _hide_mask() -> void:
	_mask.visible = false
