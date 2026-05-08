extends PlayerMovementState

@export var climb_speed := 72.0

func enter(_previous_state: StringName) -> void:
	player.velocity = Vector2.ZERO
	player.set_crouching(false)

func physics_update(_delta: float) -> void:
	var vertical := Input.get_axis("jump", "crouch")
	player.velocity.x = 0.0
	player.velocity.y = vertical * climb_speed

func update_animation() -> bool:
	if abs(player.velocity.y) > 0.0:
		player.sprite.play("Walk")
		player.sprite.speed_scale = 1.0
	else:
		player.sprite.play("Idle")
	return true

func get_next_state() -> StringName:
	if not player.climbing_vine:
		if player.is_on_floor():
			return &"idle"
		return &"fall"
	return StringName()
