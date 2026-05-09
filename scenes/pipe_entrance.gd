extends Area2D

class_name PipeEntrance

enum Direction { DOWN, RIGHT }

@export_group("This Pipe")
@export var direction: Direction = Direction.DOWN
@export var is_transition_scene: bool = false
@export var use_longer_loading_time: bool = false
@export var auto_walk_speed_modf: float = 52

@export_group("Destination")
@export var dest_scene_path: String = ""
@export var dest_marker_name: String = "PipeDest"
@export var dest_is_bonus_room: bool = false
@export var dest_rise_from_pipe: bool = false
@export var dest_exit_direction: Direction = Direction.DOWN
@export var dest_warp_level: String = ""

const SINK_DISTANCE_ENTER_V := 36.0
const SINK_DISTANCE_ENTER_H := 20.0
const SINK_DURATION := 0.5
const RISE_DURATION := 0.5
const PAUSE_AFTER_SINK := 0.35
const PAUSE_BEFORE_RISE := 1.5
const PAUSE_BLACKOUT := 0.3

var _triggered := false
var _player_ref: Player
var _player_inside: Player
var _transition_scene_ready := false
@onready var _mask: Sprite2D = $Mask

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_hide_mask()
	if direction == Direction.RIGHT:
		$CollisionShape2D.position.x -= 4

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = body
		if is_transition_scene and not _triggered:
			body.auto_walk_right = false
			_player_ref = body
			_triggered = true
			_enter_pipe()

func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null

func _physics_process(_delta: float) -> void:
	if is_transition_scene and not _transition_scene_ready and not _triggered:
		var auto_player := get_tree().root.find_child("Player", true, false) as Player
		if auto_player and not auto_player.is_dead:
			_transition_scene_ready = true
			Game.level_timer_paused = true
			auto_player.auto_walk_speed = auto_player.MAX_WALK_SPEED - auto_walk_speed_modf
			auto_player.auto_walk_right = true
			auto_player.lock_player()

	if _triggered or not _player_inside:
		return
	if dest_scene_path.is_empty() and dest_marker_name.is_empty() and dest_warp_level.is_empty():
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
	Game.level_timer_paused = true

	var sink_dist := SINK_DISTANCE_ENTER_V if direction == Direction.DOWN else SINK_DISTANCE_ENTER_H
	player.start_enter_pipe({
		"direction": direction,
		"sink_distance": sink_dist,
		"sink_duration": SINK_DURATION,
		"show_mask": _show_mask,
	})

	var total_sink := SINK_DURATION

	if not dest_warp_level.is_empty():
		var tween := create_tween()
		tween.tween_interval(total_sink + PAUSE_AFTER_SINK)
		tween.tween_callback(_request_warp)
		return

	if use_longer_loading_time:
		total_sink += PAUSE_AFTER_SINK * 5.4
	total_sink += PAUSE_AFTER_SINK

	var tween := create_tween()
	tween.tween_interval(total_sink)

	if not dest_scene_path.is_empty():
		tween.tween_callback(_request_cross_scene_transition)
	else:
		tween.tween_callback(_request_same_scene_teleport)

func _request_warp() -> void:
	_hide_mask()
	var parts := dest_warp_level.split("-")
	if parts.size() == 2:
		Game.world = int(parts[0])
		Game.level = int(parts[1])
	TransitionManager.request_warp()

func _request_cross_scene_transition() -> void:
	_hide_mask()
	TransitionManager.request_pipe_transition({
		"scene_path": dest_scene_path,
		"marker_name": dest_marker_name,
		"dest_rise_from_pipe": dest_rise_from_pipe,
		"dest_exit_direction": dest_exit_direction,
		"dest_is_bonus_room": dest_is_bonus_room,
		"rise_duration": RISE_DURATION,
	})

func _request_same_scene_teleport() -> void:
	var exit_point := _find_marker_in_scene()
	if not exit_point:
		push_error("PipeEntrance: could not find marker '%s' in current scene" % dest_marker_name)
		return
	TransitionManager.request_same_scene_teleport({
		"player": _player_ref,
		"exit_point": exit_point,
		"dest_rise_from_pipe": dest_rise_from_pipe,
		"dest_exit_direction": dest_exit_direction,
		"pause_before_rise": PAUSE_BEFORE_RISE,
		"rise_duration": RISE_DURATION,
		"hide_mask": _hide_mask,
	})
	_triggered = false

func _find_marker_in_scene() -> Node2D:
	if dest_marker_name.is_empty():
		return null
	var level := Game.current_level
	if not level:
		return null
	return level.find_child(dest_marker_name, true, false) as Node2D

func _show_mask() -> void:
	_mask.modulate = Palette.CLEAR_COLOR[Game.lvl_palette]
	_mask.visible = true

func _hide_mask() -> void:
	_mask.visible = false
