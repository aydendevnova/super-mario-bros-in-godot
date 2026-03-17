extends CharacterBody2D

const SPEED := 200.0
const BOUNCE_SPEED := -180.0
const MAX_FALL_SPEED := 300.0
const LIFETIME := 3.0
const SPIN_INTERVAL := 0.06

var direction := 1.0
var _timer := 0.0
var _spin_timer := 0.0
var _spin_frame := 0

@onready var sprite_a: Sprite2D = $Sprite2D
@onready var sprite_b: Sprite2D = $Sprite2D2
@onready var hitbox: Area2D = $Hitbox
@onready var explosion_sprite: AnimatedSprite2D = $ExplosionSprite

var _exploding := false

func _ready() -> void:
	velocity.y = BOUNCE_SPEED
	hitbox.area_entered.connect(_on_area_entered)
	_apply_spin_frame()

func _physics_process(delta: float) -> void:
	if _exploding:
		return
	velocity.x = direction * SPEED
	velocity.y = min(MAX_FALL_SPEED, velocity.y + Physics.GRAVITY * delta)

	move_and_slide()

	if is_on_floor():
		velocity.y = BOUNCE_SPEED

	if is_on_wall():
		AudioSystem.play_sfx("bump")
		_explode()
		return

	_spin_timer += delta
	if _spin_timer >= SPIN_INTERVAL:
		_spin_timer -= SPIN_INTERVAL
		_spin_frame = (_spin_frame + 1) % 4
		_apply_spin_frame()

	_timer += delta
	if _timer >= LIFETIME:
		queue_free()

func _apply_spin_frame() -> void:
	var use_b := _spin_frame % 2 == 1
	var flipped := _spin_frame >= 2
	sprite_a.visible = not use_b
	sprite_b.visible = use_b
	var s := sprite_b if use_b else sprite_a
	s.flip_h = flipped
	s.flip_v = flipped

func _on_area_entered(area: Area2D) -> void:
	var body = area.get_parent()
	if body is Enemy and not body.stomped:
		AudioSystem.play_sfx("kick")
		body.die_from_hit(velocity)
		_explode()

func _explode() -> void:
	_exploding = true
	velocity = Vector2.ZERO
	sprite_a.visible = false
	sprite_b.visible = false
	hitbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	$CollisionShape2D.set_deferred("disabled", true)
	explosion_sprite.visible = true
	explosion_sprite.play()
	explosion_sprite.animation_finished.connect(queue_free)
