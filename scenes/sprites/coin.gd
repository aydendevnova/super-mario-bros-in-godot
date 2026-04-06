extends Area2D

const SCORE_COIN := preload("res://scenes/sprites/score_coin.tscn")

func _ready() -> void:
	add_to_group("coins")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		collect()

func collect(from_block := false) -> void:
	Game.add_coin()
	Game.up_score(200)
	
	if from_block:
		var coin := SCORE_COIN.instantiate()
		coin.position = Game.current_level.to_local(global_position)
		coin.popup_points = 200
		Game.current_level.add_child(coin)
	else:
		AudioSystem.play_sfx("coin")
	queue_free()
