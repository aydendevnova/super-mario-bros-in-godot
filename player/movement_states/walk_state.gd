extends PlayerMovementState

func enter(_previous_state: StringName) -> void:
	pass

func physics_update(delta: float) -> void:
	player.update_facing_from_input()
	player.apply_ground_movement(delta, player.MAX_WALK_SPEED, player.WALK_ACCELERATION)

func update_animation() -> bool:
	player.sprite.play("Walk")
	player.sprite.speed_scale = player._get_walk_animation_speed_scale()
	return true

func get_next_state() -> StringName:
	if not player.is_on_floor():
		return &"fall"
	if player.should_jump():
		return &"jump"
	if player.should_crouch():
		return &"crouch"
	if player.should_skid():
		return &"skid"
	if player.input_axis.x == 0.0:
		return &"idle"
	if player.should_sprint():
		return &"sprint"
	return StringName()
