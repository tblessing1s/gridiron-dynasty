extends RefCounted

enum Offense { SLANTS, DEEP_SHOT, DRAW, SCREEN }
enum Defense { COVER, BLITZ, SPY }

const OFFENSE_NAMES: Array[String] = ["SLANTS", "DEEP SHOT", "DRAW", "SCREEN"]
const DEFENSE_NAMES: Array[String] = ["COVER", "BLITZ", "SPY"]
const OFFENSE_HINTS: Array[String] = ["quick pass", "long pass", "run up the middle", "toss to the RB"]
const DEFENSE_HINTS: Array[String] = ["safe vs the pass", "sack chance up • loses to DRAW", "shadows the RB • stops the run"]
const OFFENSE_IS_RUN: Array[bool] = [false, false, true, true]

# Offense yardage multiplier by matchup. Rows are offense cards, columns are
# defense cards, in enum order.
const MATCHUP: Array = [
    [1.0, 1.25, 1.0],
    [0.55, 1.6, 1.0],
    [0.55, 1.6, 1.0],
    [1.0, 1.25, 0.55],
]

static func matchup_multiplier(offense: int, defense: int) -> float:
    var row: Array = MATCHUP[offense]
    return float(row[defense])

static func matchup_label(offense: int, defense: int) -> String:
    var multiplier: float = matchup_multiplier(offense, defense)
    if multiplier >= 1.5:
        return "great"
    if multiplier > 1.0:
        return "good"
    if multiplier < 1.0:
        return "bad"
    return "even"

static func ai_offense_card(down: int, yards_to_go: int, rng: RandomNumberGenerator) -> int:
    var weights: Array[int] = [30, 20, 30, 20]
    if yards_to_go >= 8:
        weights[Offense.DEEP_SHOT] += 15
        weights[Offense.DRAW] -= 10
    if yards_to_go <= 3:
        weights[Offense.DRAW] += 20
        weights[Offense.DEEP_SHOT] -= 10
    if down >= 4 and yards_to_go > 6:
        weights[Offense.DEEP_SHOT] += 20
        weights[Offense.DRAW] -= 15
    return _weighted_pick(weights, rng)

static func ai_defense_card(_down: int, yards_to_go: int, rng: RandomNumberGenerator) -> int:
    var weights: Array[int] = [45, 30, 25]
    if yards_to_go <= 3:
        weights[Defense.SPY] += 15
        weights[Defense.BLITZ] += 5
    if yards_to_go >= 8:
        weights[Defense.COVER] += 15
    return _weighted_pick(weights, rng)

static func _weighted_pick(weights: Array[int], rng: RandomNumberGenerator) -> int:
    var total: int = 0
    for weight in weights:
        total += maxi(weight, 1)
    var roll: int = rng.randi_range(1, total)
    var accumulated: int = 0
    for i in range(weights.size()):
        accumulated += maxi(weights[i], 1)
        if roll <= accumulated:
            return i
    return weights.size() - 1
