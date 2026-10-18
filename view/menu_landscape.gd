extends Control
## A quiet delta at sundown, drawn in layers without image assets or a running clock.
## Coordinates use a 960 × 600 artboard so the composition follows the menu card.

var colors: Dictionary = {}:
	set(value):
		colors = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	if colors.is_empty():
		var palette = JSON.parse_string(FileAccess.get_file_as_string("res://data/palette.json"))
		if palette is Dictionary:
			colors = palette
	queue_redraw()


func _color(key: String, fallback: String) -> Color:
	return Color(colors.get(key, fallback))


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(960.0, 600.0))
	_draw_sky()
	_draw_hills()
	_draw_fields()
	_draw_river()
	_draw_village()
	_draw_foreground()
	draw_rect(Rect2(0, 0, 960, 600), _color("paper", "f4efdb") * Color(1, 1, 1, 0.12), false, 1.0)
	draw_set_transform(Vector2.ZERO)


func _draw_sky() -> void:
	var dusk: Color = _color("lagoon", "123e44").lerp(Color("59716a"), 0.58)
	var haze: Color = _color("accent", "c6a66d").lerp(Color("a3b39a"), 0.48)
	for row: int in range(220):
		var weight: float = float(row) / 219.0
		draw_rect(Rect2(0, row, 960, 1.2), dusk.lerp(haze, pow(weight, 1.2)))
	# Broad transparent veils keep the light atmospheric instead of a hard halo.
	for ring: int in range(18, 0, -1):
		var glow := Color("e4c28b", 0.008 + float(18 - ring) * 0.0008)
		_ellipse(Vector2(657, 126), Vector2(34 + ring * 7, 26 + ring * 3), glow)
	draw_circle(Vector2(657, 122), 30, Color("f0d7a0", 0.84), true, -1.0, true)
	_ellipse(Vector2(660, 147), Vector2(75, 5), Color("d1c9a3", 0.28))
	_ellipse(Vector2(512, 83), Vector2(116, 4), Color("dce0c3", 0.10))
	_ellipse(Vector2(767, 75), Vector2(135, 3), Color("dce0c3", 0.08))
	_ellipse(Vector2(355, 133), Vector2(120, 3), Color("e0d7ae", 0.09))
	for i: int in range(42):
		var y: float = 18.0 + i * 4.7
		var x: float = fmod(i * 153.7, 940.0)
		draw_line(Vector2(x, y), Vector2(minf(x + 40 + i % 4 * 19, 960), y), Color("f4efdb", 0.018), 1.0)
	_bird(Vector2(730, 112), 9, Color("294e4b", 0.78))
	_bird(Vector2(757, 103), 6, Color("294e4b", 0.62))
	_bird(Vector2(784, 120), 4, Color("294e4b", 0.52))


func _draw_hills() -> void:
	_shape(_bezier([
		Vector2(-30, 191), Vector2(57, 177), Vector2(89, 127), Vector2(170, 141),
		Vector2(246, 153), Vector2(257, 182), Vector2(334, 173),
		Vector2(416, 162), Vector2(420, 147), Vector2(492, 174),
		Vector2(555, 196), Vector2(622, 180), Vector2(686, 171),
		Vector2(745, 163), Vector2(835, 135), Vector2(886, 149),
		Vector2(940, 159), Vector2(978, 178), Vector2(995, 178)
	]) + PackedVector2Array([Vector2(995, 260), Vector2(-30, 260)]), Color("6e8d7b"))
	_shape(_bezier([
		Vector2(-30, 215), Vector2(41, 181), Vector2(118, 203), Vector2(190, 180),
		Vector2(243, 161), Vector2(317, 181), Vector2(367, 204),
		Vector2(429, 232), Vector2(488, 199), Vector2(551, 211),
		Vector2(632, 225), Vector2(670, 179), Vector2(734, 190),
		Vector2(814, 202), Vector2(834, 189), Vector2(884, 188),
		Vector2(938, 188), Vector2(967, 210), Vector2(990, 204)
	]) + PackedVector2Array([Vector2(990, 290), Vector2(-30, 290)]), Color("4d7464"))
	# Mist lies between the hill layers and the dark, irregular riverside canopy.
	_ellipse(Vector2(445, 213), Vector2(410, 9), Color("c0c4a1", 0.13))
	_ellipse(Vector2(749, 216), Vector2(267, 5), Color("c0c4a1", 0.15))
	var canopy := PackedVector2Array([Vector2(-20, 265)])
	for i: int in range(104):
		var x: float = i * 9.6 - 15.0
		var y: float = 244.0 - 12.0 * sin(i * 0.26) - 4.0 * sin(i * 1.73)
		if x > 525 and x < 645:
			y += 10.0
		canopy.append(Vector2(x, y))
	canopy.append(Vector2(980, 330))
	canopy.append(Vector2(-20, 330))
	_shape(canopy, _color("forest", "2b5747").lerp(Color("376957"), 0.5))
	for i: int in range(28):
		var x: float = i * 37.0 - 20
		var y: float = 248 - sin(i * 0.94) * 8
		_ellipse(Vector2(x, y), Vector2(22, 13 + i % 3 * 2), Color("386b55", 0.7))
	_ellipse(Vector2(558, 256), Vector2(280, 5), Color("a9b797", 0.16))


