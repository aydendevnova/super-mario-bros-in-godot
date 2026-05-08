extends PlayerMovementState

func enter(_previous_state: StringName) -> void:
	player.velocity = Vector2.ZERO
	player.input_axis = Vector2.ZERO
	player.set_crouching(false)

func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO

func get_next_state() -> StringName:
	if not player.is_locked:
		if player.input_axis.x != 0.0:
			return &"sprint" if player.should_sprint() else &"walk"
		return &"idle"
	return StringName()
