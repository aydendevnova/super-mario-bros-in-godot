extends Control
## Boot-time ROM resource generator.
## Shows a ROM prompt when generated textures are missing, then rips sprites
## to user:// and transitions to the main game scene.

const ASSETS_VERSION := 1
const VERSION_FILE := "user://generated/version.txt"
const GEN_TEXTURES := "user://generated/textures/"

@onready var _file_dialog: FileDialog = %FileDialog
@onready var _status_label: Label = %StatusLabel
@onready var _prompt_container: VBoxContainer = %PromptContainer
@onready var _progress_bar: ProgressBar = %ProgressBar


func _ready() -> void:
	if _assets_up_to_date():
		_proceed_to_game()
		return
	_show_rom_prompt()


func _assets_up_to_date() -> bool:
	if not FileAccess.file_exists(VERSION_FILE):
		return false
	var ver := FileAccess.get_file_as_string(VERSION_FILE).strip_edges()
	return ver == str(ASSETS_VERSION)


func _show_rom_prompt() -> void:
	_prompt_container.visible = true
	_progress_bar.visible = false
	_status_label.text = "Please provide a Super Mario Bros. NES ROM to generate textures."


func _on_skip_pressed() -> void:
	_proceed_to_game()


func _on_browse_pressed() -> void:
	_file_dialog.filters = PackedStringArray(["*.nes ; NES ROM Files"])
	_file_dialog.popup_centered(Vector2i(600, 400))


func _on_file_dialog_file_selected(path: String) -> void:
	_prompt_container.visible = false
	_progress_bar.visible = true
	_status_label.text = "Generating textures..."
	await get_tree().process_frame
	generate(path)


func generate(rom_path: String) -> void:
	var ripper := RomAssetRipper.new()
	if not ripper.load_rom(rom_path):
		_show_error("Invalid ROM file. Please provide a valid iNES (.nes) ROM.")
		return

	DirAccess.make_dir_recursive_absolute(GEN_TEXTURES + "enemies")
	DirAccess.make_dir_recursive_absolute(GEN_TEXTURES + "player")

	var chr_mapping_data = _load_json("res://data/asset_ripper/chr_mapping_tiles.json")
	var player_anims = _load_json("res://data/asset_ripper/player_animations.json")
	var actor_anims = _load_json("res://data/asset_ripper/actor_animations.json")
	var enemy_defs = _load_json("res://data/asset_ripper/enemy_defs.json")
	var spritesheet_rows = _load_json("res://data/asset_ripper/spritesheet_rows.json")
	var ripper_config = _load_json("res://data/asset_ripper/ripper_config.json")

	if chr_mapping_data == null or player_anims == null or actor_anims == null:
		_show_error("Missing data files in res://data/asset_ripper/")
		return

	var actor_autocrop: Array = ripper_config.get("actor_autocrop", [])
	var player_autocrop: Array = ripper_config.get("player_autocrop", [])
	var player_need_full: Array = ripper_config.get("player_need_full", [])

	_set_progress(0.0, "Building chr-mapping...")
	var chr_img := ripper.build_chr_mapping(chr_mapping_data)
	chr_img.save_png(GEN_TEXTURES + "chr-mapping.png")

	_set_progress(0.15, "Rendering actor frames...")
	var actor_frames := {}
	for anim_name in actor_anims:
		var anim_def: Dictionary = actor_anims[anim_name]
		var rendered: Array[Image] = []
		for tile_slots in anim_def["frames"]:
			var img := ripper.render_frame(tile_slots)
			if anim_name in actor_autocrop:
				img = ripper.crop_transparent_rows(img)
			rendered.append(img)
		actor_frames[anim_name] = rendered

	actor_frames["bowser"] = [
		ripper.compose_bowser(actor_frames["bowser_mouth_opened"][0], actor_frames["bowser_step_right"][0]),
		ripper.compose_bowser(actor_frames["bowser_mouth_opened"][0], actor_frames["bowser_step_left"][0]),
		ripper.compose_bowser(actor_frames["bowser_mouth_closed"][0], actor_frames["bowser_step_right"][0]),
		ripper.compose_bowser(actor_frames["bowser_mouth_closed"][0], actor_frames["bowser_step_left"][0]),
	]

	_set_progress(0.4, "Rendering player frames...")
	var player_frames := {}
	for anim_name in player_anims:
		var frames: Array = player_anims[anim_name]
		var rendered: Array[Image] = []
		var rendered_full: Array[Image] = []
		for tile_slots in frames:
			var img := ripper.render_frame(tile_slots)
			if anim_name in player_need_full:
				rendered_full.append(img.duplicate())
			if anim_name in player_autocrop:
				img = ripper.crop_transparent_rows(img)
			rendered.append(img)
		player_frames[anim_name] = rendered
		if rendered_full.size() > 0:
			player_frames[anim_name + "_full"] = rendered_full

	_set_progress(0.6, "Building spritesheet...")
	var all_frames := {}
	for key in player_frames:
		all_frames[key] = player_frames[key]
	for key in actor_frames:
		all_frames[key] = actor_frames[key]
	var sheet := _build_spritesheet(all_frames, spritesheet_rows)
	sheet.save_png(GEN_TEXTURES + "spritesheet.png")

	_set_progress(0.7, "Exporting enemy PNGs...")
	for def_entry in enemy_defs:
		var scene_name: String = def_entry["scene_name"]
		var animations: Dictionary = def_entry["animations"]
		for anim_name in animations:
			var frame_refs: Array = animations[anim_name]
			for i in range(frame_refs.size()):
				var ref: Array = frame_refs[i]
				var src_anim: String = ref[0]
				var src_frame: int = ref[1]
				var img: Image = actor_frames[src_anim][src_frame]
				img.save_png(GEN_TEXTURES + "enemies/%s_%s_%d.png" % [scene_name, anim_name, i])

	_set_progress(0.85, "Exporting player PNGs...")
	var sorted_player_keys := player_frames.keys()
	sorted_player_keys.sort()
	for anim_name in sorted_player_keys:
		var frames: Array = player_frames[anim_name]
		for i in range(frames.size()):
			var img: Image = frames[i]
			img.save_png(GEN_TEXTURES + "player/%s_%d.png" % [anim_name, i])

	_set_progress(0.95, "Writing version stamp...")
	var f := FileAccess.open(VERSION_FILE, FileAccess.WRITE)
	f.store_string(str(ASSETS_VERSION))
	f.close()

	_set_progress(1.0, "Done!")
	TextureSwapper.activate()
	await get_tree().create_timer(0.5).timeout
	_proceed_to_game()


