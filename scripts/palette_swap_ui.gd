# DO NOT EDIT - JUST COPY FROM PALETTE_SWAP FOR NODE2D
# TODO ? EXEND FROM NODE2D and CONTROL?
extends Control

enum SpriteType { FOREGROUND, BACKGROUND, GOLD, SCENERY, SCENERY_SNOW, SCENERY_MUSHROOM, ATMOSPHERIC, ENEMIES, ENEMY_GREEN, ENEMY_RED, ENEMY_DARK, PRINCESS, TOAD }
@export var sprite_type: SpriteType = SpriteType.FOREGROUND

const PALETTE_TABLE := {
	SpriteType.FOREGROUND:       [0, 1, 2, 3],
	SpriteType.BACKGROUND:       [4, 5, 6, 7],
	SpriteType.GOLD:             [8, 9, 10, 11],
	SpriteType.SCENERY:          [12, 13, 6, 14],
	SpriteType.SCENERY_SNOW:     [17, 17, 17, 17],
	SpriteType.SCENERY_MUSHROOM: [16, 16, 16, 16],
	SpriteType.ATMOSPHERIC:      [17, 18, 20, 19],
	SpriteType.ENEMIES:          [27, 27, 27, 27],
	SpriteType.ENEMY_GREEN:      [24, 25, 39, 26],
	SpriteType.ENEMY_RED:        [27, 27, 27, 27],
	SpriteType.ENEMY_DARK:       [36, 36, 36, 36],
	SpriteType.PRINCESS:         [37, 37, 37, 37],
	SpriteType.TOAD:             [38, 38, 38, 38],
}

# The NES cycles this every 8 frames (8 * 0.0166s ≈ 0.133s)
const GOLD_STEP_DURATION := (1.0 / 60.0) * 8 

# Pattern logic (6 steps total):
# Steps 0, 1, 2: Bright Gold ($27) - Total 24 frames
# Step 3: Medium Gold ($17)       - Total 8 frames
# Step 4: Dark Brown ($07)        - Total 8 frames
# Step 5: Medium Gold ($17)       - Total 8 frames
const GOLD_CYCLE := {
	0: [8, 8, 8, 28, 32, 28],    # Overworld
	1: [9, 9, 9, 29, 33, 29],    # Underground
	2: [10, 10, 10, 30, 34, 30], # Castle
	3: [11, 11, 11, 31, 35, 31], # Underwater
}

var _gold_timer := 0.0
var _gold_step := 0

func _ready() -> void:
	material = material.duplicate()
	SignalBus.game_palette_updated.connect(_apply_palette)
	_apply_palette()
	if sprite_type == SpriteType.GOLD:
		process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if Game.state == Game.GameState.TRANSITION or Game.is_paused:
		if _gold_step != 0:
			_gold_step = 0
			_apply_palette()
		return

	var time_now = Time.get_ticks_msec() / 1000.0
	var step_duration = 8.0 / 60.0
	var total_steps = 6
	var new_step = int(time_now / step_duration) % total_steps

	if new_step != _gold_step:
		_gold_step = new_step
		_apply_palette()

func _apply_palette() -> void:
	var palette_id: int
	if sprite_type == SpriteType.GOLD:
		palette_id = GOLD_CYCLE[Game.lvl_palette][_gold_step]
	else:
		palette_id = PALETTE_TABLE[sprite_type][Game.lvl_palette]
	
	material.set_shader_parameter("palette_id", palette_id)
