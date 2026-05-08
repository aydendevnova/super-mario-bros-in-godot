extends Node

class_name PlayerPowerState

@export var state_name: StringName = &"power_state"

var machine: PlayerPowerStateMachine
var player: Player

func setup(power_machine: PlayerPowerStateMachine, target_player: Player) -> void:
	machine = power_machine
	player = target_player

func enter(_previous_state: StringName) -> void:
	pass

func exit(_next_state: StringName) -> void:
	pass

func process_input() -> void:
	pass
