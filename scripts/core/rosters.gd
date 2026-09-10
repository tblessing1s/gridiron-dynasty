extends RefCounted

const GameConstants = preload("res://scripts/core/game_constants.gd")

# Two hard-coded 7-man lineups for testing the battle. Everyone plays both
# ways: slot order is QB/S, RB/LB, WR/CB, WR/CB, then three BL/X linemen.

const LINE_START: int = 4
const LINE_SIZE: int = 3
const SLOT_TYPES: Array[String] = ["QB", "RB", "WR", "WR", "BL", "BL", "BL"]
const DEFENSE_SLOT_TYPES: Array[String] = ["S", "LB", "CB", "CB", "X", "X", "X"]

static func hawks() -> Dictionary:
    return {
        "name": "HARBOR HAWKS",
        "short": "HAWKS",
        "color": Color("2f77c7"),
        "players": [
            _player("Bell", 70, 55, 81, 74),
            _player("Okafor", 79, 70, 50, 55),
            _player("Reyes", 84, 45, 70, 60),
            _player("Cross", 72, 50, 77, 62),
            _player("Turner", 38, 79, 40, 58),
            _player("Voss", 40, 83, 45, 66),
            _player("Mbeki", 44, 77, 42, 60),
        ],
    }

static func forge() -> Dictionary:
    return {
        "name": "IRONVALE FORGE",
        "short": "FORGE",
        "color": Color("c2622a"),
        "players": [
            _player("Marsh", 60, 55, 76, 70),
            _player("Pike", 75, 72, 48, 50),
            _player("Lund", 80, 44, 72, 58),
            _player("Amari", 70, 48, 74, 60),
            _player("Holt", 40, 81, 38, 55),
            _player("Grange", 42, 88, 40, 62),
            _player("Dace", 45, 76, 44, 57),
        ],
    }

static func line_power(players: Array) -> float:
    var total: float = 0.0
    for i in range(LINE_START, LINE_START + LINE_SIZE):
        total += float(int(players[i].get("power", 50)))
    return total / float(LINE_SIZE)

static func _player(player_name: String, speed: int, power: int, skill: int, awareness: int) -> Dictionary:
    return {"name": player_name, "speed": speed, "power": power, "skill": skill, "awareness": awareness}

const FIRST_NAMES: Array[String] = ["Ade", "Bram", "Cal", "Dev", "Eli", "Finn", "Gus", "Hal", "Ike", "Jory", "Kai", "Lev", "Mose", "Nico", "Oz", "Pax", "Quin", "Rafe", "Sol", "Tam", "Ugo", "Vic", "Wes", "Zane"]
const LAST_NAMES: Array[String] = ["Adair", "Boone", "Calder", "Dray", "Ellis", "Farrow", "Gale", "Hardy", "Ivers", "Jett", "Kerr", "Lowe", "Marr", "Nash", "Orde", "Pryce", "Quill", "Rook", "Slade", "Tully", "Usher", "Vane", "Wick", "York"]

# Slot biases on top of a team rating: index order QB, RB, WR, WR, BL, BL, BL;
# values are speed, power, skill, awareness.
const SLOT_BIAS: Array = [
    [-8, -8, 12, 8],
    [8, 6, -8, -2],
    [10, -10, 4, 0],
    [10, -10, 4, 0],
    [-14, 14, -10, 0],
    [-14, 14, -10, 0],
    [-14, 14, -10, 0],
]

static func generate_players(rating: int, rng: RandomNumberGenerator) -> Array:
    var players: Array = []
    for i in range(SLOT_TYPES.size()):
        var bias: Array = SLOT_BIAS[i]
        var player_name: String = "%s %s" % [FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)], LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]]
        players.append(_player(
            player_name,
            clampi(rating + int(bias[0]) + rng.randi_range(-8, 8), 30, 95),
            clampi(rating + int(bias[1]) + rng.randi_range(-8, 8), 30, 95),
            clampi(rating + int(bias[2]) + rng.randi_range(-8, 8), 30, 95),
            clampi(rating + int(bias[3]) + rng.randi_range(-8, 8), 30, 95)
        ))
    return players

