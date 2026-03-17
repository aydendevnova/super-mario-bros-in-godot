extends Node2D

@onready var sprite: Sprite2D = $Sprite

const FOREGROUND_PALETTES := [0, 1, 2, 3]

const SCORE_REGIONS := {
	100:  Rect2(384, 80, 12, 8),
	200:  Rect2(384, 88, 12, 8),
	400:  Rect2(384, 96, 12, 8),
	500:  Rect2(384, 104, 12, 8),
	800:  Rect2(384, 112, 12, 8),
	1000: Rect2(396, 80, 24, 8),
	2000: Rect2(396, 88, 24, 8),
	4000: Rect2(396, 96, 24, 8),
	5000: Rect2(396, 104, 24, 8),
	8000: Rect2(396, 112, 24, 8),
}

const ONE_UP_REGION := Rect2(396, 120, 24, 8)

const FLOAT_DISTANCE := 24.0
const FLOAT_DURATION := 0.6

var points: int = 100:
	set(value):
		points = value
		if is_node_ready():
			_update_region()

var is_1up: bool = false:
	set(value):
		is_1up = value
		if is_node_ready():
			_update_region()

var _camera_start_x: float
var _spawn_x: float

func _ready() -> void:
	sprite.texture = (sprite.texture as AtlasTexture).duplicate()
	sprite.material = (sprite.material as ShaderMaterial).duplicate()
	(sprite.material as ShaderMaterial).set_shader_parameter("palette_id", 24)

	_spawn_x = global_position.x
	var cam := get_viewport().get_camera_2d()
	_camera_start_x = cam.global_position.x if cam else _spawn_x

	_update_region()

	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, FLOAT_DURATION)
	tween.tween_callback(queue_free)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		global_position.x = _spawn_x + (cam.global_position.x - _camera_start_x)

func _update_region() -> void:
	var atlas_tex := sprite.texture as AtlasTexture
	if is_1up:
		atlas_tex.region = ONE_UP_REGION
	elif SCORE_REGIONS.has(points):
		atlas_tex.region = SCORE_REGIONS[points]
