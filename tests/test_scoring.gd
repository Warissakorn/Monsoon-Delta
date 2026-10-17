extends "res://tests/test_case.gd"

const StateModel = preload("res://core/game_state.gd")
const ScoreRules = preload("res://core/scoring.gd")
const Constants = preload("res://core/constants.gd")


func _state() -> StateModel:
	var state: StateModel = StateModel.new()
	state.population = 6
	state.food = 7
	return state


func test_win_adds_both_preservation_bonuses() -> void:
	var state: StateModel = _state()
	state.outcome = Constants.Outcome.WIN
	assert_eq(ScoreRules.score(state), 147)


func test_nonwinning_outcomes_receive_only_population_and_food() -> void:
	var state: StateModel = _state()
	for outcome: int in [
		Constants.Outcome.NONE,
		Constants.Outcome.LOSE_HALL,
		Constants.Outcome.LOSE_POPULATION,
	]:
		state.outcome = outcome
		assert_eq(ScoreRules.score(state), 67, "outcome %d" % outcome)


func test_win_damage_flags_remove_only_their_own_bonus() -> void:
	var state: StateModel = _state()
	state.outcome = Constants.Outcome.WIN
	state.stats["houses_lost"] = 1
	assert_eq(ScoreRules.score(state), 97, "a lost house removes the house bonus")
	state.stats["houses_lost"] = 0
	state.stats["hall_ever_wet"] = true
	assert_eq(ScoreRules.score(state), 117, "wet hall removes the hall bonus")
	state.stats["houses_lost"] = 3
	assert_eq(ScoreRules.score(state), 67, "both damage flags remove both bonuses")


func test_difficulty_multiplies_bonuses_and_rounds_the_final_score() -> void:
	var state: StateModel = _state()
	state.outcome = Constants.Outcome.WIN
	state.difficulty = 3
	assert_eq(ScoreRules.score(state), 191, "147 times 1.3 rounds from 191.1")
	state.difficulty = 1
	state.food = 5
	assert_eq(ScoreRules.score(state), 160, "145 times 1.1 rounds from 159.5")


func test_loss_still_uses_difficulty_multiplier() -> void:
	var state: StateModel = _state()
	state.outcome = Constants.Outcome.LOSE_POPULATION
	state.difficulty = 5
	assert_eq(ScoreRules.score(state), 101, "67 times 1.5 rounds from 100.5")


func test_scoring_is_repeatable_and_does_not_mutate_state() -> void:
	var state: StateModel = _state()
	state.outcome = Constants.Outcome.WIN
	state.difficulty = 2
	state.final_score = 42
	state.rng.seed = 12345
	state.rng.randi()
	state.harvest_report = {"nested": {"values": [1, 2, 3]}}
	var before: Dictionary = state.to_dict()
	var mods_before: Dictionary = state.mods.duplicate(true)
	var index_before: Dictionary = state.index.duplicate(true)
	assert_eq(ScoreRules.score(state), 176)
	assert_eq(ScoreRules.score(state), 176)
	assert_eq(state.to_dict(), before, "all saved values and RNG state stay unchanged")
	assert_eq(state.mods, mods_before, "scoring does not populate modifier caches")
	assert_eq(state.index, index_before, "scoring does not rebuild the tile index")


func test_population_ten_example_uses_mt_01_formula() -> void:
	# MT-01 is authoritative; the TS-04 example omits one preservation bonus.
	var state: StateModel = _state()
	state.population = 10
	state.food = 5
	state.outcome = Constants.Outcome.WIN
	state.difficulty = 3
	assert_eq(ScoreRules.score(state), 241, "(100 + 5 + 50 + 30) * 1.3")
