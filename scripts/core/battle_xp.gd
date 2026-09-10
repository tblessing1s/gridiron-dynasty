extends RefCounted

# Turns what a player actually did in a battle into stat gains. Kept as a
# table so the aftermath screen can show exactly why each point was earned.

const STAT_CAP_PER_BATTLE: int = 2
const FATIGUE_PLAYS_PER_BAR: int = 8
const MAX_FATIGUE_BARS: int = 4

static func empty_stats() -> Dictionary:
    return {"plays": 0, "catches": 0, "completions": 0, "yards": 0, "tackles": 0, "interceptions": 0, "pocket_wins": 0, "sacks": 0, "touchdowns": 0}

static func gains(stats: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    _add(result, "skill", int(stats["catches"]) / 2 + int(stats["completions"]) / 3)
    _add(result, "speed", int(stats["yards"]) / 40)
    _add(result, "power", int(stats["tackles"]) / 3 + int(stats["pocket_wins"]) / 4 + int(stats["sacks"]))
    _add(result, "awareness", int(stats["interceptions"]) + int(stats["touchdowns"]) / 2)
    return result

static func apply(player: Dictionary, stat_gains: Dictionary) -> void:
    for key in stat_gains.keys():
        player[key] = clampi(int(player[key]) + int(stat_gains[key]), 1, 99)

static func fatigue_bars(stats: Dictionary) -> int:
    return clampi(int(stats["plays"]) / FATIGUE_PLAYS_PER_BAR, 0, MAX_FATIGUE_BARS)

static func _add(result: Dictionary, key: String, amount: int) -> void:
    var capped: int = mini(amount, STAT_CAP_PER_BATTLE)
    if capped > 0:
        result[key] = capped
