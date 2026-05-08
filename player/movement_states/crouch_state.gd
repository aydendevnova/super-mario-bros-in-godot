extends PlayerMovementState

func enter(_previous_state: StringName) -> void:
	player.set_crouching(true)

func physics_update(delta: float) -> void:
	player.apply_floor_friction(delta, player.MIN_SLOW_DOWN_SPEED)

func update_animation() -> bool:
	player.sprite.play("Crouch")
	return true

func get_next_state() -> StringName:
	if not player.is_on_floor():
		return &"fall"
	if player.should_jump():
		return &"jump"
	if player.should_crouch():
		return StringName()
	if not player.set_crouching(false):
		return StringName()
	if player.input_axis.x != 0.0:
		return &"sprint" if player.should_sprint() else &"walk"
	return &"idle"
