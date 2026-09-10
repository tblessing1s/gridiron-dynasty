extends RefCounted

const GameConstants = preload("res://scripts/core/game_constants.gd")

# Two hard-coded 7-man lineups for testing the battle. Everyone plays both
# ways: slot order is QB/S, RB/LB, WR/CB, WR/CB, then three BL/X linemen.

const LINE_START: int = 4
const LINE_SIZE: int = 3

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
