extends SubViewportContainer

## Dynamic widescreen viewport: fixed height, width adjusts to aspect ratio.
## The game world extends horizontally rather than stretching pixels.
##
## SETUP:
##   1. Attach this to your SubViewportContainer (Stretch OFF)
##   2. SubViewport as child, with your game inside it
##   3. Inside the SubViewport, add a CanvasLayer (layer = 100)
##   4. Inside that CanvasLayer, add a ColorRect with nes_composite.gdshader
##   5. The shader runs at SubViewport resolution, NOT display resolution
##
## TREE:
##   SubViewportContainer  (this script, Stretch OFF, NO material)
##     SubViewport
##       Level (your game)
##       CompositeLayer (CanvasLayer, layer = 100)
##         CompositeRect (ColorRect, shader material)

@export var base_height: int = 900
@export var min_width: int = 900
@export var max_width: int = 0  ## 0 = no limit

var _viewport: SubViewport
var _composite_rect: ColorRect

func _ready() -> void:
	for child in get_children():
		if child is SubViewport:
			_viewport = child
			break

	if not _viewport:
		push_error("WideScreenViewport: No SubViewport child found.")
		return

	# Find the composite ColorRect so we can resize it with the viewport
	_find_composite_rect(_viewport)

	_on_resize()
	get_viewport().size_changed.connect(_on_resize)

func _find_composite_rect(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			for grandchild in child.get_children():
				if grandchild is ColorRect:
					_composite_rect = grandchild
					return
		_find_composite_rect(child)

func _on_resize() -> void:
	if not _viewport:
		return

	var window_size := get_viewport().get_visible_rect().size
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return

	var scale_factor := window_size.y / float(base_height)
	var source_width := int(ceil(window_size.x / scale_factor))

	source_width = max(source_width, min_width)
	if max_width > 0:
		source_width = min(source_width, max_width)

	_viewport.size = Vector2i(source_width, base_height)

	# Resize the composite ColorRect to cover the full viewport
	if _composite_rect:
		_composite_rect.size = Vector2(source_width, base_height)

	self.scale = Vector2(scale_factor, scale_factor)
	self.size = Vector2(source_width, base_height)

	var actual_width := float(source_width) * scale_factor
	self.position.x = floor((window_size.x - actual_width) * 0.5)
	self.position.y = 0.0
