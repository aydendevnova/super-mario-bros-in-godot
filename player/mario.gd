extends CharacterBody2D

class_name Player

const MIN_SPEED = 4.453125
const MAX_SPEED = 153.75
const MAX_WALK_SPEED = 93.75
const MAX_FALL_SPEED = 270.0
const MIN_SLOW_DOWN_SPEED = 33.75

const WALK_ACCELERATION = 133.59375
const RUN_ACCELERATION = 200.390625
const WALK_FRICTION = 182.8125
const SKID_FRICTION = 365.625

# Jump physics vary based on horizontal speed thresholds
const JUMP_SPEED = [-240.0, -240.0, -300.0]
const LONG_JUMP_GRAVITY = [450.0, 421.875, 562.5]
const GRAVITY = [1575.0, 1350.0, 2025.0]

const SPEED_THRESHOLDS = [60, 138.75]

const STOMP_SPEED = 240.0
const STOMP_SPEED_CAP = -80.0
const STOMP_TOLERANCE = 8.0
const CORNER_CORRECTION_PX := 2

const COOLDOWN_TIME_SEC = 3.0
const STAR_DURATION := 10.0
const STAR_WARNING_TIME := 3.0
const STAR_PALETTE_INTERVAL := 0.05
const STAR_WARNING_PALETTE_INTERVAL := 0.15
const STAR_PALETTES := [27, 24, 44, 27]
const POINTS_POPUP := preload("res://scenes/sprites/points_popup.tscn")
const FIREBALL_SCENE := preload("res://scenes/sprites/fireball.tscn")
const FIREBALL_MIN_DISTANCE := 112
const MAX_FIREBALLS := 2

# Input
var spawnpoint = Vector2(48, -7)

var is_facing_left = false
var is_running = false
var is_jumping = false
var is_falling = false
var is_skiding = false
var is_crouching = false
var entering_pipe = false
var is_locked = false
var auto_walk_right = false
var camera_frozen := false
var _camera_frozen_pos := Vector2.ZERO

var _old_velocity = Vector2.ZERO

var input_axis = Vector2.ZERO
var speed_scale = 0.0

var min_speed = MIN_SPEED
var max_speed = MAX_WALK_SPEED
var acceleration = WALK_ACCELERATION

var speed_threshold: int = 0

var lives = 3
var is_dead = false

enum State { SMALL, BIG, FIRE }

var state = State.BIG:
	set(value):
		if state != value:
			state = value
			
			match state:
				State.SMALL:
					transition_sprite.animation = "shrink"
				State.BIG, State.FIRE:
					transition_sprite.animation = "grow"
			
			transition_sprite.flip_h = sprite.flip_h
			play_transition()
			

var has_cooldown = false
var star_power := false
var _star_timer := 0.0
var _star_palette_timer := 0.0
var _star_palette_index := 0
var _is_transitioning = false
var _blink_timer: float = 0.0
const COOLDOWN_BLINK_INTERVAL = 0.025
const TRANSITION_BLINK_INTERVAL = 0.05
var _death_tween: Tween

var collected_item_ref: Node = null

# Nodes
@onready var camera: Camera2D = get_node("Camera2D")
@onready var tranistion_timer = $TransitionTimer
signal points_scored(points: int)

@onready var sprite = $SmallSprite

@onready var small_sprite: AnimatedSprite2D = $SmallSprite
@onready var big_sprite: AnimatedSprite2D = $BigSprite
@onready var transition_sprite: AnimatedSprite2D = $TransitionSprite

@onready var hitbox: Area2D = $Hitbox
@onready var small_hitbox_shape: CollisionShape2D = $Hitbox/SmallHitbox
@onready var big_hitbox_shape: CollisionShape2D = $Hitbox/BigHitbox

@onready var small_collision_shape: CollisionShape2D = $SmallCollisionShape
@onready var big_collision_shape: CollisionShape2D = $BigCollisionShape

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_tree()
	camera.make_current()

