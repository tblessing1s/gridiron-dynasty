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

static func read_chance(awareness: int) -> float:
    return float(awareness) / 100.0 * 0.9
