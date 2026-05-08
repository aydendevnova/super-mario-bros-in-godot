extends PlayerMovementState

func enter(_previous_state: StringName) -> void:
	player.begin_jump()

func physics_update(delta: float) -> void:
	player.apply_air_movement(delta)
	player.apply_gravity(delta, true)

func update_animation() -> bool:
	player.sprite.play("Jump")
	return true

func get_next_state() -> StringName:
	if player.velocity.y >= 0.0:
		return &"fall"
	return StringName()