func _process(delta):
	_process_star_power(delta)
	_process_blink(delta)
	if camera_frozen:
		camera.global_position.x = _camera_frozen_pos.x
	if get_tree().paused:
		sprite.pause()
		return
	if not is_locked:
		process_input()
	process_animation()

func _physics_process(delta):
	if get_tree().paused:
		return

	if auto_walk_right:
		velocity.x = MAX_WALK_SPEED / 1.8
		velocity.y += GRAVITY[0] * delta
		if velocity.y > MAX_FALL_SPEED:
			velocity.y = MAX_FALL_SPEED
		move_and_slide()
		return

	if is_locked:
		return

	process_jump(delta)
	process_walk(delta)
	#process_camera_bounds()
	
	_old_velocity = velocity

	move_and_slide()
	if not _corner_correct():
		handle_last_collision()
	
	if (position.y > (Game.bottom_of_map_y + 16) && not is_dead):
		handle_death()
	
func process_camera_bounds():
	if global_position.x > camera.position.x and global_position.y <= 0:
		camera.position.x = global_position.x
	
	var camera_left_bound = 8 + camera.position.x - get_viewport_rect().size.x / 2 / camera.zoom.x

	if global_position.x <= camera_left_bound:
		velocity.x = 0
		global_position.x = camera_left_bound + .001

func process_input():
	input_axis.x = Input.get_axis("move_left", "move_right")
	input_axis.y = Input.get_axis("jump", "crouch")

	var was_crouching = is_crouching
	
	if is_on_floor():
		is_running = Input.is_action_pressed("run")
		is_crouching = Input.is_action_pressed("crouch")

		if is_crouching and input_axis.x:
			is_crouching = false
			input_axis.x = 0.0

		if was_crouching and not is_crouching and state != State.SMALL:
			if not _can_stand_up():
				is_crouching = true

	if is_crouching != was_crouching:
		_update_tree()

	if state == State.FIRE and Input.is_action_just_pressed("run"):
		_try_shoot_fireball()

func process_jump(delta: float):
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			is_jumping = true
			AudioSystem.play_sfx("jump_small" if state == State.SMALL else "jump_super")
			var speed = abs(velocity.x)

			speed_threshold = SPEED_THRESHOLDS.size()

			for i in SPEED_THRESHOLDS.size():
				if speed < SPEED_THRESHOLDS[i]:
					speed_threshold = i
					break
			
			velocity.y = JUMP_SPEED[speed_threshold]
	else:
		var gravity = GRAVITY[speed_threshold]
		
		if Input.is_action_pressed("jump") and not is_falling:
			gravity = LONG_JUMP_GRAVITY[speed_threshold]
		
		velocity.y = velocity.y + gravity * delta
		
		if velocity.y > MAX_FALL_SPEED:
			velocity.y = MAX_FALL_SPEED
	
	if velocity.y > 0:
		is_jumping = false
		is_falling = true
	elif is_on_floor():
		is_falling = false

func process_walk(delta: float):
	if input_axis.x:
		if is_on_floor():
			if velocity.x:
				is_facing_left = input_axis.x < 0.0
				is_skiding = velocity.x < 0.0 != is_facing_left
				
			if is_skiding:
				min_speed = MIN_SLOW_DOWN_SPEED
				max_speed = MAX_WALK_SPEED
				acceleration = SKID_FRICTION
			elif is_running:
				min_speed = MIN_SPEED
				max_speed = MAX_SPEED
				acceleration = RUN_ACCELERATION
			else:
				min_speed = MIN_SPEED
				max_speed = MAX_WALK_SPEED
				acceleration = WALK_ACCELERATION
		elif is_running and abs(velocity.x) > MAX_WALK_SPEED:
			max_speed = MAX_SPEED
		else:
			max_speed = MAX_WALK_SPEED
		
		var target_speed = input_axis.x * max_speed
		
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		
	elif is_on_floor() and velocity.x:
		if not is_skiding:
			acceleration = WALK_FRICTION
		
		if input_axis.y:
			min_speed = MIN_SLOW_DOWN_SPEED
		else:
			min_speed = MIN_SPEED
		
		if abs(velocity.x) < min_speed:
			velocity.x = 0.0
		else:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	
	if abs(velocity.x) < MIN_SLOW_DOWN_SPEED:
		is_skiding = false
	
	speed_scale = abs(velocity.x) / MAX_SPEED
	
