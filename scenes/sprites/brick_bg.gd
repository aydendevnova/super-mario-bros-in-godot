extends ItemBlock

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _multi_coin_count := 10
var _original_texture: Texture2D
var _breaking := false
var _pieces: Array[Sprite2D] = []
var _piece_velocities: Array[Vector2] = []
var _flip_timer := 0.0

func _ready() -> void:
	super()
	_original_texture = sprite.texture
	$First.visible = false
	$Second.visible = false
	$Third.visible = false
	$Fourth.visible = false



func _process(delta: float) -> void:
	if not _breaking:
		return
	_flip_timer += delta
	if _flip_timer >= 0.067:
		_flip_timer -= 0.067
		for p in _pieces:
			p.flip_h = !p.flip_h
	for i in range(_pieces.size()):
		_piece_velocities[i].y += 1200.0 * delta
		_pieces[i].position += _piece_velocities[i] * delta

func hit(player) -> void:
	if _bopping or _used:
		return

	if contents.begins_with("invisible"):
		_make_solid()

	_knock_enemies_above(player)

	match contents:
		"empty":
			if player.state != Player.State.SMALL:
				_break()
			else:
				AudioSystem.play_sfx("bump")
				_bop(false)
		"multi_coin":
			_dispense_coin()
			_multi_coin_count -= 1
			_bop(_multi_coin_count <= 0)
		_:
			_handle_contents(player)
			_bop(true)

func _break() -> void:
	AudioSystem.play_sfx("brick_smash")
	sprite.visible = false
	collision_shape.set_deferred("disabled", true)
	_pieces = [$First, $Second, $Third, $Fourth]
	_piece_velocities = [
		Vector2(-90, -300),
		Vector2(90, -300),
		Vector2(-90, -180),
		Vector2(90, -180),
	]
	for p in _pieces:
		p.visible = true
	_breaking = true
	Game.up_score(50)
	get_tree().create_timer(1.0).timeout.connect(func(): queue_free())
