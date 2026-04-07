extends AnimatableBody2D

enum MovementType {
	HORIZONTAL,   # 0: back-and-forth oscillation
	VERTICAL,     # 1: up-and-down oscillation
	UP,           # 2: continuous upward lift, wraps
	DOWN,         # 3: continuous downward lift, wraps
	DROP,         # 4: falls when player stands on it
	BALANCE,      # 5: pulley-linked pair
	RIGHT,        # 6: continuous rightward movement
}

@export var movement_type: MovementType = MovementType.HORIZONTAL

var _origin := Vector2.ZERO
var _time := 0.0
var _drop_active := false
var _drop_speed := 0.0
var _rider_count := 0
var _partner: AnimatableBody2D = null
var _bal_velocity := 0.0
var _bal_offset := 0.0
var _wrap_frames := 0

# Horizontal floater: NES speed counter 0-14, steps every 4 frames.
# Full cycle = 224 frames / 60fps ≈ 3.73s. Travel per half ≈ 49px.
const H_HALF_RANGE := 24.0
const H_PERIOD := 3.73

# Vertical oscillation: PLAT_V_INC = 64 pixel range,
# gravity accel 5/256 px/frame², decel 10/256.
const V_HALF_RANGE := 32.0
const V_PERIOD := 2.7

# Lift: veloc_y=±1, accel_y_grav=±16 → effective 15/16 px/frame
const LIFT_SPEED := 56.25
const LIFT_WRAP_RANGE := 160.0

# Drop: motion_fall_fast accel_y_inc=127, max_vel=2 px/frame
const DROP_ACCEL := 1800.0
const DROP_MAX_SPEED := 120.0

# Right: PLAT_RIGHT_VELOC_X = 16 → 4.4 fixed = 1 px/frame
const RIGHT_SPEED := 60.0

# Balance: motion_platform accel 5/256 px/frame², max_vel 3 px/frame
const BAL_ACCEL := 70.0
const BAL_MAX_SPEED := 180.0
const BAL_FALL_THRESHOLD := 45.0

@onready var _col_shape: CollisionShape2D = $CollisionShape2D


func _ready():
	_origin = position
	if Engine.is_editor_hint():
		return
	if movement_type == MovementType.DROP or movement_type == MovementType.BALANCE:
		_create_rider_sensor()
	if movement_type == MovementType.BALANCE:
		call_deferred("_find_partner")


func _physics_process(delta: float):
	if Engine.is_editor_hint():
		return
	if Game.state == Game.GameState.DEAD:
		return

	if _wrap_frames > 0:
		_wrap_frames -= 1
		if _wrap_frames == 0:
			_col_shape.disabled = false

	match movement_type:
		MovementType.HORIZONTAL:
			_time += delta
			position.x = _origin.x + sin(_time * TAU / H_PERIOD) * H_HALF_RANGE
		MovementType.VERTICAL:
			_time += delta
			position.y = _origin.y + sin(_time * TAU / V_PERIOD) * V_HALF_RANGE
		MovementType.UP:
			_move_lift(delta, -1.0)
		MovementType.DOWN:
			_move_lift(delta, 1.0)
		MovementType.DROP:
			_process_drop(delta)
		MovementType.BALANCE:
			_process_balance(delta)
		MovementType.RIGHT:
			position.x += RIGHT_SPEED * delta
			if position.x > _origin.x + 512.0:
				queue_free()


func _move_lift(delta: float, direction: float):
	position.y += direction * LIFT_SPEED * delta
	if _wrap_frames > 0:
		return
	if direction < 0.0 and position.y < _origin.y - LIFT_WRAP_RANGE:
		position.y += LIFT_WRAP_RANGE * 2.0
		_col_shape.disabled = true
		_wrap_frames = 2
	elif direction > 0.0 and position.y > _origin.y + LIFT_WRAP_RANGE:
		position.y -= LIFT_WRAP_RANGE * 2.0
		_col_shape.disabled = true
		_wrap_frames = 2


func _process_drop(delta: float):
	if not _drop_active:
		return
	_drop_speed = min(_drop_speed + DROP_ACCEL * delta, DROP_MAX_SPEED)
	position.y += _drop_speed * delta
	if position.y > _origin.y + 240.0:
		queue_free()


func _process_balance(delta: float):
	if not _partner or not is_instance_valid(_partner):
		return
	if get_instance_id() > _partner.get_instance_id():
		return

	var weight := 0.0
	if _rider_count > 0 and _partner._rider_count == 0:
		weight = 1.0
	elif _partner._rider_count > 0 and _rider_count == 0:
		weight = -1.0

	if weight != 0.0:
		_bal_velocity = clamp(
			_bal_velocity + weight * BAL_ACCEL * delta,
			-BAL_MAX_SPEED, BAL_MAX_SPEED
		)
	else:
		_bal_velocity = move_toward(_bal_velocity, 0.0, BAL_ACCEL * 0.5 * delta)

	_bal_offset += _bal_velocity * delta
	position.y = _origin.y + _bal_offset
	_partner.position.y = _partner._origin.y - _bal_offset

	if abs(_bal_offset) >= BAL_FALL_THRESHOLD:
		_trigger_fall()
		_partner._trigger_fall()


func _trigger_fall():
	movement_type = MovementType.DROP
	_drop_active = true
	_drop_speed = LIFT_SPEED


func _create_rider_sensor():
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 2
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 16)
	shape_node.shape = rect
	shape_node.position = Vector2(24, -6)
	sensor.add_child(shape_node)
	add_child(sensor)
	sensor.body_entered.connect(_on_rider_entered)
	sensor.body_exited.connect(_on_rider_exited)


func _on_rider_entered(body: Node2D):
	if body is CharacterBody2D:
		_rider_count += 1
		if movement_type == MovementType.DROP:
			_drop_active = true


func _on_rider_exited(body: Node2D):
	if body is CharacterBody2D:
		_rider_count = max(0, _rider_count - 1)


func _find_partner():
	var parent := get_parent()
	if not parent:
		return
	var best: AnimatableBody2D = null
	var best_dist := INF
	for child in parent.get_children():
		if child == self or not (child is AnimatableBody2D):
			continue
		if not ("movement_type" in child):
			continue
		if child.movement_type != MovementType.BALANCE:
			continue
		var d := position.distance_to(child.position)
		if d < best_dist:
			best_dist = d
			best = child
	_partner = best
