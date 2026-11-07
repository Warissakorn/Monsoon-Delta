class_name TransportBoard
extends YearBoard
## Read-only route corridors and actual cargo locations over the year map.

var transport_model: Dictionary = {}
var route_mode: String = "land"
var route_resource: String = "wood"


func _draw() -> void:
	super._draw()
	if model.is_empty() or transport_model.is_empty():
		return
	var t: Dictionary = transport_model["transport"]
	for mode: String in ["land", "boat"]:
		var points: PackedVector2Array = []
		for index: int in t["land" if mode == "land" else "water"]:
			points.append(center_of(index))
		if points.size() > 1:
			draw_polyline(points, Color("b59b70") if mode == "land" else Color("7ab8c3"), 2.0, true)
	var origin: String = "source" if route_resource == "wood" else "mill"
	var target: String = "mill" if route_resource == "wood" else "store"
	var route: Array[int] = TransportGame.route(transport_model, int(t["sites"][origin]), int(t["sites"][target]), route_mode)
	var points: PackedVector2Array = []
	for index: int in route:
		points.append(center_of(index))
	if points.size() > 1:
		draw_polyline(points, Color("f1d28b"), 4.0, true)
	var font: Font = get_theme_default_font()
	for role: String in TransportGame.ROLES:
		var at: Vector2 = center_of(int(t["sites"][role]))
		var color: Color = Color("f1d28b") if t["ports"][role] else Color("dc9681")
		draw_arc(at, _radius * 0.85, 0.0, TAU, 24, color, 2.5, true)
		var label: String = tr("transport.short." + role)
		var font_size: int = clampi(roundi(_radius * 0.43), 9, 18)
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, at + Vector2(-width * 0.5, -_radius * 0.52), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	for job: Dictionary in t["shipments"]:
		var at: Vector2 = center_of(int(job["current"])) + Vector2(_radius * 0.45, _radius * 0.20)
		var blocked: bool = TransportGame.shipment_status(transport_model, job) == "transport.status.blocked"
		draw_circle(at, maxf(3.0, _radius * 0.13), Color("dc9681") if blocked else Color("e9dfb3"))