func _draw_fields() -> void:
	# Paddies follow the river, with their divisions opening out toward the viewer.
	draw_rect(Rect2(0, 272, 960, 328), Color("55734d"))
	_shape([Vector2(0, 283), Vector2(359, 268), Vector2(535, 287), Vector2(452, 314), Vector2(0, 347)], Color("7b8b55"))
	_shape([Vector2(0, 350), Vector2(433, 316), Vector2(519, 336), Vector2(390, 370), Vector2(0, 409)], Color("919451"))
	_shape([Vector2(0, 416), Vector2(374, 377), Vector2(504, 409), Vector2(431, 449), Vector2(0, 488)], Color("a09a58"))
	_shape([Vector2(0, 496), Vector2(412, 455), Vector2(453, 475), Vector2(327, 600), Vector2(0, 600)], Color("7b8848"))
	_shape([Vector2(653, 271), Vector2(960, 264), Vector2(960, 380), Vector2(732, 364), Vector2(623, 300)], Color("738051"))
	_shape([Vector2(785, 389), Vector2(960, 366), Vector2(960, 530), Vector2(662, 482)], Color("71834e"))
	_shape([Vector2(665, 497), Vector2(960, 539), Vector2(960, 600), Vector2(632, 600)], Color("5f7647"))
	# Fine parallel seedlings, broken deliberately rather than a repeated grid.
	for i: int in range(35):
		var y: float = 287.0 + i * 8.6
		var extent: float = 430.0 - i * 1.2
		for j: int in range(5):
			var x: float = j * 91 + fmod(i * 13.0, 23.0) - 35
			if x > extent:
				continue
			var end: float = minf(x + 53 + (i + j) % 4 * 7, extent)
			var tint := Color("d3c578", 0.17 if i % 2 == 0 else 0.10)
			draw_line(Vector2(x, y), Vector2(end, y - (end - x) * 0.075), tint, 1.2, true)
	for row: int in range(12):
		for column: int in range(11):
			var x: float = 22 + column * 34 + row % 2 * 13
			var y: float = 383 + row * 14 - x * 0.085
			var seed_color := Color("d8c779", 0.25)
			draw_line(Vector2(x, y), Vector2(x - 1.5, y - 4), seed_color, 1.0, true)
			draw_line(Vector2(x, y), Vector2(x + 2, y - 3), seed_color, 1.0, true)
	# Raised earth bunds have a sunlit upper edge and a cool underslope.
	var bunds: Array = [
		[Vector2(-10, 347), Vector2(125, 335), Vector2(328, 330), Vector2(452, 314)],
		[Vector2(-10, 410), Vector2(131, 396), Vector2(268, 391), Vector2(391, 370)],
		[Vector2(-10, 488), Vector2(154, 474), Vector2(293, 471), Vector2(431, 449)],
		[Vector2(121, 274), Vector2(176, 325), Vector2(210, 382), Vector2(245, 468), Vector2(273, 600)],
		[Vector2(310, 272), Vector2(352, 312), Vector2(322, 389)]
	]
	for bund: Array in bunds:
		draw_polyline(PackedVector2Array(bund), Color("435b3b"), 4.8, true)
		var edge := PackedVector2Array()
		for point: Vector2 in bund:
			edge.append(point + Vector2(0, -1.9))
		draw_polyline(edge, Color("d1bc75", 0.47), 1.3, true)
	_tree(Vector2(336, 290), 0.38, Color("355b3d"), Color("526e43"))
	_tree(Vector2(59, 311), 0.55, Color("2c543c"), Color("44663f"))
	_tree(Vector2(899, 300), 0.52, Color("2d5941"), Color("527347"))


