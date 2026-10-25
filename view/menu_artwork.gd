extends Control
## Static local key art; scale to fill without distorting the illustration.

const ART: Texture2D = preload("res://assets/art/delta_village.png")
const BRASS: Color = Color("c6a66d")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var source_size: Vector2 = ART.get_size()
	var scale_factor: float = maxf(size.x / source_size.x, size.y / source_size.y)
	var visible_source: Vector2 = size / scale_factor
	draw_texture_rect_region(ART, Rect2(Vector2.ZERO, size), Rect2((source_size - visible_source) * 0.5, visible_source))
	# Quiet double frame and corner marks recall a printed village field journal.
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2.0), Color(BRASS, 0.45), false, 1.0)
	draw_rect(Rect2(Vector2.ONE * 9.0, size - Vector2.ONE * 18.0), Color(BRASS, 0.24), false, 1.0)
	for corner: Vector2 in [Vector2(9, 9), Vector2(size.x - 9, 9), Vector2(9, size.y - 9), size - Vector2(9, 9)]:
		var inward: Vector2 = Vector2(1 if corner.x < size.x * 0.5 else -1, 1 if corner.y < size.y * 0.5 else -1)
		draw_line(corner, corner + Vector2(inward.x * 22, 0), BRASS, 2.0, true)
		draw_line(corner, corner + Vector2(0, inward.y * 22), BRASS, 2.0, true)
