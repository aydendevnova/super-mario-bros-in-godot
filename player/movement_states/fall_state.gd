extends PlayerMovementState

func enter(_previous_state: StringName) -> void:
	pass

func physics_update(delta: float) -> void:
	player.apply_air_movement(delta)
	player.apply_gravity(delta, false)

func update_animation() -> bool:
	player.sprite.stop()
	return true

func get_next_state() -> StringName:
	if player.is_on_floor():
		if player.should_crouch():
			return &"crouch"
		if player.input_axis.x != 0.0:
			return &"sprint" if player.should_sprint() else &"walk"
		return &"idle"
	return StringName()
