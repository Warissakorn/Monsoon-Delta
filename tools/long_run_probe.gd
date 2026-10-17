extends SceneTree
## Small reproducible play probe: real maps, legal commands, no saves or overrides.
## godot --headless --path . --script res://tools/long_run_probe.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_probe_baseline()
	_probe_goals()
	quit()


func _probe_baseline() -> void:
	for policy: String in ["farmer", "greedy"]:
		for seed_value: int in [1, 2, 42]:
			var state: GameState = GameFlow.new_game({"seed": seed_value, "run_mode": "long", "village_goal": "growth"})
			var random: RandomNumberGenerator = RandomNumberGenerator.new()
			random.seed = SeedUtil.derive_seed(seed_value, 9000)
			var turns: int = 0
			var actions: int = 0
			var peak_paddy: int = 0
			while state.phase != C.Phase.GAME_OVER and turns <= 60:
				if state.phase == C.Phase.HARVEST:
					peak_paddy = maxi(peak_paddy, int(state.harvest_report["paddy_food"]))
					GameFlow.continue_after_harvest(state)
					continue
				if policy == "farmer":
					actions += BotFarmer.play_turn(state, random)
				else:
					actions += BotGreedy.play_turn(state, random, {"candidate_count": 8})
				GameFlow.end_turn(state)
				turns += 1
			print(JSON.stringify({"policy": policy, "seed": seed_value, "outcome": C.enum_name(C.Outcome, state.outcome), "year": state.year, "turns": turns, "actions": actions, "population": state.population, "max_population": state.stats["max_population"], "food": state.food, "peak_paddy_food": peak_paddy, "goal": RunGoals.progress(state)}))


func _probe_goals() -> void:
	for goal: String in ["forest", "rice", "growth"]:
		var state: GameState = GameFlow.new_game({"seed": 1, "run_mode": "long", "village_goal": goal})
		var turns: int = 0
		var actions: int = 0
		var failures: Array[String] = []
		var peak_rice: int = 0
		while state.phase != C.Phase.GAME_OVER and turns <= 60:
			if state.phase == C.Phase.HARVEST:
				peak_rice = maxi(peak_rice, int(state.harvest_report["paddy_food"]))
				GameFlow.continue_after_harvest(state)
				continue
			if not state.is_rain():
				var desired: int = 12 if goal == "growth" else 8
				for _attempt: int in range(8):
					if state.capacity() >= desired:
						break
					var targets: Array[Vector2i] = CommandRules.valid_targets(state, "house")
					if not targets.is_empty():
						var best: Vector2i = targets[0]
						for coord: Vector2i in targets:
							if state.get_tile(coord).elevation > state.get_tile(best).elevation:
								best = coord
						var error: String = GameFlow.apply_command(state, Command.new("house", best))
						if not error.is_empty():
							failures.append(error)
						actions += 1
					elif state.wood < 2 and state.labor >= 1:
						var forests: Array[Vector2i] = CommandRules.valid_targets(state, "chop")
						if forests.is_empty() or (goal == "forest" and forests.size() <= 8):
							break
						var error: String = GameFlow.apply_command(state, Command.new("chop", forests.back()))
						if not error.is_empty():
							failures.append(error)
						actions += 1
					else:
						break
				actions += BotFarmer.play_turn(state)
			GameFlow.end_turn(state)
			turns += 1
		print(JSON.stringify({"policy": "farmer_and_safe_homes", "seed": 1, "goal_id": goal, "outcome": C.enum_name(C.Outcome, state.outcome), "year": state.year, "turns": turns, "actions": actions, "errors": failures, "peak_paddy_food": peak_rice, "max_population": state.stats["max_population"], "progress": RunGoals.progress(state)}))
