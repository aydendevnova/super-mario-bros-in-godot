extends Node

const GAME_ACTIONS := [
	"jump", "move_left", "move_right", "run", "crouch", "select", "start"
]

var _saved_events := {}
var _is_cleared := false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if not _is_cleared:
			print("FOCUS OUT - saving")
			_save_and_clear()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if _is_cleared:
			print("FOCUS IN - restoring")
			_restore()

func _save_and_clear() -> void:
	_saved_events.clear()
	for action in GAME_ACTIONS:
		if not InputMap.has_action(action):
			continue
		_saved_events[action] = InputMap.action_get_events(action)
		Input.action_release(action)
		for event in _saved_events[action]:
			InputMap.action_erase_event(action, event)
	_is_cleared = true

func _restore() -> void:
	for action in _saved_events:
		Input.action_release(action)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for event in _saved_events[action]:
			InputMap.action_add_event(action, event)
		print("  restored: ", action, " -> ", InputMap.action_get_events(action).size(), " events")
	_saved_events.clear()
	_is_cleared = false