func _river_outline() -> PackedVector2Array:
	return _bezier([
		Vector2(564, 247), Vector2(548, 266), Vector2(492, 273), Vector2(505, 298),
		Vector2(518, 326), Vector2(605, 330), Vector2(607, 373),
		Vector2(610, 417), Vector2(499, 454), Vector2(447, 494),
		Vector2(399, 531), Vector2(366, 569), Vector2(349, 610),
		Vector2(420, 617), Vector2(569, 615), Vector2(635, 610),
		Vector2(627, 551), Vector2(593, 520), Vector2(622, 485),
		Vector2(652, 451), Vector2(758, 419), Vector2(748, 370),
		Vector2(738, 316), Vector2(609, 305), Vector2(586, 279),
		Vector2(571, 264), Vector2(588, 253), Vector2(595, 247)
	])


func _draw_river() -> void:
	var outline: PackedVector2Array = _river_outline()
	_shape(outline, _color("lagoon", "123e44").lerp(Color("477e75"), 0.48))
	# Scan the hand-drawn river so every glint stays inside its winding banks.
	for row: int in range(88):
		var y: float = 250.0 + row * 4.15
		var intersections := PackedFloat32Array()
		for i: int in range(outline.size()):
			var start: Vector2 = outline[i]
			var finish: Vector2 = outline[(i + 1) % outline.size()]
			if (start.y <= y and finish.y > y) or (finish.y <= y and start.y > y):
				intersections.append(start.x + (y - start.y) / (finish.y - start.y) * (finish.x - start.x))
		intersections.sort()
		for i: int in range(0, intersections.size() - 1, 2):
			var left: float = intersections[i] + 4.0
			var right: float = intersections[i + 1] - 4.0
			var river_width: float = right - left
			if river_width < 4.0:
				continue
			var phase: float = sin(row * 12.13) * 0.5 + 0.5
			var x: float = left + river_width * phase * 0.6
			var glint_width: float = minf(right - x, (9 + row * 0.35) * (1 + phase))
			var opacity: float = 0.09 + (1.0 - float(row) / 100.0) * 0.17
			draw_line(Vector2(x, y), Vector2(x + glint_width, y), Color("e2c788", opacity), 1.0, true)
			if river_width > 45:
				var x2: float = right - river_width * 0.15
				draw_line(Vector2(x2 - 11 - phase * 13, y + 1.7), Vector2(x2, y + 1.7), Color("89b5a4", 0.15), 1.0, true)
	var left_bank: PackedVector2Array = _bezier([
		Vector2(564, 247), Vector2(548, 266), Vector2(492, 273), Vector2(505, 298),
		Vector2(518, 326), Vector2(605, 330), Vector2(607, 373),
		Vector2(610, 417), Vector2(499, 454), Vector2(447, 494),
		Vector2(399, 531), Vector2(366, 569), Vector2(349, 610)
	])
	draw_polyline(left_bank, Color("b3b17b", 0.58), 2.2, true)
	var right_bank: PackedVector2Array = _bezier([
		Vector2(595, 247), Vector2(588, 253), Vector2(571, 264), Vector2(586, 279),
		Vector2(609, 305), Vector2(738, 316), Vector2(748, 370),
		Vector2(758, 419), Vector2(652, 451), Vector2(622, 485),
		Vector2(593, 520), Vector2(627, 551), Vector2(635, 610)
	])
	draw_polyline(right_bank, Color("294e3f", 0.85), 4.0, true)
	# A single small boat gives the panorama a human scale.
	var boat := PackedVector2Array([Vector2(576, 427), Vector2(593, 433), Vector2(620, 428), Vector2(611, 437), Vector2(590, 440), Vector2(581, 436)])
	_ellipse(Vector2(601, 444), Vector2(29, 3), Color("0d3438", 0.34))
	_shape(boat, Color("2a3730"))
	draw_line(Vector2(584, 431), Vector2(614, 430), Color("caad76"), 1.4, true)
	draw_line(Vector2(602, 422), Vector2(608, 436), Color("d6bd84"), 1.5, true)
	draw_circle(Vector2(596, 422), 2.5, Color("d8bb82"), true, -1.0, true)
	_shape([Vector2(593, 425), Vector2(599, 425), Vector2(601, 431), Vector2(591, 432)], Color("a76c4b"))
	draw_line(Vector2(573, 445), Vector2(595, 447), Color("a7b89a", 0.23), 1.0, true)


