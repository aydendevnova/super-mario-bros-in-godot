# Outer UI - Custom UI / Debug Menus
extends CanvasLayer

var _debug_panel: PanelContainer
var _debug_label: Label
var _debug_visible := false
var _audio_viz_visible := false

@onready var _audio_viz = $AudioVisualizer

func _ready() -> void:
		_setup_debug_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F2:
		show()
		_audio_viz_visible = not _audio_viz_visible
		_audio_viz.visible = _audio_viz_visible
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		show()
		_debug_visible = not _debug_visible
		_debug_panel.visible = _debug_visible
		return

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
	lines.append("=== ENGINE ===")
	lines.append("FPS: %s" % Engine.get_frames_per_second())
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
