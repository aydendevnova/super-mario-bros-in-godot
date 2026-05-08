extends PlayerMovementState

func enter(_previous_state: StringName) -> void:
	player.set_crouching(false)

func physics_update(delta: float) -> void:
	player.velocity.x = player.auto_walk_speed
	player.apply_gravity(delta, false)

func update_animation() -> bool:
	player.sprite.flip_h = false
	player.sprite.speed_scale = 1
	player.sprite.play("Walk")
	return true

func get_next_state() -> StringName:
	if not player.auto_walk_right:
		return &"idle"
	return StringName()
