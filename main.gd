extends Node

const LEVEL_Y_OFFSET := -208.0
const PLAYER_SCENE := preload("res://player/player.tscn")
const METATILE_PX := 16
const AREA_ROWS := 13
const SPAWN_COL := 2
const SPAWN_X := 40.0

const THEME_BGM := {
	Palette.WorldTheme.OVERWORLD: "overworld_bgm",
	Palette.WorldTheme.UNDERGROUND: "underground_bgm",
	Palette.WorldTheme.CASTLE: "castle_bgm",
	Palette.WorldTheme.UNDERWATER: "underwater_bgm",
}
const HURRY_BGM := {
	"overworld_bgm": "overworld_bgm_hurry_up",
	"underground_bgm": "underground_bgm_hurry_up",
	"castle_bgm": "castle_bgm_hurry_up",
	"underwater_bgm": "underwater_bgm_hurry_up",
	"invincible_bgm": "invincible_bgm_hurry_up",
}

@export var dev_quick_start := false
@export var dev_level := "1-1"

var _level_container: Node2D
var _current_level: Node
var _player: Player
var _current_bgm := ""
var _hurry := false
var _loading_level := false

func _ready():
	get_window().size = Vector2i(1920, 1080)
	DisplayServer.window_set_min_size(Vector2(960, 960), 0)
	_level_container = %Level
	for child in _level_container.get_children():
		child.queue_free()
	SignalBus.game_state_changed.connect(_on_state_changed)
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.level_completed.connect(_on_level_completed)
	SignalBus.game_palette_updated.connect(_on_palette_updated)
	SignalBus.time_updated.connect(_on_time_updated)
	SignalBus.star_power_ended.connect(_on_star_power_ended)

	if dev_quick_start:
		_dev_start.call_deferred()

var _skip_load := false

func _on_state_changed(new_state) -> void:
	match new_state:
		Game.GameState.PLAYING:
			if _skip_load:
				_skip_load = false
			else:
				_load_level()
		Game.GameState.DEAD:
			AudioSystem.stop_music()
			AudioSystem.play_music("player_down")
		Game.GameState.MENU:
			AudioSystem.stop_music()
			_unload_level()
			_despawn_player()

func _load_level() -> void:
	_unload_level()
	_despawn_player()
	_hurry = false

	var scene = load(Game.get_level_scene_path()) as PackedScene
	if not scene:
		push_error("Failed to load level: %s" % Game.get_level_scene_path())
		return

	_current_level = scene.instantiate()
	_current_level.position.y = LEVEL_Y_OFFSET
	_loading_level = true
	_level_container.add_child(_current_level)
	Game.current_level = _current_level

	var level_builder = _current_level.get_node_or_null("LevelBuilder")
	if level_builder:
		Game.lvl_palette = level_builder.world_theme
		Game.lvl_scenery_palette = level_builder.scenery_type
		SignalBus.game_palette_updated.emit()
	else:
		printerr("Error!")

	_spawn_player()

	_current_bgm = THEME_BGM.get(Game.lvl_palette, "overworld_bgm")
	if _has_auto_enter_pipe():
		AudioSystem.play_music("scene_change_bgm")
	else:
		AudioSystem.play_music(_current_bgm)
	_loading_level = false



func _unload_level() -> void:
	if _current_level and is_instance_valid(_current_level):
		_current_level.queue_free()
		_current_level = null
		Game.current_level = null

func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	_level_container.add_child(_player)
	_player.position = Vector2(SPAWN_X, _find_spawn_y())
	

func _despawn_player() -> void:
	if _player and is_instance_valid(_player):
		_player.queue_free()
		_player = null