const STAT_KEYS: Array[String] = ["speed", "power", "skill", "awareness"]
const ROOKIE_SLOT_TYPES: Array[String] = ["QB", "RB", "WR", "BL"]
const ROOKIE_SLOT_WEIGHTS: Array[int] = [1, 1, 2, 3]

# Career fields: age, a hidden per-stat ceiling, where the player came from,
# and how fast he grows for this team. Added lazily so hand-made rosters
# and older saves pick them up.
static func ensure_career(player: Dictionary, rng: RandomNumberGenerator) -> void:
    if not player.has("age"):
        player["age"] = rng.randi_range(22, 31)
    if not player.has("potential"):
        var age: int = int(player["age"])
        var headroom: int = maxi(0, 28 - age) * 4 + 4
        var potential: Dictionary = {}
        for key in STAT_KEYS:
            potential[key] = clampi(int(player[key]) + rng.randi_range(0, headroom), int(player[key]), 99)
        player["potential"] = potential
    if not player.has("origin"):
        player["origin"] = "original"
    if not player.has("loyalty"):
        player["loyalty"] = 1.0

static func slot_bias_for_type(slot_type: String) -> Array:
    for i in range(SLOT_TYPES.size()):
        if SLOT_TYPES[i] == slot_type:
            return SLOT_BIAS[i]
    return [0, 0, 0, 0]

static func random_name(rng: RandomNumberGenerator) -> String:
    return "%s %s" % [FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)], LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]]

static func generate_rookie(slot_type: String, ceiling_low: int, ceiling_high: int, rng: RandomNumberGenerator) -> Dictionary:
    var bias: Array = slot_bias_for_type(slot_type)
    var base: int = rng.randi_range(42, 56)
    var target: int = rng.randi_range(ceiling_low, ceiling_high)
    var player: Dictionary = {"name": random_name(rng)}
    var potential: Dictionary = {}
    for k in range(STAT_KEYS.size()):
        var value: int = clampi(base + int(bias[k]) + rng.randi_range(-6, 6), 25, 90)
        player[STAT_KEYS[k]] = value
        potential[STAT_KEYS[k]] = clampi(target + int(bias[k]) + rng.randi_range(-6, 6), value, 99)
    player["potential"] = potential
    player["age"] = rng.randi_range(20, 22)
    player["origin"] = "drafted"
    player["loyalty"] = 1.0
    player["slot_type"] = slot_type
    player["grade"] = scout_grade(potential_average(player) + rng.randi_range(-4, 4))
    return player

static func generate_journeyman(slot_type: String, rng: RandomNumberGenerator) -> Dictionary:
    var bias: Array = slot_bias_for_type(slot_type)
    var base: int = rng.randi_range(44, 54)
    var player: Dictionary = {"name": random_name(rng)}
    var potential: Dictionary = {}
    for k in range(STAT_KEYS.size()):
        var value: int = clampi(base + int(bias[k]) + rng.randi_range(-5, 5), 25, 90)
        player[STAT_KEYS[k]] = value
        potential[STAT_KEYS[k]] = clampi(value + rng.randi_range(0, 4), value, 99)
    player["potential"] = potential
    player["age"] = rng.randi_range(27, 30)
    player["origin"] = "free agent"
    player["loyalty"] = 1.0
    return player

static func potential_average(player: Dictionary) -> int:
    if not player.has("potential"):
        return player_overall(player)
    var potential: Dictionary = player["potential"]
    var total: int = 0
    for key in STAT_KEYS:
        total += int(potential[key])
    return int(round(float(total) / float(STAT_KEYS.size())))

static func scout_grade(value: int) -> String:
    if value >= 85:
        return "A+"
    if value >= 78:
        return "A"
    if value >= 70:
        return "B"
    if value >= 62:
        return "C"
    return "D"

static func player_overall(player: Dictionary) -> int:
    var total: int = 0
    for key in ["speed", "power", "skill", "awareness"]:
        total += int(player[key])
    return int(round(float(total) / 4.0))

static func team_overall(team: Dictionary) -> int:
    var players: Array = team["players"]
    if players.is_empty():
        return 0
    var total: int = 0
    for player in players:
        total += player_overall(player)
    return int(round(float(total) / float(players.size())))

