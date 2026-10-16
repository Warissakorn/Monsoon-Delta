class_name BotFarmer
extends RefCounted
## Plant only during dry turns, taking the nearest original-river cells first.


static func play_turn(state: GameState, _random: RandomNumberGenerator = null) -> int:
	if state.is_rain() or state.phase != C.Phase.PLANNING:
		return 0
	var rivers: Array[Vector2i] = []
	for tile: Tile in state.tiles:
		if tile.is_river:
			rivers.append(tile.coord)
	if rivers.is_empty():
		return 0
	var actions: int = 0
	while state.labor > 0:
		var targets: Array[Vector2i] = CommandRules.valid_targets(state, "paddy", -1)
		if targets.is_empty():
			break
		var chosen: Vector2i = targets[0]
		var nearest: int = C.MAP_RADIUS * 2 + 1
		# Scanning the state preserves tile-index order when distances tie.
		for tile: Tile in state.tiles:
			if not targets.has(tile.coord):
				continue
			var distance: int = C.MAP_RADIUS * 2 + 1
			for river: Vector2i in rivers:
				distance = mini(distance, Hex.distance(tile.coord, river))
			if distance < nearest:
				nearest = distance
				chosen = tile.coord
		var error: String = GameFlow.apply_command(state, Command.new("paddy", chosen))
		if not error.is_empty():
			push_error("Farmer could not apply a legal command: " + error)
			return -1
		actions += 1
	return actions
