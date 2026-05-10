extends MarginContainer

signal game_start_requested
signal options_requested

@onready var _cursors: Array[TextureRect] = [
	get_node("VBoxContainer/1PlayerGame/HBoxContainer/Cursor"),
	get_node("VBoxContainer/2PlayerGame/HBoxContainer/Cursor"),
	get_node("VBoxContainer/Options/HBoxContainer/Cursor"),
]

var _selection: int = 0

func _ready() -> void:
	set_process_unhandled_input(false)

func activate(at_selection: int = 0) -> void:
	visible = true
	_selection = clampi(at_selection, 0, _cursors.size() - 1)
	_update_cursors()
	set_process_unhandled_input(true)

func deactivate() -> void:
	visible = false
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or event.is_action_pressed("crouch"):
		_selection = (_selection + 1) % _cursors.size()
		_update_cursors()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("jump"):
		_selection = (_selection - 1 + _cursors.size()) % _cursors.size()
		_update_cursors()
	elif event.is_action_pressed("start") or event.is_action_pressed("ui_accept"):
		match _selection:
			0, 1:
				game_start_requested.emit()
			2:
				options_requested.emit()

func _update_cursors() -> void:
	for i in _cursors.size():
		_cursors[i].modulate.a = 1.0 if i == _selection else 0.0