static func best_player_index(team: Dictionary) -> int:
    var players: Array = team["players"]
    var best: int = 0
    var best_overall: int = -1
    for i in range(players.size()):
        var overall: int = player_overall(players[i])
        if overall > best_overall:
            best_overall = overall
            best = i
    return best

# Stat-to-physics mappings. Kept together so tuning happens in one place.

static func pocket_seconds(block_power: int, rush_power: int) -> float:
    return clampf(2.4 + float(block_power - rush_power) * 0.05, 1.0, 5.0)

static func catch_radius(skill: int) -> float:
    return GameConstants.CATCH_RADIUS * (0.8 + float(skill) / 250.0)

static func intercept_radius(skill: int) -> float:
    return 12.0 + float(skill) * 0.14

static func scatter_px(skill: int) -> float:
    return float(100 - skill) * 0.9

static func break_tackle_chance(carrier_power: int, tackler_power: int) -> float:
    return clampf(0.1 + float(carrier_power - tackler_power) * 0.006, 0.02, 0.45)

static func decision_seconds(awareness: int) -> float:
    return lerpf(1.7, 0.9, float(awareness) / 100.0)

# Separation (px) that lets the QB pull the trigger early, in rhythm, rather
# than waiting out the full decision_seconds read. A sharper QB trusts a
# tighter window.
static func early_throw_separation(awareness: int) -> float:
    return lerpf(75.0, 45.0, float(awareness) / 100.0)

static func read_chance(awareness: int) -> float:
    return float(awareness) / 100.0 * 0.9

# ---------------------------------------------------------------- coordinators

# Generates an OC/DC pair the first time a team is seen; already-coached
# teams (a restored save, a season carried into a new one) are left alone.
static func ensure_coaches(team: Dictionary, rng: RandomNumberGenerator, base_rating: int) -> void:
    if team.has("coaches"):
        return
    team["coaches"] = {
        "oc": {"name": random_name(rng), "rating": clampi(base_rating + rng.randi_range(-12, 12), 30, 95)},
        "dc": {"name": random_name(rng), "rating": clampi(base_rating + rng.randi_range(-12, 12), 30, 95)},
    }

static func coach(team: Dictionary, role: String) -> Dictionary:
    var coaches: Dictionary = team.get("coaches", {})
    if coaches.has(role):
        var c: Dictionary = coaches[role]
        return {"name": str(c.get("name", "Coach")), "rating": int(c.get("rating", 60))}
    return {"name": "Coach", "rating": 60}

static func team_rating(players: Array) -> int:
    if players.is_empty():
        return 60
    var total: int = 0
    var count: int = 0
    for player in players:
        for key in STAT_KEYS:
            total += int(player[key])
            count += 1
    return int(round(float(total) / float(count)))

# ---------------------------------------------------------------- overall rating

# Slot-weighted overall (0-99): each of the four stats counted by how much
# the slot actually leans on it, rather than a flat average.
const SLOT_WEIGHTS: Dictionary = {
    "QB": {"speed": 0.1, "power": 0.1, "skill": 0.45, "awareness": 0.35},
    "RB": {"speed": 0.4, "power": 0.4, "skill": 0.1, "awareness": 0.1},
    "WR": {"speed": 0.45, "power": 0.05, "skill": 0.4, "awareness": 0.1},
    "BL": {"speed": 0.05, "power": 0.55, "skill": 0.1, "awareness": 0.3},
}

static func overall_for_type(player: Dictionary, slot_type: String) -> int:
    var weights: Dictionary = SLOT_WEIGHTS.get(slot_type, {"speed": 0.25, "power": 0.25, "skill": 0.25, "awareness": 0.25})
    var total: float = 0.0
    for key in STAT_KEYS:
        total += float(player[key]) * float(weights.get(key, 0.25))
    return clampi(int(round(total)), 0, 99)

# slot_index is 0-6 into SLOT_TYPES (the player's fixed offensive slot,
# regardless of which side of the ball is being displayed).
static func overall(player: Dictionary, slot_index: int) -> int:
    return overall_for_type(player, SLOT_TYPES[slot_index])

# Same letter grades the draft's scout report uses, so A+ means the same
# thing everywhere.
static func grade(value: int) -> String:
    return scout_grade(value)
