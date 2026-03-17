extends CanvasLayer

@onready var main_menu: CenterContainer = $MainMenu

@onready var hud: CenterContainer = $HUD
@onready var transition: Control = $Transition
@onready var transition_content: CenterContainer = $Transition/Transition

@onready var cursor_1p: TextureRect = get_node("MainMenu/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/1PlayerGame/HBoxContainer/Cursor")
@onready var cursor_2p: TextureRect = get_node("MainMenu/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/2PlayerGame/HBoxContainer/Cursor")

@onready var hud_score: Control = $HUD/MarginContainer/UI/BottomLine/Score
@onready var hud_coin: Control = $HUD/MarginContainer/UI/BottomLine/CoinDiv/Coin
@onready var hud_world: Control = $HUD/MarginContainer/UI/BottomLine/Control/World
@onready var hud_time: Control = $HUD/MarginContainer/UI/BottomLine/Time

@onready var trans_world: Control = $Transition/Transition/MarginContainer/VBoxContainer/HBoxContainer/Label
@onready var trans_lives: Control = $Transition/Transition/MarginContainer/VBoxContainer/VBoxContainer/MarginContainer/HBoxContainer2/MarginContainer/HBoxContainer/LivesLabel
@onready var load_timer: Timer = $Transition/Transition/LoadTimer

@onready var menu_top_score: Control = $MainMenu/MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/Label

var menu_selection: int = 0
var _pause_container: CenterContainer
var _debug_panel: PanelContainer
var _debug_label: Label
var _debug_visible := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	SignalBus.game_state_changed.connect(_on_state_changed)
	SignalBus.pipe_blackout.connect(_on_pipe_blackout)
	SignalBus.score_updated.connect(func(_v): _refresh_score())
	SignalBus.coins_updated.connect(func(v): hud_coin.text = "*%02d" % v)
	SignalBus.time_updated.connect(func(v):
		if Game.state == Game.GameState.PLAYING or Game.state == Game.GameState.DEAD:
			hud_time.text = str(v).lpad(3)
	)

	load_timer.wait_time = 3.0
	load_timer.one_shot = true
	load_timer.timeout.connect(_on_load_timer_timeout)

	_setup_pause_ui()
	_setup_debug_ui()
	_show_menu()

func _setup_pause_ui() -> void:
	_pause_container = CenterContainer.new()
	_pause_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_container.visible = false
	add_child(_pause_container)

	var text_node := Control.new()
	text_node.set_script(preload("res://ui/text_builder.gd"))
	text_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/palette_swap.gdshader")
	mat.set_shader_parameter("palette_id", 6)
	text_node.material = mat
	_pause_container.add_child(text_node)
	text_node.text = "PAUSE"
	text_node.scale_factor = 4

func _setup_debug_ui() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_panel.offset_left = 8
	_debug_panel.offset_top = 100
	_debug_panel.visible = false
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.set_content_margin_all(6)
	_debug_panel.add_theme_stylebox_override("panel", style)

	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", 13)
	_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_debug_panel.add_child(_debug_label)
	add_child(_debug_panel)

func _process(_delta: float) -> void:
	if _debug_visible:
		_debug_label.text = _build_debug_text()

