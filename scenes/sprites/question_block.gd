extends ItemBlock

func _ready() -> void:
	super()
	if contents == "empty":
		contents = "coin"

func hit(player) -> void:
	if _used or _bopping:
		return

	if contents.begins_with("invisible"):
		_make_solid()

	_knock_enemies_above(player)
	_handle_contents(player)

	sprite.set_physics_process(false)
	_bop(true)
