class_name RomAssetRipper
## GDScript port of the Python CHR ROM decoder.
## Reads an iNES ROM and decodes 2-bitplane tiles into palette-indexed images
## (R-channel encodes index 0-3 for shader-based palette swapping).

const INDEX_COLORS := {
	0: Color(0, 0, 0, 0),
	1: Color8(85, 0, 0, 255),
	2: Color8(170, 0, 0, 255),
	3: Color8(255, 0, 0, 255),
}

const FRAME_COLS := 2

var chr_rom: PackedByteArray


func load_rom(path: String) -> bool:
	var rom := FileAccess.get_file_as_bytes(path)
	if rom.size() < 16:
		return false
	if rom[0] != 0x4E or rom[1] != 0x45 or rom[2] != 0x53 or rom[3] != 0x1A:
		return false
	var prg_banks := rom[4]
	var chr_banks := rom[5]
	if chr_banks == 0:
		return false
	var prg_size := prg_banks * 16384
	var chr_start := 16 + prg_size
	var chr_size := chr_banks * 8192
	if rom.size() < chr_start + chr_size:
		return false
	chr_rom = rom.slice(chr_start, chr_start + chr_size)
	return true


func decode_tile(tile_idx: int, is_bg: bool) -> Array[Array]:
	var base := (0x1000 if is_bg else 0x0000) + tile_idx * 16
	var pixels: Array[Array] = []
	for row in range(8):
		var lo := chr_rom[base + row]
		var hi := chr_rom[base + row + 8]
		var row_px: Array[int] = []
		for bit in range(7, -1, -1):
			row_px.append(((lo >> bit) & 1) | (((hi >> bit) & 1) << 1))
		pixels.append(row_px)
	return pixels


func decode_tile_absolute(abs_idx: int) -> Array[Array]:
	var base := abs_idx * 16
	var pixels: Array[Array] = []
	for row in range(8):
		var lo := chr_rom[base + row]
		var hi := chr_rom[base + row + 8]
		var row_px: Array[int] = []
		for bit in range(7, -1, -1):
			row_px.append(((lo >> bit) & 1) | (((hi >> bit) & 1) << 1))
		pixels.append(row_px)
	return pixels


func draw_tile_indexed(image: Image, pixels: Array[Array], pos: Vector2i) -> void:
	for y in range(8):
		var row_px: Array = pixels[y]
		for x in range(8):
			image.set_pixelv(Vector2i(x, y) + pos, INDEX_COLORS[row_px[x]])


func render_frame(tile_slots: Array, cols: int = FRAME_COLS) -> Image:
	var rows_count := ceili(tile_slots.size() / float(cols))
	var img := Image.create(cols * 8, rows_count * 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for i in range(tile_slots.size()):
		var slot = tile_slots[i]
		if slot == null:
			continue

		var col := i % cols
		var row := i / cols
		var tile_idx: int = slot[0]
		var is_bg: bool = slot[1]
		var explicit_h = slot[2] if slot.size() > 2 else null
		var explicit_v: bool = slot[3] if slot.size() > 3 else false

		var h_flip: bool
		if explicit_h != null:
			h_flip = explicit_h
		else:
			h_flip = false
			if col == 1 and i >= 1:
				var left_slot = tile_slots[i - 1]
				if left_slot != null and left_slot[0] == slot[0] and left_slot[1] == slot[1]:
					h_flip = true

		var pixels := decode_tile(tile_idx, is_bg)
		if explicit_v:
			pixels.reverse()
		if h_flip:
			for r in range(pixels.size()):
				var arr: Array = pixels[r].duplicate()
				arr.reverse()
				pixels[r] = arr

		draw_tile_indexed(img, pixels, Vector2i(col * 8, row * 8))

	return img


func crop_transparent_rows(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var top := 0
	for r in range(h):
		var found := false
		for c in range(w):
			if img.get_pixel(c, r).a > 0:
				found = true
				break
		if found:
			top = r
			break

	var bottom := h
	for r in range(h - 1, -1, -1):
		var found := false
		for c in range(w):
			if img.get_pixel(c, r).a > 0:
				found = true
				break
		if found:
			bottom = r + 1
			break

	if bottom <= top:
		return img

	top = (top / 8) * 8
	bottom = ceili(bottom / 8.0) * 8
	return img.get_region(Rect2i(0, top, w, bottom - top))


func compose_bowser(head_img: Image, body_img: Image) -> Image:
	var canvas := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(body_img, Rect2i(Vector2i.ZERO, body_img.get_size()), Vector2i(0, 8))
	canvas.blit_rect(head_img, Rect2i(Vector2i.ZERO, head_img.get_size()), Vector2i(15, 0))
	return canvas


func build_chr_mapping(mapping_data: Array) -> Image:
	var width := 432
	var height := 232
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for entry in mapping_data:
		var col: int = entry["col"]
		var r: int = entry["row"]
		var tile_idx: int = entry["chr_tile"]
		var hflip: bool = entry["hflip"] != 0
		var vflip: bool = entry["vflip"] != 0

		var pixels := decode_tile_absolute(tile_idx)
		if vflip:
			pixels.reverse()
		if hflip:
			for ri in range(pixels.size()):
				var arr: Array = pixels[ri].duplicate()
				arr.reverse()
				pixels[ri] = arr

		draw_tile_indexed(img, pixels, Vector2i(col * 8, r * 8))

	return img
