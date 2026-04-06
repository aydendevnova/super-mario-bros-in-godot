extends Enemy

const SHELL_SPEED := 200.0
const WARNING_TIME := 4.0
const RECOVER_DELAY := 1.5

const STOMPED_POS := Vector2(0, 10)
const FLIPPED_POS := Vector2(0, 8)

@onready var walk_collision: CollisionShape2D = $CollisionShape2D
@onready var shell_collision: CollisionShape2D = $CollisionShape2D2
@onready var walk_sprite: AnimatedSprite2D = $KoopaNormal
@onready var shell_sprite: AnimatedSprite2D = $KoopaStomp
@onready var hitbox: Area2D = $Area2D

var _flipped := false
var _launched := false
var _shell_gen := 0

func _ready():
	sprite = walk_sprite
	collision_layer = 4
	walk_collision.disabled = false
	shell_collision.disabled = true
	walk_sprite.show()
	shell_sprite.hide()
	hitbox.body_entered.connect(_on_shell_body_entered)

func _physics_process(delta):
	if _launched:
		velocity.y = min(Physics.MAX_FALL_SPEED, velocity.y + Physics.GRAVITY * delta)
		move_and_slide()
		if is_on_floor():
			_launched = false
			velocity.x = 0.0
		return
	super._physics_process(delta)
	if velocity.x:
		walk_sprite.flip_h = velocity.x < 0
	if pushed:
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			var body = col.get_collider()
			if body is Enemy and body != self:
				body.die_from_hit(velocity)

func _set_shell_stomped():
	shell_sprite.position = STOMPED_POS
	shell_sprite.flip_v = true
	shell_sprite.frame = 0
	shell_sprite.speed_scale = 0.0
	shell_sprite.show()

func _set_shell_flipped():
	shell_sprite.position = FLIPPED_POS
	shell_sprite.flip_v = false
	shell_sprite.frame = 0
	shell_sprite.speed_scale = 0.0
	shell_sprite.show()

func stomp(player: Player):
	
	if not shell:
		AudioSystem.play_sfx("stomp")
		_enter_shell()
		Game.up_score(100)
		_spawn_points(100)
	elif pushed:
		AudioSystem.play_sfx("kick")
		_stop_shell()
	else:
		AudioSystem.play_sfx("kick")
		push(player)

func _enter_shell():
	shell = true
	_flipped = false
	walk_sprite.hide()
	_set_shell_stomped()
	walk_collision.set_deferred("disabled", true)
	shell_collision.set_deferred("disabled", false)
	_begin_recovery_cycle()

func hit_from_below(source_velocity := Vector2.ZERO):
	if _dying or shell:
		return
	_flipped = true
	shell = true
	walk_sprite.hide()
	_set_shell_flipped()
	walk_collision.set_deferred("disabled", true)
	shell_collision.set_deferred("disabled", false)
	_launched = true
	velocity = Vector2(sign(source_velocity.x) * 50.0, -300.0)
	Game.up_score(100)
	_spawn_points(100)
	_begin_recovery_cycle()

func die_from_hit(source_velocity := Vector2.ZERO):
	if _dying:
		return
	_flipped = true
	walk_sprite.hide()
	_set_shell_flipped()
	walk_collision.set_deferred("disabled", true)
	shell_collision.set_deferred("disabled", false)
	sprite = shell_sprite
	super.die_from_hit(source_velocity)
	shell_sprite.flip_v = false

func _on_flip_landed():
	set_physics_process(true)
	_dying = false
	_begin_recovery_cycle()

func _begin_recovery_cycle():
	_shell_gen += 1
	var gen := _shell_gen
	get_tree().create_timer(WARNING_TIME).timeout.connect(func():
		if _shell_gen == gen:
			_warn_recovery(gen)
	)

func _warn_recovery(gen: int):
	if not shell or pushed:
		return
	shell_sprite.speed_scale = 1.0
	get_tree().create_timer(RECOVER_DELAY).timeout.connect(func():
		if _shell_gen == gen:
			_recover()
	)

func _recover():
	if not is_inside_tree():
		return
	_shell_gen += 1
	_flipped = false
	shell = false
	pushed = false
	MOVEMENT_SPEED = Physics.MOVE_SPEED
	shell_sprite.frame = 0
	shell_sprite.speed_scale = 0.0
	shell_sprite.hide()
	shell_sprite.position = STOMPED_POS
	shell_sprite.flip_v = true
	walk_sprite.show()
	shell_collision.set_deferred("disabled", true)
	walk_collision.set_deferred("disabled", false)
	set_collision_mask_value(3, true)

func push(player: Player = null):
	AudioSystem.play_sfx("kick")
	_shell_gen += 1
	_flipped = false
	pushed = true
	MOVEMENT_SPEED = SHELL_SPEED
	if player:
		is_facing_left = player.global_position.x > global_position.x
	_set_shell_stomped()
	hitbox.set_collision_mask_value(3, true)
	set_collision_mask_value(3, false)
	Game.up_score(400)
	_spawn_points(400)

func _stop_shell():
	pushed = false
	MOVEMENT_SPEED = 0.0
	hitbox.set_collision_mask_value(3, false)
	set_collision_mask_value(3, true)
	_begin_recovery_cycle()

func _on_shell_body_entered(body: Node2D):
	if not pushed:
		return
	if body is Enemy and body != self:
		body.die_from_hit(velocity)

func _spawn_points(pts: int):
	var popup := points_animation.instantiate()
	popup.points = pts
	popup.position = Game.current_level.to_local(global_position) + Vector2(0, -16)
	Game.current_level.add_child(popup)
