@tool
extends Control

const ATLAS_ORIGIN := Vector2i(160, 144)
const CHAR_SIZE := 8

@export var text: String = "":
	set(value):
		text = value.to_upper()
		_update_size()
		queue_redraw()

@export var scale_factor: int = 1:
	set(value):
		scale_factor = max(value, 1)
		_update_size()
		queue_redraw()

var _atlas: Texture2D

func _ready() -> void:
	_atlas = preload("res://assets/textures/chr-mapping.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_update_size()
	queue_redraw()

func _char_grid(c: String) -> Vector2i:
	if c >= "0" and c <= "9":
		return Vector2i(c.unicode_at(0) - 48, 0)
	if c >= "A" and c <= "J":
		return Vector2i(c.unicode_at(0) - 65, 1)
	if c >= "K" and c <= "T":
		return Vector2i(c.unicode_at(0) - 75, 2)
	if c >= "U" and c <= "Z":
		return Vector2i(c.unicode_at(0) - 85, 3)
	match c:
		"-": return Vector2i(0, 4)
		"*": return Vector2i(1, 4)
		"!": return Vector2i(2, 4)
		".": return Vector2i(3, 4)
	return Vector2i(-1, -1)

func _parse_text() -> Array:
	var glyphs := []
	var i := 0
	while i < text.length():
		var c := text[i]
		# &C -> copyright glyph
		if c == "&" and i + 1 < text.length() and text[i + 1] == "C":
			glyphs.append(Vector2i(4, 4))
			i += 2
			continue
		if c == " ":
			glyphs.append(Vector2i(-1, -1))
			i += 1
			continue
		glyphs.append(_char_grid(c))
		i += 1
	return glyphs

func _update_size() -> void:
	var glyphs := _parse_text()
	var s := CHAR_SIZE * scale_factor
	custom_minimum_size = Vector2(glyphs.size() * s, s)
	size = custom_minimum_size

func _draw() -> void:
	if not _atlas:
		return
	var s := CHAR_SIZE * scale_factor
	var glyphs := _parse_text()
	for idx in glyphs.size():
		var g: Vector2i = glyphs[idx]
		if g.x < 0:
			continue
		var src := Rect2(
			ATLAS_ORIGIN.x + g.x * CHAR_SIZE,
			ATLAS_ORIGIN.y + g.y * CHAR_SIZE,
			CHAR_SIZE, CHAR_SIZE
		)
		draw_texture_rect_region(_atlas, Rect2(idx * s, 0, s, s), src)
