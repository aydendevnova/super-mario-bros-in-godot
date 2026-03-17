extends Node

enum WorldTheme { OVERWORLD, UNDERGROUND, CASTLE, UNDERWATER }
enum SceneryType { DEFAULT, SNOW, MUSHROOM }


# sprite_type → palette_id per WorldTheme index [overworld, underground, castle, underwater]
const PALETTE_TABLE := {
	1: [4, 5, 6, 7],       # BACKGROUND
	3: [12, 13, 6, 14],   # SCENERY
	6: [17, 18, 20, 19],   # ATMOSPHERIC
	7: [27, 27, 27, 27],   # ENEMIES
}

const SCENERY_OVERRIDE := {
	SceneryType.SNOW: 17,
	SceneryType.MUSHROOM: 16,
}

# NES background color per world theme ($22 = sky blue, $0F = black)
const CLEAR_COLOR := {
	WorldTheme.OVERWORLD:    Color("#9494ff"),
	WorldTheme.UNDERGROUND:  Color(0.0, 0.0, 0.0),
	WorldTheme.CASTLE:       Color(0.0, 0.0, 0.0),
	WorldTheme.UNDERWATER:   Color("#9494ff"),
}

func _ready() -> void:
	SignalBus.game_palette_updated.connect(_apply_clear_color)
	_apply_clear_color()

func _apply_clear_color() -> void:
	RenderingServer.set_default_clear_color(CLEAR_COLOR[Game.lvl_palette])
