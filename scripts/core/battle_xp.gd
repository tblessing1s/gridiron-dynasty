extends RefCounted

const Rosters = preload("res://scripts/core/rosters.gd")

# Turns what a player actually did in a battle into stat gains. Kept as a
# table so the aftermath screen can show exactly why each point was earned.
# Gains stop at the player's hidden potential, and a raided player keeps
# each point only three times in four.

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

# Returns the gains actually kept, so the report matches the roster.
static func apply(player: Dictionary, stat_gains: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    var kept: Dictionary = {}
    var loyalty: float = float(player.get("loyalty", 1.0))
    var potential: Dictionary = player.get("potential", {})
    for key in stat_gains.keys():
        var amount: int = 0
        for i in range(int(stat_gains[key])):
            if rng.randf() <= loyalty:
                amount += 1
        var ceiling: int = int(potential.get(key, 99))
        var new_value: int = clampi(int(player[key]) + amount, 1, maxi(ceiling, int(player[key])))
        var actual: int = new_value - int(player[key])
        if actual > 0:
            player[key] = new_value
            kept[key] = actual
    return kept

static func fatigue_bars(stats: Dictionary, fatigue_multiplier: float = 1.0) -> int:
    return clampi(int(float(stats["plays"]) * fatigue_multiplier) / FATIGUE_PLAYS_PER_BAR, 0, MAX_FATIGUE_BARS)

static func _add(result: Dictionary, key: String, amount: int) -> void:
    var capped: int = mini(amount, STAT_CAP_PER_BATTLE)
    if capped > 0:
        result[key] = capped
