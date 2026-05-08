extends PlayerMovementState

func enter(_previous_state: StringName) -> void:
	pass

func physics_update(delta: float) -> void:
	player.update_facing_from_input()
	var sprint_acceleration := player.RUN_ACCELERATION if abs(player.velocity.x) >= player.MAX_WALK_SPEED else player.WALK_ACCELERATION
	player.apply_ground_movement(delta, player.MAX_SPEED, sprint_acceleration)

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
	if not player.should_sprint():
		return &"walk"
	return StringName()
