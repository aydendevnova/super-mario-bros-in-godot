extends CharacterBody2D

@export var is_1up := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

const MOVE_SPEED := 60.0
const EMERGE_DISTANCE := 16.0
const EMERGE_DURATION := 0.5

var _emerging := true
var _direction := 1.0

func _ready() -> void:
	add_to_group("powerups")
	if is_1up:
		sprite.material.set_shader_parameter("palette_id", 24)
	else:
		sprite.material.set_shader_parameter("palette_id", 27)

	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)

	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - EMERGE_DISTANCE, EMERGE_DURATION)
	tween.tween_callback(_start_moving)

func _start_moving() -> void:
	_emerging = false
	collision_shape.set_deferred("disabled", false)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	velocity.y = min(Physics.MAX_FALL_SPEED, velocity.y + Physics.GRAVITY * delta)
	velocity.x = _direction * MOVE_SPEED

	move_and_slide()

	if is_on_wall():
		_direction *= -1.0