func _build_spritesheet(all_frames: Dictionary, rows_def: Array) -> Image:
	var row_metrics := []
	for row in rows_def:
		var w := 0
		var h := 0
		for entry in row:
			var name: String = entry[0]
			var fi: int = entry[1]
			var img: Image = all_frames[name][fi]
			w += _align8(img.get_width())
			h = maxi(h, img.get_height())
		row_metrics.append({"w": _align8(w), "h": _align8(h)})

	var sheet_w := 0
	var sheet_h := 0
	for m in row_metrics:
		sheet_w = maxi(sheet_w, m["w"])
		sheet_h += m["h"]
	sheet_w = _align8(sheet_w)
	sheet_h = _align8(sheet_h)

	var sheet := Image.create(sheet_w, sheet_h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))

	var y := 0
	for ri in range(rows_def.size()):
		var row: Array = rows_def[ri]
		var rh: int = row_metrics[ri]["h"]
		var x := 0
		for entry in row:
			var name: String = entry[0]
			var fi: int = entry[1]
			var img: Image = all_frames[name][fi]
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()),
				Vector2i(x, y + rh - img.get_height()))
			x += _align8(img.get_width())
		y += rh

	return sheet


func _align8(val: int) -> int:
	return ceili(val / 8.0) * 8


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	return JSON.parse_string(text)


func _set_progress(value: float, msg: String) -> void:
	_progress_bar.value = value * 100.0
	_status_label.text = msg


func _show_error(msg: String) -> void:
	_prompt_container.visible = true
	_progress_bar.visible = false
	_status_label.text = "ERROR: " + msg
	push_error("RomResourceGenerator: " + msg)


func _proceed_to_game() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
