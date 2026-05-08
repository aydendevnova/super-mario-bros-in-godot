extends Node

class_name PlayerPowerStateMachine

@export var initial_state_name: StringName = &"small"

var player: Player
var _states: Dictionary = {}
var _current_state: PlayerPowerState

const ENUM_TO_NAME := {
	Player.State.SMALL: &"small",
	Player.State.BIG: &"big",
	Player.State.FIRE: &"fire"
}

const NAME_TO_ENUM := {
	&"small": Player.State.SMALL,
	&"big": Player.State.BIG,
	&"fire": Player.State.FIRE
}

func _ready() -> void:
	for child in get_children():
		if child is PlayerPowerState:
			var state := child as PlayerPowerState
			_states[state.state_name] = state

func setup(target_player: Player) -> void:
	player = target_player
	for state in _states.values():
		(state as PlayerPowerState).setup(self, player)

	if not _states.has(initial_state_name):
		push_error("Missing initial player power state: %s" % initial_state_name)
		return

	transition_to(initial_state_name, true)

func transition_to_enum(next_state: Player.State) -> void:
	var next_state_name: StringName = ENUM_TO_NAME.get(next_state, StringName())
	if next_state_name == StringName():
		return
	transition_to(next_state_name)

func transition_to(next_state_name: StringName, is_initial: bool = false) -> void:
	if not _states.has(next_state_name):
		return

	var previous_state_name := StringName()
	if _current_state:
		previous_state_name = _current_state.state_name
		if previous_state_name == next_state_name:
			return
		_current_state.exit(next_state_name)

	_current_state = _states[next_state_name]
	_current_state.enter(previous_state_name if not is_initial else StringName())
	player.set_power_state_name(next_state_name)
	player.apply_power_state(NAME_TO_ENUM[next_state_name], previous_state_name if not is_initial else StringName(), is_initial)

func get_current_state_name() -> StringName:
	if not _current_state:
		return StringName()
	return _current_state.state_name

func process_input() -> void:
	if not _current_state:
		return
	_current_state.process_input()
