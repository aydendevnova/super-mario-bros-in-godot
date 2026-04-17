class_name ItemBlock
extends StaticBody2D

@export var contents: String = "empty"

@onready var sprite: Sprite2D = $Sprite2D

const _EMPTY_FG_BASE := preload("res://assets/block_empty_fg.tres")
const _EMPTY_BG_BASE := preload("res://assets/block_empty_bg.tres")
const POINTS_POPUP := preload("res://scenes/sprites/points_popup.tscn")
const SCORE_COIN := preload("res://scenes/sprites/score_coin.tscn")
const MUSHROOM := preload("res://scenes/sprites/mushroom.tscn")
const FIRE_FLOWER := preload("res://scenes/sprites/fire_flower.tscn")
const STAR := preload("res://scenes/sprites/star.tscn")

const INVISIBLE_LAYER := 6

var EMPTY_FG: AtlasTexture
var EMPTY_BG: AtlasTexture
var _used := false
var _bopping := false

func _ready() -> void:
	EMPTY_FG = AssetLoader.swap_atlas_texture(_EMPTY_FG_BASE)
	EMPTY_BG = AssetLoader.swap_atlas_texture(_EMPTY_BG_BASE)
	if contents.begins_with("invisible"):
		sprite.visible = false
		set_collision_layer_value(1, false)
		set_collision_layer_value(INVISIBLE_LAYER, true)

func _make_solid() -> void:
	sprite.visible = true
	set_collision_layer_value(INVISIBLE_LAYER, false)
	set_collision_layer_value(1, true)

func _handle_contents(player) -> bool:

	match contents:
		"coin", "invisible_coin":
			_dispense_coin()
			return true
		"one_up", "invisible_one_up":
			_spawn_item(MUSHROOM, true)
			return true
		"powerup":
			if player.state == Player.State.SMALL:
				_spawn_item(MUSHROOM, false)
			else:
				_spawn_item(FIRE_FLOWER, false)
			return true
		"star":
			_spawn_item(STAR, false)
			return true
	return false

func _bop(become_empty: bool) -> void:
	_bopping = true
	var is_gold: bool = sprite.sprite_type == sprite.SpriteType.GOLD

	if become_empty:
		sprite.sprite_type = sprite.SpriteType.GOLD
		if is_gold:
			sprite.texture = EMPTY_BG
		else:
			sprite.texture = EMPTY_BG
		sprite._apply_palette()

	var tween := create_tween()
	tween.tween_property(sprite, "position", Vector2(0, -6), 0.08)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.08)
	tween.tween_callback(func():
		_bopping = false
		if become_empty:
			_used = true
			sprite.texture = EMPTY_BG
			if not is_gold:
				sprite.sprite_type = sprite.SpriteType.BACKGROUND
				sprite._apply_palette()
			else:
				sprite.sprite_type = sprite.SpriteType.GOLD
				sprite._apply_palette()
	)

func _knock_enemies_above(player) -> void:
	for enemy in get_tree().get_nodes_in_group("Enemies"):
		var ex: float = enemy.global_position.x
		var ey: float = enemy.global_position.y
		if ex > global_position.x - 8 and ex < global_position.x + 16 \
				and ey < global_position.y and ey > global_position.y - 32:
			enemy.hit_from_below(player.velocity)

	for node in get_tree().get_nodes_in_group("coins"):
		var cx: float = node.global_position.x
		var cy: float = node.global_position.y
		if cx > global_position.x - 8 and cx < global_position.x + 16 \
				and cy < global_position.y and cy > global_position.y - 20:
			node.collect(true)

func _spawn_item(scene: PackedScene, is_1up: bool) -> void:
	for n in range(8):
		await get_tree().physics_frame
	AudioSystem.play_sfx("powerup_appears")
	var item := scene.instantiate()
	item.position = Game.current_level.to_local(global_position)
	if "is_1up" in item:
		item.is_1up = is_1up
	Game.current_level.add_child(item)

func _dispense_coin() -> void:
	Game.add_coin()
	Game.up_score(200)
	var coin := SCORE_COIN.instantiate()
	coin.position = Game.current_level.to_local(global_position)
	coin.popup_points = 200
	Game.current_level.add_child(coin)
