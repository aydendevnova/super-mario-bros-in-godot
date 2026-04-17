extends Node

enum GameState { MENU, TRANSITION, PLAYING, DEAD }

var state: GameState = GameState.MENU:
	set(value):
		state = value
		SignalBus.game_state_changed.emit(state)

var time: int = 400
var world: int = 1
var level: int = 1
var lives: int = 3
var score: int = 0
var coins: int = 0
var top_score: int = 0

var lvl_palette = Palette.WorldTheme.OVERWORLD
var lvl_scenery_palette = Palette.SceneryType.DEFAULT

var is_paused := false
var current_level: Node = null

# may be different depending on subareas, etc
var bottom_of_map_y: float = 0

var _time_accumulator: float = 0.0
var _level_finished := false
var timer_paused := false
var _countdown_active := false
var _countdown_callback: Callable
const COUNTDOWN_TICK_INTERVAL := 0.014
const POINTS_PER_TICK := 50

func _process(delta: float) -> void:
	if _countdown_active and time > 0:
		_time_accumulator += delta
		if _time_accumulator >= COUNTDOWN_TICK_INTERVAL:
			_time_accumulator -= COUNTDOWN_TICK_INTERVAL
			time -= 1
			up_score(POINTS_PER_TICK)
			SignalBus.time_updated.emit(time)
			AudioSystem.play_sfx("select")
		if time <= 0:
			_countdown_active = false
			if _countdown_callback.is_valid():
				_countdown_callback.call()
		return

	if state == GameState.PLAYING and not _level_finished and not timer_paused and time > 0:
		_time_accumulator += delta
		if _time_accumulator >= 0.4:
			_time_accumulator -= 0.4
			time -= 1
			SignalBus.time_updated.emit(time)

func start_game() -> void:
	world = 1
	level = 1
	lives = 3
	score = 0
	coins = 0
	state = GameState.TRANSITION

func begin_level() -> void:
	time = 400
	_time_accumulator = 0.0
	_level_finished = false
	_countdown_active = false
	state = GameState.PLAYING

func up_score(scr: int) -> void:
	score += scr
	if score > top_score:
		top_score = score
	SignalBus.score_updated.emit(score)

func add_coin() -> void:
	coins += 1
	if coins >= 100:
		coins = 0
		lives += 1
	SignalBus.coins_updated.emit(coins)

func on_player_died() -> void:
	lives -= 1
	if lives >= 0:
		state = GameState.TRANSITION
	else:
		lives = 3
		state = GameState.MENU

func get_level_key() -> String:
	return "%d-%d" % [world, level]

func get_level_scene_path() -> String:
	return "res://scenes/levels/%s.tscn" % get_level_key()

func level_complete() -> void:
	_level_finished = true
	_time_accumulator = 0.0

func countdown_time_to_score(callback: Callable) -> void:
	if time <= 0:
		_countdown_active = false
		if callback.is_valid():
			callback.call()
		return
	_time_accumulator = 0.0
	_countdown_callback = callback
	_countdown_active = true

func advance_level() -> void:
	_level_finished = false
	_countdown_active = false
	level += 1
	if level > 4:
		level = 1
		world += 1
	SignalBus.level_completed.emit()
	state = GameState.TRANSITION
