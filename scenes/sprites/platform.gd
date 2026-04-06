@tool
extends Node2D

enum MovementType {
	HORIZONTAL,
	VERTICAL,
	UP,
	DOWN,
	DROP,
	BALANCE,
}

@export var movement_type: MovementType = MovementType.HORIZONTAL
