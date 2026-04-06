extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

const EMERGE_DISTANCE := 16.0
const EMERGE_DURATION := 0.5
const PALETTE_CYCLE_INTERVAL := 0.1
const PALETTES := [24, 27, 44, 24]

var _palette_index := 0
var _palette_timer := 0.0

func _ready() -> void:
	add_to_group("powerups")

	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - EMERGE_DISTANCE, EMERGE_DURATION)

func _process(delta: float) -> void:
	_palette_timer += delta
	if _palette_timer >= PALETTE_CYCLE_INTERVAL:
		_palette_timer -= PALETTE_CYCLE_INTERVAL
		_palette_index = (_palette_index + 1) % PALETTES.size()
		sprite.material.set_shader_parameter("palette_id", PALETTES[_palette_index])