func _draw_village() -> void:
	# A few trees behind the roofs; the open river stays the focus of the picture.
	_tree(Vector2(804, 310), 0.88, Color("244e38"), Color("3f6741"))
	_tree(Vector2(851, 329), 1.02, Color("294e36"), Color("4d6c41"))
	_palm(Vector2(740, 306), 91, -12, Color("355b3f"), Color("718257"))
	_palm(Vector2(895, 332), 115, 14, Color("254c39"), Color("4d7148"))
	_house(Vector2(711, 308), 0.64, true)
	_house(Vector2(773, 322), 0.76, false)
	_house(Vector2(848, 350), 0.91, true)
	_house(Vector2(789, 387), 1.04, false)
	# Narrow timber landings are made of a few uneven planks, not a solid platform.
	var walkway := PackedVector2Array([Vector2(704, 318), Vector2(750, 336), Vector2(795, 364), Vector2(773, 398), Vector2(733, 412)])
	draw_polyline(walkway, Color("3e4c36"), 8.0, true)
	draw_polyline(walkway, Color("b3a475"), 3.0, true)
	for i: int in range(8):
		var x: float = 736 + i * 5.4
		var y: float = 409 - i * 2.1
		draw_line(Vector2(x, y - 4), Vector2(x + 4, y + 3), Color("d0b382", 0.56), 1.2, true)
	draw_line(Vector2(736, 414), Vector2(736, 427), Color("293d31"), 2.4, true)
	draw_line(Vector2(768, 402), Vector2(768, 417), Color("293d31"), 2.4, true)
	for i: int in range(4):
		var x: float = 809 + i * 13
		var y: float = 400 + i * 2
		draw_line(Vector2(x, y), Vector2(x + 9, y + 1), Color("93a77d", 0.27), 1.0, true)
	_tree(Vector2(915, 430), 0.87, Color("24462e"), Color("43613a"))
	_tree(Vector2(695, 294), 0.34, Color("355c3e"), Color("66804c"))


func _house(base: Vector2, scale_factor: float, warm: bool) -> void:
	var wall: Color = _color("house", "c8b58a").darkened(0.08)
	var roof: Color = _color("roof", "ae6d4d")
	var s: float = scale_factor
	_ellipse(base + Vector2(8, 13) * s, Vector2(36, 6) * s, Color("183c32", 0.28))
	for x: int in [-28, -3, 23]:
		draw_line(base + Vector2(x, -12) * s, base + Vector2(x, 16) * s, Color("38402c"), 2.8 * s, true)
		draw_line(base + Vector2(x, -9) * s, base + Vector2(x, 11) * s, Color("ba9d66", 0.47), 1.0 * s, true)
	_shape(_offset([Vector2(-30, -34), Vector2(11, -31), Vector2(11, -6), Vector2(-30, -8)], base, s), wall)
	_shape(_offset([Vector2(11, -31), Vector2(30, -39), Vector2(30, -15), Vector2(11, -6)], base, s), wall.darkened(0.27))
	for i: int in range(6):
		var x: float = -26 + i * 6.3
		draw_line(base + Vector2(x, -31) * s, base + Vector2(x, -9) * s, Color("736c48", 0.33), 0.8 * s, true)
	_shape(_offset([Vector2(-39, -34), Vector2(-13, -58), Vector2(19, -51), Vector2(7, -28)], base, s), roof)
	_shape(_offset([Vector2(7, -28), Vector2(19, -51), Vector2(39, -37), Vector2(31, -32)], base, s), roof.darkened(0.22))
	draw_polyline(_offset([Vector2(-39, -34), Vector2(-13, -58), Vector2(19, -51), Vector2(39, -37)], base, s), Color("e0b47c", 0.65), 1.5 * s, true)
	for i: int in range(4):
		var shift: float = i * 4.4
		draw_line(base + Vector2(-30 + shift, -37 - shift * 0.55) * s, base + Vector2(8 + shift * 0.5, -32 - shift * 0.8) * s, Color("6a4933", 0.28), 0.8 * s, true)
	var window_color: Color = Color("e8ba69") if warm else Color("4d5540")
	_shape(_offset([Vector2(-21, -25), Vector2(-12, -24), Vector2(-12, -15), Vector2(-21, -16)], base, s), window_color)
	draw_line(base + Vector2(-16.5, -25) * s, base + Vector2(-16.5, -15) * s, Color("685b3c"), 1.0 * s, true)
	_shape(_offset([Vector2(-2, -24), Vector2(5, -23), Vector2(5, -6), Vector2(-2, -7)], base, s), Color("4f5037"))
	draw_line(base + Vector2(-33, -6) * s, base + Vector2(15, -3) * s, Color("ddbf83"), 2.0 * s, true)
	if warm:
		draw_circle(base + Vector2(-17, -20) * s, 11 * s, Color("eac47c", 0.035), true, -1.0, true)


