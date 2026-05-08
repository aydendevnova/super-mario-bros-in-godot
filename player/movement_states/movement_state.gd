extends Node

class_name PlayerMovementState

@export var state_name: StringName = &"state"

var machine: PlayerMovementStateMachine
var player: Player

func setup(movement_machine: PlayerMovementStateMachine, target_player: Player) -> void:
	machine = movement_machine
	player = target_player

func enter(_previous_state: StringName) -> void:
	pass

func exit(_next_state: StringName) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func get_next_state() -> StringName:
	return StringName()

func can_transition_to(_state: StringName) -> bool:
	return true

func update_animation() -> bool:
	return false

func get_forced_state() -> StringName:
	return StringName()
