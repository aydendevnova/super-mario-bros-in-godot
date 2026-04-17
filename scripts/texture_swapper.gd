extends Node
## Autoload that automatically swaps placeholder res:// textures with
## user://generated/ overrides via SceneTree.node_added. Every node that
## enters the tree is checked — no manual swap calls needed.

const RES_PREFIX := "res://assets/textures/"

## Maps imported .ctex filenames back to their res:// source paths so inline
## CompressedTexture2D sub-resources (which only carry a load_path) can be
## resolved for swapping.
const IMPORT_STEMS := {
	"chr-mapping.png": "res://assets/textures/chr-mapping.png",
	"spritesheet.png": "res://assets/textures/spritesheet.png",
}

var _active := false


func _ready() -> void:
	_active = AssetLoader.has_generated_assets()
	if _active:
		get_tree().node_added.connect(_on_node_added)


func activate() -> void:
	if _active:
		return
	AssetLoader.clear_cache()
	_active = true
	get_tree().node_added.connect(_on_node_added)


func _resolve_atlas_res_path(atlas: Texture2D) -> String:
	if atlas == null:
		return ""
	var path := atlas.resource_path
	if path.begins_with(RES_PREFIX):
		return path
	# Inline CompressedTexture2D sub-resources only have a load_path in the
	# import cache — match the filename stem to recover the original res:// path.
	for stem in IMPORT_STEMS:
		if path.contains(stem):
			return IMPORT_STEMS[stem]
	return ""


func _on_node_added(node: Node) -> void:
	if not _active:
		return
	if node is Sprite2D:
		_swap_sprite2d(node)
	elif node is AnimatedSprite2D:
		_swap_animated_sprite(node)
	elif node is TextureRect:
		_swap_texture_rect(node)
	elif node is TileMapLayer:
		_swap_tilemap_layer(node)


func _try_swap_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if tex is AtlasTexture:
		var atlas: AtlasTexture = tex
		var inner := atlas.atlas
		# Unwrap nested AtlasTextures (e.g. score_coin frames -> score_coin_atlas.tres -> chr-mapping.png)
		if inner is AtlasTexture:
			var swapped_inner := _try_swap_texture(inner)
			if swapped_inner == null:
				return null
			var swapped := atlas.duplicate() as AtlasTexture
			swapped.atlas = swapped_inner
			return swapped
		var res_path := _resolve_atlas_res_path(inner)
		if res_path.is_empty():
			return null
		var new_base := AssetLoader.load_texture(res_path)
		if new_base == null:
			return null
		var swapped := atlas.duplicate() as AtlasTexture
		swapped.atlas = new_base
		return swapped
	var path := tex.resource_path
	if path.begins_with(RES_PREFIX):
		return AssetLoader.load_texture(path)
	return null


func _swap_sprite2d(sprite: Sprite2D) -> void:
	var new_tex := _try_swap_texture(sprite.texture)
	if new_tex:
		sprite.texture = new_tex


func _swap_texture_rect(tex_rect: TextureRect) -> void:
	var new_tex := _try_swap_texture(tex_rect.texture)
	if new_tex:
		tex_rect.texture = new_tex


func _swap_animated_sprite(anim_sprite: AnimatedSprite2D) -> void:
	var frames := anim_sprite.sprite_frames
	if frames == null:
		return

	for anim_name in frames.get_animation_names():
		for i in range(frames.get_frame_count(anim_name)):
			var tex := frames.get_frame_texture(anim_name, i)
			var new_tex := _try_swap_texture(tex)
			if new_tex:
				frames.set_frame(anim_name, i, new_tex, frames.get_frame_duration(anim_name, i))


func _swap_tilemap_layer(layer: TileMapLayer) -> void:
	var tile_set := layer.tile_set
	if tile_set == null:
		return

	for src_idx in range(tile_set.get_source_count()):
		var source_id := tile_set.get_source_id(src_idx)
		var source := tile_set.get_source(source_id)
		if source is TileSetAtlasSource:
			var atlas_source: TileSetAtlasSource = source
			var res_path := _resolve_atlas_res_path(atlas_source.texture)
			if not res_path.is_empty():
				var new_tex := AssetLoader.load_texture(res_path)
				if new_tex:
					atlas_source.texture = new_tex
