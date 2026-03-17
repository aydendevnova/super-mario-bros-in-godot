extends Node2D

@onready var sprite: AnimatedSprite2D = $Sprite2D

const ARC_HEIGHT := 48.0
const RISE_TIME := 0.2
const FALL_TIME := 0.15
const LINGER_TIME := 0.25
const POINTS_POPUP := preload("res://scenes/sprites/points_popup.tscn")

var popup_points := 0

func _ready() -> void:
	sprite.play("default")
	AudioSystem.play_sfx("coin")

	var end_y := position.y - 8
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - ARC_HEIGHT, RISE_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position:y", end_y, FALL_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_on_arc_finished)
	tween.tween_interval(LINGER_TIME)
	tween.tween_callback(queue_free)

func _on_arc_finished() -> void:
	sprite.visible = false
	if popup_points > 0:
		var popup := POINTS_POPUP.instantiate()
		popup.points = popup_points
		popup.position = Game.current_level.to_local(global_position)
		Game.current_level.add_child(popup)
