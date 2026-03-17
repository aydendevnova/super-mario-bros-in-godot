extends ItemBlock

func _ready() -> void:
	if contents == "empty":
		contents = "coin"

func hit(player) -> void:
	if _used or _bopping:
		return

	_knock_enemies_above(player)
	_handle_contents(player)

	sprite.set_physics_process(false)
	_bop(true)
