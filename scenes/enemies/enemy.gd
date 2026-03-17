extends CharacterBody2D

class_name Enemy

@onready var MOVEMENT_SPEED = Physics.MOVE_SPEED
@onready var FALL_SPEED = Physics.MAX_FALL_SPEED

@onready var sprite: AnimatedSprite2D
@export var is_facing_left: bool = true
@onready var in_range: VisibleOnScreenNotifier2D = $VisibleOnScreenEnabler2D

@onready var points_animation = preload("res://scenes/sprites/points_popup.tscn")

const DESPAWN_TIME_SEC: float = 1.0

var stomped: bool = false
var shell: bool = false
var pushed: bool = false

var last_x_position: float = 0.00
var _frozen: bool = false
var _dying: bool = false

func _enter_tree() -> void:
	SignalBus.game_state_changed.connect(_on_game_state_changed)

func _exit_tree() -> void:
	if SignalBus.game_state_changed.is_connected(_on_game_state_changed):
		SignalBus.game_state_changed.disconnect(_on_game_state_changed)

func _on_game_state_changed(new_state) -> void:
	if new_state == Game.GameState.DEAD:
		_freeze()

func _freeze() -> void:
	_frozen = true
	if sprite:
		sprite.pause()

func kill():
	queue_free()

func _ready() -> void:
	set_collision_mask_value(2, false)
	sprite = get_node_or_null("AnimatedSprite2D")

func _physics_process(delta):
	if Game.state == Game.GameState.DEAD:
		return
	if not in_range.is_on_screen():
		return
	var collision = get_last_slide_collision()
	
	if pushed and last_x_position == position.x:
		MOVEMENT_SPEED = -MOVEMENT_SPEED
	
	if collision:
		var normal = collision.get_normal()
		if normal.x:
			is_facing_left = normal.x < 0

	if !stomped and !shell or pushed:
		velocity.x = -MOVEMENT_SPEED if is_facing_left else MOVEMENT_SPEED
	else:
		velocity.x = 0.0
	
	if pushed:
		last_x_position = position.x	

	velocity.y = min(Physics.MAX_FALL_SPEED, velocity.y + Physics.GRAVITY * delta)

	move_and_slide()
	
func _on_hitbox_area_entered(area: Area2D):
	var body = area.get_parent()

	if body is Player and body.has_cooldown:
		return
		
	if shell and body is Enemy:
		body.is_facing_left = not body.is_facing_left
			
	if pushed and body is Enemy:
		body.die_from_hit()

func die_procedure():
	stomped = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	var area := get_node_or_null("Area2D")
	if area:
		area.set_deferred("monitorable", false)
		area.set_deferred("monitoring", false)

func die_score_popup():
	var popup := points_animation.instantiate()
	popup.points = 100
	popup.position = Game.current_level.to_local(global_position) + Vector2(0, -16)
	Game.current_level.add_child(popup)

func hit_from_below(source_velocity := Vector2.ZERO):
	die_from_hit(source_velocity)

func die_from_hit(source_velocity := Vector2.ZERO):
	if _dying:
		return
	_dying = true
	die_procedure()
	Game.up_score(100)

	die_score_popup()
	if sprite != null:
		sprite.flip_v = true

	var h_offset: float = sign(source_velocity.x) * 32.0
	var start_pos := position
	var die_tween = get_tree().create_tween()
	die_tween.tween_property(self, "position", start_pos + Vector2(h_offset * 0.5, -32), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	die_tween.tween_property(self, "position", start_pos + Vector2(h_offset, 240), 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	die_tween.tween_callback(queue_free)