func _build_debug_text() -> String:
	var lines: PackedStringArray = []
	var state_names := {0: "MENU", 1: "TRANSITION", 2: "PLAYING", 3: "DEAD"}
	lines.append("=== GAME ===")
	lines.append("State: %s" % state_names.get(Game.state, "?"))
	lines.append("World: %s" % Game.get_level_key())
	lines.append("Time: %d" % Game.time)
	lines.append("Timer paused: %s" % Game.timer_paused)
	lines.append("Level finished: %s" % Game._level_finished)
	var theme_names := {0: "OVERWORLD", 1: "UNDERGROUND", 2: "CASTLE", 3: "UNDERWATER"}
	lines.append("Palette: %s" % theme_names.get(Game.lvl_palette, "?"))
	var player = get_tree().root.find_child("Player", true, false) as Player
	if player:
		var pstate := {0: "SMALL", 1: "BIG", 2: "FIRE"}
		lines.append("")
		lines.append("=== PLAYER ===")
		lines.append("State: %s" % pstate.get(player.state, "?"))
		lines.append("Star: %s" % player.star_power)
		lines.append("Cooldown: %s" % player.has_cooldown)
		lines.append("Locked: %s" % player.is_locked)
		lines.append("Pipe: %s" % player.entering_pipe)
		lines.append("Dead: %s" % player.is_dead)
		lines.append("Pos: (%.0f, %.0f)" % [player.position.x, player.position.y])
		lines.append("Vel: (%.0f, %.0f)" % [player.velocity.x, player.velocity.y])
		lines.append("Floor: %s" % player.is_on_floor())
		lines.append("Jump: %s" % player.is_jumping)
		lines.append("Fall: %s" % player.is_falling)
	var audio: Dictionary = AudioSystem.get_debug_info()
	lines.append("")
	lines.append("=== AUDIO ===")
	lines.append("Music: %s" % audio.track)
	var ch_names := ["P1", "P2", "TR", "NS"]
	for i in 4:
		var ch: Dictionary = audio.channels[i]
		var src := ""
		if ch.sfx:
			src = "SFX %.2fs" % ch.sfx_left
		elif ch.playing:
			src = "music"
		else:
			src = "---"
		var stream_short: String = ch.stream.get_file().get_basename() if ch.stream != "" else ""
		lines.append("%s: %s %s" % [ch_names[i], src, stream_short])
	return "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_debug_visible = not _debug_visible
		_debug_panel.visible = _debug_visible
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		if Game.is_paused:
			_toggle_pause()
		elif Game.state == Game.GameState.MENU:
			Game.start_game()
		elif Game.state == Game.GameState.PLAYING and not get_tree().paused:
			_toggle_pause()
		return

	if Game.state == Game.GameState.MENU:
		if event.is_action_pressed("ui_down") or event.is_action_pressed("crouch"):
			menu_selection = 1
			_update_cursor()
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("jump"):
			menu_selection = 0
			_update_cursor()

func _toggle_pause() -> void:
	Game.is_paused = not Game.is_paused
	get_tree().paused = Game.is_paused
	_pause_container.visible = Game.is_paused

func _update_cursor() -> void:
	cursor_1p.modulate.a = 1.0 if menu_selection == 0 else 0.0
	cursor_2p.modulate.a = 1.0 if menu_selection == 1 else 0.0

func _show_menu() -> void:
	main_menu.visible = true
	hud.visible = true
	transition.visible = false
	menu_selection = 0
	_update_cursor()
	_refresh_hud()
	hud_time.text = ""

func _show_transition() -> void:
	main_menu.visible = false
	hud.visible = true
	transition_content.visible = true
	transition.visible = true
	trans_world.text = "WORLD %s" % Game.get_level_key()
	trans_lives.text = str(Game.lives)
	_refresh_hud()
	hud_time.text = ""
	load_timer.start()

func _show_gameplay() -> void:
	main_menu.visible = false
	hud.visible = true
	transition.visible = false

func _on_state_changed(new_state) -> void:
	match new_state:
		Game.GameState.MENU:
			_show_menu()
		Game.GameState.TRANSITION:
			_show_transition()
		Game.GameState.PLAYING:
			_show_gameplay()

func _on_load_timer_timeout() -> void:
	Game.begin_level()

func _refresh_score() -> void:
	hud_score.text = "%06d" % Game.score
	menu_top_score.text = "TOP- %06d" % Game.top_score

func _refresh_hud() -> void:
	hud_score.text = "%06d" % Game.score
	hud_coin.text = "*%02d" % Game.coins
	hud_world.text = Game.get_level_key()
	hud_time.text = str(Game.time).lpad(3)
	menu_top_score.text = "TOP- %06d" % Game.top_score

func _on_pipe_blackout(active: bool) -> void:
	if active:
		transition_content.visible = false
		transition.visible = true
	else:
		transition.visible = false
