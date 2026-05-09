extends Node2D

const POLE_TOP_Y := 8.0
const POLE_BOTTOM_Y := 136.0
const FLAG_BOTTOM_Y := 128.0
const SLIDE_SPEED := 120.0
const BOTTOM_PAUSE := 0.5

@onready var flag_sprite: Sprite2D = $FlagSprite
@onready var pole_area: Area2D = $PoleArea

const HIDE_DISTANCE := 96-12

var _triggered := false

func _on_pole_area_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not body is Player:
		return

	_triggered = true
	var player := body as Player
	Game.level_complete()
	player.start_flag_pole_sequence({
		"flag": self,
		"flag_sprite": flag_sprite,
		"hide_distance": HIDE_DISTANCE,
		"pole_top_y": POLE_TOP_Y,
		"pole_bottom_y": POLE_BOTTOM_Y,
		"flag_bottom_y": FLAG_BOTTOM_Y,
		"slide_speed": SLIDE_SPEED,
		"bottom_pause": BOTTOM_PAUSE
	})
