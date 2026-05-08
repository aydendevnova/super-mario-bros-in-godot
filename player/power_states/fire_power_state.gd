extends PlayerPowerState


func process_input() -> void:
	if not Input.is_action_just_pressed("run"):
		return
	_try_shoot_fireball()

func _try_shoot_fireball() -> void:
	var nearby := 0
	for fireball in player.get_tree().get_nodes_in_group("fireballs"):
		if fireball.global_position.distance_to(player.global_position) < player.FIREBALL_MIN_DISTANCE:
			nearby += 1
	if nearby >= player.MAX_FIREBALLS:
		return

	var spawned_fireball := player.FIREBALL_SCENE.instantiate()
	spawned_fireball.add_to_group("fireballs")
	spawned_fireball.direction = -1.0 if player.is_facing_left else 1.0
	spawned_fireball.position = Game.current_level.to_local(player.global_position) + Vector2(8 if not player.is_facing_left else -4, 4)
	Game.current_level.add_child(spawned_fireball)
	AudioSystem.play_sfx("fireball")
