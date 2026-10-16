class_name BotGreedy
extends RefCounted
## Deterministic policies; their RNG is separate from the game's generator.

const GREEDY_COMMANDS: Array[String] = [
	"dig", "fill", "paddy", "house", "stilt_house", "chop", "plant", "gate",
	"toggle_gate", "fish_trap", "granary",
]
const RANDOM_COMMANDS: Array[String] = [
	"dig", "fill", "paddy", "house", "stilt_house", "raft_house", "chop", "plant",
	"gate", "toggle_gate", "reservoir", "fish_trap", "granary", "waterwheel", "demolish",
]


static func configuration(overrides: Dictionary = {}) -> Dictionary:
	var config: Dictionary = Dictionary(DataDB.balance()["bots"]).duplicate(true)
	for key: Variant in overrides:
		if key == "weights":
			config["weights"].merge(overrides[key], true)
		else:
			config[key] = overrides[key]
	return config


static func legal_commands(state: GameState, ids: Array[String] = GREEDY_COMMANDS) -> Array[Command]:
	var commands: Array[Command] = []
	for id: String in ids:
		if id == "waterwheel":
			for direction: int in 6:
				for coord: Vector2i in CommandRules.valid_targets(state, id, direction):
					commands.append(Command.new(id, coord, direction))
		else:
			for coord: Vector2i in CommandRules.valid_targets(state, id, -1):
				commands.append(Command.new(id, coord))
	return commands


static func score_preview(prediction: Dictionary, weights: Dictionary) -> float:
	var state: GameState = prediction["state"]
	var report: TurnReport = prediction["report"]
	var loss: float = 1.0 if state.outcome in [C.Outcome.LOSE_HALL, C.Outcome.LOSE_POPULATION] else 0.0
	var paddy_yield: int = 0
	for tile: Tile in state.tiles:
		if tile.feature == C.Feature.PADDY:
			paddy_yield += tile.paddy_yield
	return (
		float(weights["loss"]) * loss
		+ float(weights["capacity"]) * state.capacity()
		+ float(weights["destroyed"]) * report.destroyed.size()
		+ float(weights["paddies_died"]) * report.paddies_died.size()
		+ float(weights["paddy_yield"]) * paddy_yield
		+ float(weights["food"]) * state.food
		+ float(weights["wood"]) * state.wood
	)


static func play_turn(state: GameState, random: RandomNumberGenerator, overrides: Dictionary = {}) -> int:
	var config: Dictionary = configuration(overrides)
	var candidates: int = int(config["candidate_count"])
	var action_limit: int = int(config["max_actions_per_turn"])
	var weights: Dictionary = config["weights"]
	var actions: int = 0
	while state.phase == C.Phase.PLANNING and actions < action_limit:
		var options: Array[Command] = legal_commands(state)
		if options.is_empty():
			break
		var best_score: float = score_preview(GameFlow.preview(state), weights)
		var best: Command = null
		# Draw without replacement. Each of the prescribed candidates is legal.
		for _candidate: int in mini(candidates, options.size()):
			var index: int = random.randi_range(0, options.size() - 1)
			var command: Command = options[index]
			options[index] = options.back()
			options.pop_back()
			var trial: GameState = state.duplicate_state()
			var error: String = GameFlow.apply_command(trial, command)
			if not error.is_empty():
				push_error("Greedy could not apply a legal candidate: " + error)
				return -1
			var value: float = score_preview(GameFlow.preview(trial), weights)
			if value > best_score + C.EPS:
				best_score = value
				best = command
		if best == null:
			break
		var error: String = GameFlow.apply_command(state, best)
		if not error.is_empty():
			push_error("Greedy could not apply its selected command: " + error)
			return -1
		actions += 1
	return actions


static func play_random_turn(state: GameState, random: RandomNumberGenerator, overrides: Dictionary = {}) -> int:
	var config: Dictionary = configuration(overrides)
	var actions: int = 0
	# The bound prevents free gate toggles from keeping a turn alive forever.
	while state.phase == C.Phase.PLANNING and state.labor > 0 and actions < int(config["max_actions_per_turn"]):
		var options: Array[Command] = legal_commands(state, RANDOM_COMMANDS)
		if options.is_empty():
			break
		var chosen: Command = options[random.randi_range(0, options.size() - 1)]
		var error: String = GameFlow.apply_command(state, chosen)
		if not error.is_empty():
			push_error("Random bot could not apply a legal command: " + error)
			return -1
		actions += 1
	return actions


static func play_game(seed_value: int, policy: String, difficulty: int = 0, overrides: Dictionary = {}) -> Dictionary:
	if policy not in ["farmer", "greedy", "random"]:
		return {"state": null, "turns": 0, "actions": 0, "error": "unknown_bot"}
	var state: GameState = GameFlow.new_game({
		"seed": seed_value, "map_type": "plains", "leader": "farmer", "difficulty": difficulty,
	})
	if state == null:
		return {"state": null, "turns": 0, "actions": 0, "error": "new_game_failed"}
	var random := RandomNumberGenerator.new()
	random.seed = SeedUtil.derive_seed(seed_value, 9000)
	var turns: int = 0
	var actions: int = 0
	while state.phase != C.Phase.GAME_OVER:
		if state.phase == C.Phase.HARVEST:
			GameFlow.continue_after_harvest(state)
			continue
		# M3 deliberately has no card/event offers. Handle unexpected phases
		# explicitly rather than silently skipping game logic.
		if state.phase != C.Phase.PLANNING:
			return {"state": state, "turns": turns, "actions": actions, "error": "unsupported_phase"}
		if turns >= C.YEARS * C.TURNS_PER_YEAR:
			return {"state": state, "turns": turns, "actions": actions, "error": "turn_limit"}
		var performed: int = 0
		match policy:
			"farmer":
				performed = BotFarmer.play_turn(state, random)
			"greedy":
				performed = play_turn(state, random, overrides)
			"random":
				performed = play_random_turn(state, random, overrides)
		if performed < 0:
			return {"state": state, "turns": turns, "actions": actions, "error": "command_failed"}
		actions += performed
		var report: TurnReport = GameFlow.end_turn(state)
		if report == null:
			return {"state": state, "turns": turns, "actions": actions, "error": "end_turn_failed"}
		turns += 1
	return {"state": state, "turns": turns, "actions": actions, "error": ""}
