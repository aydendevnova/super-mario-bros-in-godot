extends CanvasLayer

var _pause_container: CenterContainer
var _sfx_player: AudioStreamPlayer
var _pause_sfx := preload("res://assets/sfx/pause__pulse1.ogg")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_player.bus = "Master"
	add_child(_sfx_player)

	_setup_pause_ui()

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

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("start"):
		return
	if Game.is_paused:
		_unpause()
	elif Game.state == Game.GameState.PLAYING and not get_tree().paused:
		_pause()

func _play_pause_sfx() -> void:
	_sfx_player.stream = _pause_sfx
	_sfx_player.play()

func _pause() -> void:
	Game.is_paused = true
	_pause_container.visible = true
	_play_pause_sfx()
	AudioSystem.pause_streams()
	get_tree().paused = true

func _unpause() -> void:
	Game.is_paused = false
	_pause_container.visible = false
	get_tree().paused = false
	AudioSystem.unpause_streams_muted()
	_play_pause_sfx()
	_sfx_player.finished.connect(_on_unpause_sfx_finished, CONNECT_ONE_SHOT)

func _on_unpause_sfx_finished() -> void:
	AudioSystem.end_pause_mute()