func _draw_foreground() -> void:
	# The nearest bank frames the open center, with broad leaves cutting the card edge.
	_shape(_bezier([
		Vector2(-20, 516), Vector2(75, 500), Vector2(113, 516), Vector2(170, 540),
		Vector2(213, 556), Vector2(271, 550), Vector2(314, 578),
		Vector2(338, 593), Vector2(344, 607), Vector2(350, 620)
	]) + PackedVector2Array([Vector2(-20, 620)]), Color("183d31"))
	_shape(_bezier([
		Vector2(679, 620), Vector2(724, 556), Vector2(782, 573), Vector2(821, 553),
		Vector2(868, 527), Vector2(922, 522), Vector2(980, 541)
	]) + PackedVector2Array([Vector2(980, 620)]), Color("1c4132"))
	_tree(Vector2(-10, 526), 1.64, Color("173b2d"), Color("2c5335"))
	_tree(Vector2(978, 546), 1.52, Color("173c2d"), Color("315638"))
	_palm(Vector2(94, 622), 262, -42, Color("163b2d"), Color("44663e"))
	_palm(Vector2(936, 632), 223, 36, Color("153a2d"), Color("375a39"))
	for i: int in range(18):
		var x: float = i * 18.0 - 16.0
		var y: float = 592 + sin(i * 1.67) * 13
		var leaf_color := Color("365c36") if i % 3 == 0 else Color("214b32")
		_leaf(Vector2(x, y + 26), Vector2(x - 23 + i % 4 * 13, y - 20 - i % 3 * 11), 8 + i % 4 * 3, leaf_color)
	for i: int in range(15):
		var x: float = 742 + i * 17
		var y: float = 595 + sin(i * 1.81) * 17
		_leaf(Vector2(x, 625), Vector2(x - 25 + i % 3 * 18, y - 17 - i % 4 * 8), 10 + i % 3 * 3, Color("2a5233"))
	for i: int in range(22):
		var x: float = 158 + i * 8.1
		var y: float = 574 + sin(i * 2.37) * 8 + i * 0.75
		draw_line(Vector2(x, y + 15), Vector2(x - 4, y - i % 3 * 5), Color("78915a", 0.55), 1.1, true)
		draw_line(Vector2(x, y + 15), Vector2(x + 5, y - 2), Color("78915a", 0.4), 1.1, true)
	# Small floating flecks draw a gentle eye line back to the water.
	for point: Vector2 in [Vector2(318, 513), Vector2(691, 474), Vector2(851, 452)]:
		draw_circle(point, 1.3, Color("e9d18a", 0.66), true, -1.0, true)


func _tree(base: Vector2, s: float, shade: Color, light: Color) -> void:
	draw_line(base, base + Vector2(-3, -43) * s, shade.darkened(0.15), 6 * s, true)
	draw_line(base + Vector2(-2, -25) * s, base + Vector2(17, -49) * s, shade, 3 * s, true)
	_ellipse(base + Vector2(-16, -42) * s, Vector2(29, 18) * s, shade)
	_ellipse(base + Vector2(11, -49) * s, Vector2(27, 22) * s, shade)
	_ellipse(base + Vector2(-2, -62) * s, Vector2(27, 20) * s, light)
	_ellipse(base + Vector2(-24, -53) * s, Vector2(22, 17) * s, light.darkened(0.08))
	_ellipse(base + Vector2(24, -43) * s, Vector2(22, 16) * s, shade.lerp(light, 0.35))
	_ellipse(base + Vector2(-6, -71) * s, Vector2(14, 8) * s, light.lightened(0.055))


