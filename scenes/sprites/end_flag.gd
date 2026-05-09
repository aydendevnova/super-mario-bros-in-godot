extends Node2D

@onready var _sprite: Sprite2D = $Sprite2D

const DROP_OFFSET := 24.0
const RISE_SPEED := 120.0
const RISE_DELAY_FRAMES := 8

func _ready() -> void:
	_sprite.position.y += DROP_OFFSET
	SignalBus.time_updated.connect(_on_time_updated)

func _on_time_updated(time: int) -> void:
	if time <= 0 and Game.level_finished:
		SignalBus.time_updated.disconnect(_on_time_updated)
		_raise_flag()

func _raise_flag() -> void:
	var delay := RISE_DELAY_FRAMES / 60.0
	var duration := DROP_OFFSET / RISE_SPEED
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(_sprite, "position:y", _sprite.position.y - DROP_OFFSET, duration)
