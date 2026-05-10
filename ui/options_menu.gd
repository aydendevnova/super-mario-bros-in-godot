extends MarginContainer

signal back_requested

const PALETTE_SELECTED := 4
const PALETTE_DEFAULT := 6

var _selection: int = 0
var _toggle_keys: Array[String] = ["allow_going_back", "allow_widescreen", "four_channel_audio"]

var _labels: Array[Control] = []
var _cursors: Array[TextureRect] = []
var _item_count: int = 0

func _ready() -> void:
	set_process_unhandled_input(false)
	visible = false

	var items: Array[Node] = [
		$VBoxContainer/AllowGoingBack,
		$VBoxContainer/AllowWidescreen,
		$"VBoxContainer/4ChannelAudio",
		$VBoxContainer/Back,
	]
	_item_count = items.size()

	for item in items:
		var label: Control = item.get_node("HBoxContainer/Label")
		var cursor: TextureRect = item.get_node("HBoxContainer/Cursor")
		label.material = label.material.duplicate()
		_labels.append(label)
		_cursors.append(cursor)

func activate() -> void:
	visible = true
	_selection = 0
	_refresh_all()
	set_process_unhandled_input(true)

func deactivate() -> void:
	visible = false
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or event.is_action_pressed("crouch"):
		_selection = (_selection + 1) % _item_count
		_refresh_highlight()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("jump"):
		_selection = (_selection - 1 + _item_count) % _item_count
		_refresh_highlight()
	elif event.is_action_pressed("start") or event.is_action_pressed("ui_accept"):
		_confirm_selection()

func _confirm_selection() -> void:
	if _selection < _toggle_keys.size():
		var key := _toggle_keys[_selection]
		Game.set(key, not Game.get(key))
		_refresh_toggle(_selection)
		Game.save_settings()
	else:
		back_requested.emit()

func _refresh_all() -> void:
	_refresh_highlight()
	for i in _toggle_keys.size():
		_refresh_toggle(i)
	_cursors[_item_count - 1].modulate.a = 0.0

func _refresh_highlight() -> void:
	for i in _labels.size():
		var mat: ShaderMaterial = _labels[i].material as ShaderMaterial
		mat.set_shader_parameter("palette_id", PALETTE_SELECTED if i == _selection else PALETTE_DEFAULT)

func _refresh_toggle(index: int) -> void:
	if index < _toggle_keys.size():
		var on: bool = Game.get(_toggle_keys[index])
		_cursors[index].modulate.a = 1.0 if on else 0.0