func _can_stand_up() -> bool:
	small_collision_shape.disabled = true
	big_collision_shape.disabled = false
	var blocked := test_move(global_transform, Vector2.ZERO)
	big_collision_shape.disabled = true
	small_collision_shape.disabled = false
	return not blocked

func _try_shoot_fireball() -> void:
	var nearby := 0
	for fb in get_tree().get_nodes_in_group("fireballs"):
		if fb.global_position.distance_to(global_position) < FIREBALL_MIN_DISTANCE:
			nearby += 1
	if nearby >= MAX_FIREBALLS:
		return
	var fireball := FIREBALL_SCENE.instantiate()
	fireball.add_to_group("fireballs")
	fireball.direction = -1.0 if is_facing_left else 1.0
	fireball.position = Game.current_level.to_local(global_position) + Vector2(8 if not is_facing_left else -4, 4)
	Game.current_level.add_child(fireball)
	AudioSystem.play_sfx("fireball")

func _corner_correct() -> bool:
	if _old_velocity.y >= 0 or velocity.y < 0:
		return false
	for px in range(1, CORNER_CORRECTION_PX + 1):
		for dir in [1.0, -1.0]:
			var nudge = Vector2(dir * px, 0)
			if not test_move(global_transform, nudge):
				if not test_move(Transform2D(0, global_position + nudge), Vector2(0, -1)):
					position.x += dir * min(px, 1)
					velocity.y = _old_velocity.y - 4
					return true
	return false

func handle_last_collision():
	if get_slide_collision_count() == 0:
		return

	var head_hit := false
	var slide_collider: Node = null

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var normal = collision.get_normal() * -1.0

		if normal != round(normal):
			velocity.y = _old_velocity.y

		if normal == Vector2.UP:
			head_hit = true
			var collider = collision.get_collider()
			if collider.has_method("hit"):
				slide_collider = collider

	if head_hit:
		var block := _find_block_above()
		if not block:
			block = slide_collider
		if block:
			block.hit(self)

func _find_block_above() -> Node:
	var active_shape = small_collision_shape if state == State.SMALL else big_collision_shape
	var head_x: float = global_position.x + active_shape.position.x
	var head_y: float = global_position.y + active_shape.position.y - active_shape.shape.size.y / 2.0

	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Vector2(head_x, head_y - 4.0)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]

	var results := space.intersect_point(query)
	var best: Node = null
	var best_dist := INF

	for result in results:
		var collider = result.collider
		if collider.has_method("hit"):
			var dist: float = abs(head_x - (collider.global_position.x + 8.0))
			if dist < best_dist:
				best_dist = dist
				best = collider
	return best

func _process_blink(delta: float) -> void:
	if _is_transitioning or has_cooldown:
		var interval = TRANSITION_BLINK_INTERVAL if _is_transitioning else COOLDOWN_BLINK_INTERVAL
		_blink_timer += delta
		if _blink_timer >= interval:
			_blink_timer -= interval
			modulate.a = 0.0 if modulate.a else 1.0
	else:
		_blink_timer = 0.0

