class_name AssetLoader
## Runtime texture loader that checks user://generated/ before res://.
## Scenes reference res://assets/textures/ (placeholder magenta PNGs).
## After ROM extraction, real textures live in user://generated/textures/.

const RES_PREFIX := "res://assets/textures/"
const USER_PREFIX := "user://generated/textures/"

static var _cache := {}


static func load_texture(res_path: String) -> Texture2D:
	if _cache.has(res_path):
		return _cache[res_path]

	var user_path := res_path.replace(RES_PREFIX, USER_PREFIX)
	if FileAccess.file_exists(user_path):
		var img := Image.load_from_file(user_path)
		if img != null:
			var tex := ImageTexture.create_from_image(img)
			_cache[res_path] = tex
			return tex

	if ResourceLoader.exists(res_path):
		var tex: Texture2D = load(res_path)
		_cache[res_path] = tex
		return tex

	return null


static func swap_atlas_texture(atlas_tex: AtlasTexture) -> AtlasTexture:
	if atlas_tex == null or atlas_tex.atlas == null:
		return atlas_tex
	if not atlas_tex.atlas.resource_path.begins_with(RES_PREFIX):
		return atlas_tex
	var new_base := load_texture(atlas_tex.atlas.resource_path)
	if new_base == null:
		return atlas_tex
	var swapped := atlas_tex.duplicate() as AtlasTexture
	swapped.atlas = new_base
	return swapped


static func has_generated_assets() -> bool:
	return FileAccess.file_exists("user://generated/version.txt")


static func clear_cache() -> void:
	_cache.clear()
