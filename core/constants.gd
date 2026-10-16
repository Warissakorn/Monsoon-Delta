class_name C
extends RefCounted
## Shared vocabulary. Balance values belong in data/balance.json.

enum Season { DRY, RAIN }
enum Phase { CARD_PICK, EVENT, PLANNING, HARVEST, GAME_OVER }
enum Feature { NONE, FOREST, SAPLING, PADDY }
enum Building { NONE, HALL, HOUSE, STILT_HOUSE, RAFT_HOUSE, GATE, GRANARY, FISH_TRAP, RESERVOIR, WATERWHEEL }
enum Outcome { NONE, WIN, LOSE_HALL, LOSE_POPULATION }

const EPS: float = 1e-6
const MAP_RADIUS: int = 4
const YEARS: int = 5
const TURNS_PER_YEAR: int = 6
const DRY_TURNS: int = 3
const HEIGHT_UNIT: float = 0.4


static func enum_name(values: Dictionary, value: int) -> String:
	var key: Variant = values.find_key(value)
	if key == null:
		push_error("Unknown enum value: %s" % value)
		return "none"
	return String(key).to_lower()


static func enum_value(values: Dictionary, text: String) -> int:
	var key: String = text.to_upper()
	if not values.has(key):
		push_error("Unknown enum name: " + text)
		return 0
	return int(values[key])