func _find_spawn_y() -> float:
	if not _current_level:
		return -48.0

	var lb = _current_level.get_node_or_null("LevelBuilder")
	if not lb or lb.get_child_count() == 0:
		print("using -48, no level builder found")
		return -48.0

	var first_area := lb.get_child(0) as Node2D
	if not first_area:
		print("using -48, no first area found")
		return -48.0

	var bg_layer := first_area.get_node_or_null("Background") as TileMapLayer
	if not bg_layer:
		return -48.0

	# Scan from highest Y (bottom, row 12) to lowest Y (top, row 0).
	# Only check the Background layer since it's the only one with collision.
	var bottom_ground := -1
	for row in range(AREA_ROWS - 1, -1, -1):
		if bg_layer.get_cell_source_id(Vector2i(SPAWN_COL, row)) != -1:
			bottom_ground = row
			break

	if bottom_ground < 0:
		return -48.0

	var surface_row := bottom_ground
	for row in range(bottom_ground - 1, -1, -1):
		if bg_layer.get_cell_source_id(Vector2i(SPAWN_COL, row)) == -1:
			break
		surface_row = row

	# Small Mario: collision bottom at +16, sprite is 16px tall
	return (LEVEL_Y_OFFSET + surface_row * METATILE_PX - 2 * METATILE_PX) + 16

func _on_player_died() -> void:
	_unload_level()
	_despawn_player()
	Game.on_player_died()
	if Game.state == Game.GameState.MENU:
		AudioSystem.stop_music()
		AudioSystem.play_music("game_over")

func _on_level_completed() -> void:
	_unload_level()
	_despawn_player()

func _on_palette_updated() -> void:
	if _loading_level:
		return
	_current_bgm = THEME_BGM.get(Game.lvl_palette, "overworld_bgm")
	if _hurry:
		AudioSystem.play_music(HURRY_BGM.get(_current_bgm, _current_bgm))
	else:
		AudioSystem.play_music(_current_bgm)

func _on_time_updated(t: int) -> void:
	if t == 100 and not _hurry and not Game._level_finished:
		_hurry = true
		AudioSystem.stop_music()
		AudioSystem.play_music("time_up_warning_sound")
		get_tree().create_timer(3.0).timeout.connect(func():
			if Game.state == Game.GameState.PLAYING:
				AudioSystem.play_music(HURRY_BGM.get(_current_bgm, _current_bgm))
		)

func _on_star_power_ended() -> void:
	if Game.state != Game.GameState.PLAYING:
		return
	if _hurry:
		AudioSystem.play_music(HURRY_BGM.get(_current_bgm, _current_bgm))
	else:
		AudioSystem.play_music(_current_bgm)

func _has_auto_enter_pipe() -> bool:
	if not _current_level:
		return false
	for node in _current_level.find_children("*", "PipeEntrance"):
		if node.auto_enter:
			return true
	return false

func _play_level_bgm() -> void:
	if _hurry:
		AudioSystem.play_music(HURRY_BGM.get(_current_bgm, _current_bgm))
	else:
		AudioSystem.play_music(_current_bgm)

func _dev_start() -> void:
	var parts := dev_level.split("-")
	Game.world = int(parts[0])
	Game.level = int(parts[1])
	_hurry = false

	var scene = load(Game.get_level_scene_path()) as PackedScene
	if not scene:
		push_error("[DevStart] Failed to load level: %s" % Game.get_level_scene_path())
		return

	_current_level = scene.instantiate()
	_current_level.position.y = LEVEL_Y_OFFSET
	_loading_level = true
	_level_container.add_child(_current_level)
	Game.current_level = _current_level

	var level_builder = _current_level.get_node_or_null("LevelBuilder")
	if level_builder:
		Game.lvl_palette = level_builder.world_theme
		Game.lvl_scenery_palette = level_builder.scenery_type
		SignalBus.game_palette_updated.emit()

	_player = PLAYER_SCENE.instantiate()
	_level_container.add_child(_player)

	var quick_start := _current_level.get_node_or_null("QuickStart") as Marker2D
	if quick_start:
		_player.global_position = quick_start.global_position
	else:
		_player.position = Vector2(SPAWN_X, _find_spawn_y())

	_current_bgm = THEME_BGM.get(Game.lvl_palette, "overworld_bgm")
	if _has_auto_enter_pipe():
		AudioSystem.play_music("scene_change_bgm")
	else:
		AudioSystem.play_music(_current_bgm)
	_loading_level = false

	_skip_load = true
	Game.begin_level()
