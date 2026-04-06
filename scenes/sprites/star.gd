extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

const MOVE_SPEED := 48.0
const BOUNCE_SPEED := -300.0
const EMERGE_DISTANCE := 16.0
const EMERGE_DURATION := 0.5
const PALETTE_CYCLE_INTERVAL := 0.05
const PALETTES := [27, 24, 44, 27]

var _emerging := true
var _direction := 1.0
var _palette_index := 0
var _palette_timer := 0.0

func _ready() -> void:
	add_to_group("powerups")

	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)

	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - EMERGE_DISTANCE, EMERGE_DURATION)
	tween.tween_callback(_start_moving)

func _start_moving() -> void:
	_emerging = false
	collision_shape.set_deferred("disabled", false)
	set_physics_process(true)
	velocity.y = BOUNCE_SPEED

func _physics_process(delta: float) -> void:
	velocity.y = min(Physics.MAX_FALL_SPEED, velocity.y + Physics.GRAVITY * delta)
	velocity.x = _direction * MOVE_SPEED

	move_and_slide()

	if is_on_floor():
		velocity.y = BOUNCE_SPEED

	if is_on_wall():
		_direction *= -1.0

func _process(delta: float) -> void:
	_palette_timer += delta
	if _palette_timer >= PALETTE_CYCLE_INTERVAL:
		_palette_timer -= PALETTE_CYCLE_INTERVAL
		_palette_index = (_palette_index + 1) % PALETTES.size()
		sprite.material.set_shader_parameter("palette_id", PALETTES[_palette_index])