func process_animation():
	if is_locked and not auto_walk_right:
		if not has_cooldown and not _is_transitioning:
			modulate.a = 1.0
		return

	sprite.flip_h = is_facing_left
	sprite.speed_scale = max(2.5, speed_scale * 6.0) if is_running else max(1.75, speed_scale * 4.0)
	
	if is_dead:
		sprite.play("Dying")
		return

	if auto_walk_right:
		sprite.flip_h = false
		sprite.speed_scale = 1
		sprite.play("Walk")
		if not has_cooldown and not _is_transitioning:
			modulate.a = 1.0
		return
	
	if is_falling:
		sprite.stop()
	elif is_crouching and state:
		sprite.play("Crouch")
	elif is_jumping:
		sprite.play("Jump")
	elif is_skiding:
		sprite.play("Skid")
	elif input_axis.x or velocity.x:
		sprite.play("Walk")
	else:
		sprite.play("Idle")

	if not has_cooldown and not _is_transitioning:
		modulate.a = 1.0

func _update_tree():
	var is_small = not state
	var is_crouching_or_small = is_crouching or is_small

	sprite = small_sprite if is_small else big_sprite

	small_sprite.visible = is_small	
	big_sprite.visible = not is_small

	#big_collision_shape.disabled = is_crouching_or_small
	big_collision_shape.set_deferred("disabled", is_crouching_or_small)
	big_hitbox_shape.set_deferred("disabled", is_crouching_or_small)
	#big_hitbox_shape.disabled = is_crouching_or_small

	# small_collision_shape.disabled = not is_crouching_or_small
	# small_hitbox_shape.disabled = not is_crouching_or_small

	small_collision_shape.set_deferred("disabled", not is_crouching_or_small)
	small_hitbox_shape.set_deferred("disabled", not is_crouching_or_small)

	var palette_id = 23 if state == State.FIRE else 21
	small_sprite.material.set_shader_parameter("palette_id", palette_id)

func lock_player() -> void:
	is_locked = true
	velocity = Vector2.ZERO
	input_axis = Vector2.ZERO
	is_jumping = false
	is_falling = false
	is_skiding = false
	is_crouching = false

func unlock_player() -> void:
	is_locked = false
	auto_walk_right = false
	camera_frozen = false

func freeze_camera() -> void:
	camera_frozen = true
	_camera_frozen_pos = camera.global_position

func unfreeze_camera() -> void:
	camera_frozen = false
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 3.0

func snap_camera() -> void:
	camera_frozen = false
	camera.position_smoothing_enabled = false

	camera.limit_bottom = int(Game.bottom_of_map_y)
	camera.limit_top = int(Game.bottom_of_map_y) - 244+4
	camera.reset_smoothing()
	camera.force_update_scroll()

func transform(to_state: State):
	state = to_state	
	
