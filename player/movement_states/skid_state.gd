extends PlayerMovementState

func enter(_previous_state: StringName) -> void:
	pass

func exit(_next_state: StringName) -> void:
	pass

func physics_update(delta: float) -> void:
	player.apply_skid_friction(delta)

func update_animation() -> bool:
	player.sprite.play("Skid")
	return true

func get_next_state() -> StringName:
	if not player.is_on_floor():
		return &"fall"
	if player.should_jump():
		return &"jump"
	if player.should_crouch():
		return &"crouch"
	if abs(player.velocity.x) < player.MIN_SLOW_DOWN_SPEED:
		if player.input_axis.x == 0.0:
			return &"idle"
		return &"sprint" if player.should_sprint() else &"walk"
	return StringName()