func _palm(base: Vector2, height: float, lean: float, shade: Color, light: Color) -> void:
	var crown: Vector2 = base + Vector2(lean, -height)
	var trunk: PackedVector2Array = _bezier([
		base + Vector2(-4, 0), base + Vector2(lean * 0.1 - 5, -height * 0.4), crown + Vector2(3, height * 0.17), crown,
		crown + Vector2(5, height * 0.17), base + Vector2(lean * 0.1 + 3, -height * 0.4), base + Vector2(4, 0)
	])
	_shape(trunk, shade.lerp(Color("a2925a"), 0.24))
	draw_polyline(_bezier([base + Vector2(-2, -1), base + Vector2(lean * 0.1 - 4, -height * 0.4), crown + Vector2(2, height * 0.17), crown]), light.darkened(0.14), 1.7, true)
	for i: int in range(7):
		var angle: float = -2.9 + i * 0.45
		var reach: float = height * (0.29 + sin(i * 1.3) * 0.065)
		var tip: Vector2 = crown + Vector2(cos(angle) * reach, sin(angle) * reach * 0.53 + reach * 0.27)
		var leaf_color: Color = shade if i % 2 == 0 else light
		_leaf(crown, tip, height * 0.037, leaf_color)
		var mid: Vector2 = crown.lerp(tip, 0.53) + Vector2(0, -height * 0.06)
		draw_polyline(_bezier([crown, crown.lerp(mid, 0.5), mid, tip]), light.lightened(0.08) * Color(1, 1, 1, 0.45), 0.8, true)
		for j: int in range(3):
			var stem: Vector2 = crown.lerp(tip, 0.35 + j * 0.17) + Vector2(0, -height * 0.035)
			var end: Vector2 = stem + Vector2((tip.x - crown.x) * 0.13, height * (0.046 + j * 0.008))
			draw_line(stem, end, leaf_color, maxf(1, height * 0.01), true)
	_leaf(crown, crown + Vector2(height * 0.27, -height * 0.06), height * 0.03, light)
	_leaf(crown, crown + Vector2(-height * 0.13, -height * 0.23), height * 0.03, light)


func _leaf(base: Vector2, tip: Vector2, width: float, tint: Color) -> void:
	var direction: Vector2 = tip - base
	var normal: Vector2 = Vector2(-direction.y, direction.x).normalized() * width
	var bend: Vector2 = Vector2(0, -direction.length() * 0.17)
	_shape(_bezier([
		base, base + direction * 0.24 + normal + bend, base + direction * 0.73 + normal * 0.6 + bend, tip,
		base + direction * 0.67 - normal * 0.3 + bend, base + direction * 0.2 - normal * 0.5 + bend, base
	]), tint)


func _bird(at: Vector2, wingspan: float, tint: Color) -> void:
	draw_polyline(_bezier([
		at + Vector2(-wingspan, 0), at + Vector2(-wingspan * 0.4, -3), at + Vector2(-2, 0), at + Vector2(0, 2),
		at + Vector2(2, 0), at + Vector2(wingspan * 0.4, -3), at + Vector2(wingspan, -1)
	]), tint, 1.4, true)


func _ellipse(center: Vector2, radii: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for i: int in range(40):
		var angle: float = TAU * i / 40.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	_shape(points, tint)


func _shape(points, tint: Color) -> void:
	var polygon := PackedVector2Array(points)
	if polygon.size() < 3:
		return
	draw_colored_polygon(polygon, tint)
	polygon.append(polygon[0])
	draw_polyline(polygon, tint, 0.7, true)


func _offset(points: Array, origin: Vector2, s: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(origin + point * s)
	return result


func _bezier(points: Array) -> PackedVector2Array:
	var path := PackedVector2Array()
	path.append(points[0])
	for i: int in range(0, points.size() - 3, 3):
		for step: int in range(1, 13):
			var weight: float = step / 12.0
			var start: Vector2 = points[i]
			path.append(start.bezier_interpolate(points[i + 1], points[i + 2], points[i + 3], weight))
	return path