func handle_death():
	tranistion_timer.start()
	is_dead = true
	Game.state = Game.GameState.DEAD

	set_physics_process(false)
	set_collision_layer_value(1, false)

	var fell_off_map := position.y > (Game.bottom_of_map_y + 16)

	if not fell_off_map:
		var start_pos := position
		_death_tween = get_tree().create_tween()
		_death_tween.tween_interval(0.2)
		_death_tween.tween_property(self, "position", start_pos + Vector2(0, -32), 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_death_tween.tween_property(self, "position", start_pos + Vector2(0, 192), 0.9) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_transition_timer_timeout() -> void:
	tranistion_timer.stop()
	SignalBus.player_died.emit()

func reset() -> void:
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
		_death_tween = null
	if tranistion_timer and not tranistion_timer.is_stopped():
		tranistion_timer.stop()
	is_dead = false
	velocity = Vector2.ZERO
	has_cooldown = false
	star_power = false
	_star_timer = 0.0
	is_locked = false
	auto_walk_right = false
	camera_frozen = false
	camera.position_smoothing_enabled = false
	_is_transitioning = false
	_blink_timer = 0.0
	modulate.a = 1.0

func take_hit():
	if is_dead or star_power:
		return
	if state == State.SMALL:
		handle_death()
	else:
		AudioSystem.play_sfx("pipe")
		transform(state - 1)
		_cooldown()

func _cooldown():
	has_cooldown = true
	get_tree().create_timer(COOLDOWN_TIME_SEC).connect("timeout", func():
		has_cooldown = false
		_check_overlap()
	)

func _activate_star_power():
	star_power = true
	_star_timer = STAR_DURATION
	_star_palette_timer = 0.0
	_star_palette_index = 0
	AudioSystem.play_music("invincible_bgm")

func _process_star_power(delta: float):
	if not star_power:
		return
	_star_timer -= delta
	if _star_timer <= 0.0:
		_deactivate_star_power()
		return
	var interval = STAR_WARNING_PALETTE_INTERVAL if _star_timer <= STAR_WARNING_TIME else STAR_PALETTE_INTERVAL
	_star_palette_timer += delta
	if _star_palette_timer >= interval:
		_star_palette_timer -= interval
		_star_palette_index = (_star_palette_index + 1) % STAR_PALETTES.size()
		sprite.material.set_shader_parameter("palette_id", STAR_PALETTES[_star_palette_index])

func _deactivate_star_power():
	star_power = false
	_star_timer = 0.0
	_update_tree()
	SignalBus.star_power_ended.emit()

func _check_overlap():
	for area in hitbox.get_overlapping_areas():
		var body = area.get_parent()
		if body.is_in_group("Enemies") and not body.stomped and not is_dead:
			if star_power:
				AudioSystem.play_sfx("kick")
				body.die_from_hit(velocity)
			elif body.shell and not body.pushed:
				body.push(self)
			else:
				take_hit()
			return

func play_transition():
	get_tree().paused = true
	_is_transitioning = true
	_blink_timer = 0.0
	sprite.visible = false
	transition_sprite.visible = true

	transition_sprite.play()

	if collected_item_ref:
		collected_item_ref.queue_free()
		collected_item_ref = null

func _on_transition_sprite_animation_finished() -> void:
	get_tree().paused = false
	_is_transitioning = false
	_blink_timer = 0.0
	modulate.a = 1.0
	var animation_name = sprite.animation

	_update_tree()

	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
	else:
		sprite.play("Idle")

	transition_sprite.visible = false


func _on_hitbox_area_entered(area: Area2D):
	var body = area.get_parent()
	if body.is_in_group("Enemies"):
		if body.stomped or is_dead:
			return

		if star_power:
			AudioSystem.play_sfx("kick")
			body.die_from_hit(velocity)
			return

		var stomp = is_falling and hitbox.global_position.y < area.global_position.y + STOMP_TOLERANCE

		if stomp:
			if body.has_method("stomp"):
				body.stomp(self)
				#spawn_points_animation(body, 100)
				velocity.y = fmod(velocity.y, STOMP_SPEED_CAP) - STOMP_SPEED
		elif body.shell and not body.pushed:
			body.push(self)
			
		elif not has_cooldown:
			take_hit()
	
	if body.is_in_group("powerups"):
		_collect_powerup(body)

func _collect_powerup(item: Node) -> void:
	if "is_1up" in item and item.is_1up:
		Game.lives += 1
		_spawn_score_popup(item, true)
		AudioSystem.play_sfx("one_up")
		item.queue_free()
		return

	var new_state: Player.State = state
	if item.name.begins_with("FireFlower"):
		new_state = State.FIRE
	elif item.name.begins_with("Star"):
		Game.up_score(1000)
		_spawn_score_popup(item, false, 1000)
		_activate_star_power()
		item.queue_free()
		return
	else:
		if state == State.SMALL:
			new_state = State.BIG

	collected_item_ref = item
	Game.up_score(1000)
	_spawn_score_popup(item, false, 1000)
	if new_state != state:
		AudioSystem.play_sfx("power_up")
		transform(new_state)
	else:
		item.queue_free()
		collected_item_ref = null

func _spawn_score_popup(item: Node, is_1up: bool, points: int = 0) -> void:
	var popup := POINTS_POPUP.instantiate()
	popup.position = Game.current_level.to_local(item.global_position) + Vector2(0, -16)
	if is_1up:
		popup.is_1up = true
	else:
		popup.points = points
	Game.current_level.add_child(popup)
