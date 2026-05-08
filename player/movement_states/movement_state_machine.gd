extends Node

class_name PlayerMovementStateMachine

@export var initial_state_name: StringName = &"idle"

var player: Player
var _states: Dictionary = {}
var _current_state: PlayerMovementState

func _ready() -> void:
	for child in get_children():
		if child is PlayerMovementState:
			var state := child as PlayerMovementState
			_states[state.state_name] = state

func setup(target_player: Player) -> void:
	player = target_player
	for state in _states.values():
		(state as PlayerMovementState).setup(self, player)

	if not _states.has(initial_state_name):
		push_error("Missing initial player movement state: %s" % initial_state_name)
		return
	transition_to(initial_state_name, true)

func physics_update(delta: float) -> void:
	if not _current_state:
		return

	var forced_state := _current_state.get_forced_state()
	if forced_state != StringName() and forced_state != _current_state.state_name and _states.has(forced_state):
		transition_to(forced_state)

	_current_state.physics_update(delta)

	forced_state = _current_state.get_forced_state()
	if forced_state != StringName() and forced_state != _current_state.state_name and _states.has(forced_state):
		transition_to(forced_state)
		return

	var next_state := _current_state.get_next_state()
	if next_state != StringName() and next_state != _current_state.state_name:
		transition_to(next_state)

func transition_to(state: StringName, is_initial: bool = false) -> void:
	if not _states.has(state):
		return

	if _current_state and not _current_state.can_transition_to(state):
		return

	var previous_state := StringName()
	if _current_state:
		previous_state = _current_state.state_name
		_current_state.exit(state)

	_current_state = _states[state]
	_current_state.enter(previous_state if not is_initial else StringName())
	player.set_movement_state_name(state)

func get_current_state_name() -> StringName:
	if not _current_state:
		return StringName()
	return _current_state.state_name

func update_animation() -> bool:
	if not _current_state:
		return false
	return _current_state.update_animation()
