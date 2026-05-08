extends PlayerMovementState

func enter(_previous_state: StringName) -> void:
	pass

func physics_update(delta: float) -> void:
	player.apply_floor_friction(delta)

func update_animation() -> bool:
	if abs(player.velocity.x) > player.MIN_SPEED:
		player.sprite.play("Walk")
		player.sprite.speed_scale = player._get_walk_animation_speed_scale()
	else:
		player.sprite.play("Idle")
	return true

func get_next_state() -> StringName:
	if not player.is_on_floor():
		return &"fall"
	if player.should_jump():
		return &"jump"
	if player.should_crouch():
		return &"crouch"
	if player.input_axis.x != 0.0:
		return &"sprint" if player.should_sprint() else &"walk"
	return StringName()
