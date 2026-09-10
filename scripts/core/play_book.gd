extends RefCounted

# The call sheet: six offense cards, four defense cards, and the situational
# weighting that decides what the AI calls and how much of it a player's
# coordinators and Awareness let them read before the snap.

enum Offense { SLANTS, DEEP_SHOT, DRAW, SCREEN, SWEEP, PLAY_ACTION }
enum Defense { COVER, BLITZ, SPY, PRESS }
enum Family { PASS, RUN }

const OFFENSE_NAMES: Array[String] = ["SLANTS", "DEEP SHOT", "DRAW", "SCREEN", "SWEEP", "PLAY ACTION"]
const DEFENSE_NAMES: Array[String] = ["COVER", "BLITZ", "SPY", "PRESS"]
const OFFENSE_HINTS: Array[String] = [
    "quick pass, hard to stop",
    "long pass, huge upside",
    "run up the middle",
    "toss to the RB",
    "run to the edge",
    "fake run, throw over the top",
]
const DEFENSE_HINTS: Array[String] = [
    "safe vs the pass",
    "sack chance up • loses to DRAW/SWEEP",
    "shadows the RB • stops the run",
    "tight coverage • beats short, loses deep",
]

# Draw, Screen, Sweep resolve as runs. Draw and Sweep hand the ball off in
# the real-time engine; Screen throws it first, then runs.
const OFFENSE_IS_RUN: Array[bool] = [false, false, true, true, true, false]
const OFFENSE_IS_HANDOFF: Array[bool] = [false, false, true, false, true, false]

# The "look" a card gives off before the snap, for tiered pre-snap reads.
# Play Action is a pass mechanically (see OFFENSE_IS_RUN) but sells itself
# as a run, so it reads as RUN here.
const OFFENSE_FAMILY: Array[int] = [Family.PASS, Family.PASS, Family.RUN, Family.RUN, Family.RUN, Family.RUN]
const DEFENSE_FAMILY: Array[int] = [Family.PASS, Family.RUN, Family.RUN, Family.PASS]
const FAMILY_NAMES: Array[String] = ["PASS", "RUN"]
const DEFENSE_FAMILY_NAMES: Array[String] = ["COVERAGE", "PRESSURE"]

# Offense yardage multiplier by matchup. Rows are offense cards, columns are
# defense cards, in enum order: Cover, Blitz, Spy, Press.
const MATCHUP: Array = [
    [1.0, 1.25, 1.0, 0.6],
    [0.55, 1.6, 1.0, 1.4],
    [0.9, 1.6, 0.55, 1.2],
    [1.0, 1.25, 0.55, 0.7],
    [1.1, 1.3, 0.7, 1.4],
    [1.2, 0.5, 1.5, 1.1],
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

# Press behaves like tight man coverage to the real-time defender AI, which
# only knows Cover/Blitz/Spy assignments; football_game additionally tightens
# the corners' coverage offset for Press.
static func defense_assignment(card: int) -> int:
    if card == Defense.PRESS:
        return Defense.COVER
    return card

static func offense_family_name(card: int) -> String:
    return FAMILY_NAMES[OFFENSE_FAMILY[card]]

static func defense_family_name(card: int) -> String:
    return DEFENSE_FAMILY_NAMES[DEFENSE_FAMILY[card]]

# ---------------------------------------------------------------- situation

# down/yards_to_go/ball_yard describe the play about to be called; score_diff
# is offense_score - defense_score; last_possession marks the final
# possession of regulation.
static func situation(down: int, yards_to_go: int, ball_yard: int, field_yards: int, score_diff: int, sudden_death: bool, last_possession: bool) -> Dictionary:
    return {
        "red_zone": field_yards - ball_yard <= 10,
        "short": yards_to_go <= 3,
        "long": yards_to_go >= 8,
        "fourth": down >= 4,
        "trailing": score_diff < 0,
        "leading": score_diff > 0,
        "sudden_death": sudden_death,
        "last_possession": last_possession,
    }

static func situation_text(sit: Dictionary) -> String:
    var tags: Array[String] = []
    if bool(sit.get("sudden_death", false)):
        tags.append("SUDDEN DEATH")
    if bool(sit.get("red_zone", false)):
        tags.append("RED ZONE")
    if bool(sit.get("fourth", false)):
        tags.append("4TH DOWN")
    if bool(sit.get("last_possession", false)):
        tags.append("FINAL DRIVE")
    if bool(sit.get("trailing", false)):
        tags.append("TRAILING")
    elif bool(sit.get("leading", false)):
        tags.append("LEADING")
    return " • ".join(tags)

# ---------------------------------------------------------------- AI calling

static func offense_weights(down: int, to_go: int, sit: Dictionary, tendency: Dictionary) -> Array[int]:
    var weights: Array[int] = [22, 16, 18, 14, 16, 14]
    if to_go <= 3:
        weights[Offense.DRAW] += 14
        weights[Offense.SWEEP] += 10
        weights[Offense.SCREEN] += 6
        weights[Offense.DEEP_SHOT] -= 10
    if to_go >= 8:
        weights[Offense.DEEP_SHOT] += 14
        weights[Offense.PLAY_ACTION] += 10
        weights[Offense.DRAW] -= 8
    if bool(sit.get("red_zone", false)):
        weights[Offense.DEEP_SHOT] -= 10
        weights[Offense.SLANTS] += 8
        weights[Offense.SCREEN] += 6
    if bool(sit.get("fourth", false)) and to_go > 3:
        weights[Offense.DEEP_SHOT] += 10
        weights[Offense.PLAY_ACTION] += 8
    if bool(sit.get("last_possession", false)) and bool(sit.get("trailing", false)):
        weights[Offense.DEEP_SHOT] += 18
        weights[Offense.PLAY_ACTION] += 10
        weights[Offense.DRAW] -= 10
    if bool(sit.get("sudden_death", false)):
        weights[Offense.DEEP_SHOT] -= 10
        weights[Offense.PLAY_ACTION] -= 6
        weights[Offense.SLANTS] += 8
        weights[Offense.SCREEN] += 6
    var run_lean: float = float(tendency.get("run_lean", 0.0))
    if run_lean != 0.0:
        var shift: int = int(round(run_lean * 12.0))
        weights[Offense.DRAW] += shift
        weights[Offense.SCREEN] += shift
        weights[Offense.SWEEP] += shift
        weights[Offense.SLANTS] -= shift
        weights[Offense.DEEP_SHOT] -= shift
    return weights

static func defense_weights(down: int, to_go: int, sit: Dictionary, tendency: Dictionary) -> Array[int]:
    var weights: Array[int] = [34, 24, 20, 22]
    if to_go <= 3:
        weights[Defense.SPY] += 10
        weights[Defense.BLITZ] += 6
        weights[Defense.PRESS] += 4
    if to_go >= 8:
        weights[Defense.COVER] += 12
        weights[Defense.PRESS] += 8
    if bool(sit.get("red_zone", false)):
        weights[Defense.PRESS] += 12
        weights[Defense.COVER] += 6
    if bool(sit.get("fourth", false)):
        weights[Defense.BLITZ] += 14
        weights[Defense.SPY] -= 6
    if bool(sit.get("sudden_death", false)):
        weights[Defense.COVER] += 10
        weights[Defense.BLITZ] -= 8
    var blitz_lean: float = float(tendency.get("blitz_lean", 0.0))
    if blitz_lean != 0.0:
        var shift: int = int(round(blitz_lean * 12.0))
        weights[Defense.BLITZ] += shift
        weights[Defense.COVER] -= shift
    return weights

static func ai_offense_card(down: int, yards_to_go: int, rng: RandomNumberGenerator, sit: Dictionary = {}, tendency: Dictionary = {}) -> int:
    return _weighted_pick(offense_weights(down, yards_to_go, sit, tendency), rng)

static func ai_defense_card(down: int, yards_to_go: int, rng: RandomNumberGenerator, sit: Dictionary = {}, tendency: Dictionary = {}) -> int:
    return _weighted_pick(defense_weights(down, yards_to_go, sit, tendency), rng)

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

# ---------------------------------------------------------------- coach personality

# A coach's leans, seeded from the empire id so nothing new needs saving:
# every session rebuilds the same personality for the same empire.
static func coach_tendency(empire_id: int) -> Dictionary:
    var n: float = float(empire_id) * 7919.0 + 13.0
    return {
        "run_lean": clampf(sin(n * 0.017), -1.0, 1.0),
        "blitz_lean": clampf(cos(n * 0.031), -1.0, 1.0),
    }

static func tendency_text(tendency: Dictionary) -> String:
    var run_lean: float = float(tendency.get("run_lean", 0.0))
    var blitz_lean: float = float(tendency.get("blitz_lean", 0.0))
    var parts: Array[String] = []
    if run_lean >= 0.35:
        parts.append("run-heavy")
    elif run_lean <= -0.35:
        parts.append("pass-happy")
    else:
        parts.append("balanced")
    if blitz_lean >= 0.35:
        parts.append("blitzes a lot")
    elif blitz_lean <= -0.35:
        parts.append("plays it safe")
    return ", ".join(parts)

# ---------------------------------------------------------------- pre-snap reads

# Tier 2: the exact card, chance ramping from Awareness 35 up to 60% at 95.
# Tier 1: a family-level read (RUN/PASS, COVERAGE/PRESSURE) at awareness/100 * 0.9.
# Tier 0: nothing.
static func read_tier(awareness: int, rng: RandomNumberGenerator) -> int:
    var tier2_chance: float = 0.0
    if awareness >= 35:
        tier2_chance = clampf(lerpf(0.05, 0.6, float(awareness - 35) / 60.0), 0.0, 0.6)
    if rng.randf() < tier2_chance:
        return 2
    var tier1_chance: float = float(awareness) / 100.0 * 0.9
    if rng.randf() < tier1_chance:
        return 1
    return 0

const SIGNAL_LINES: Array[String] = ["I've got their signal", "read their signal cold", "called their number", "picked up their tell"]

# A coordinator's read on the other side's card. With some chance (rating-
# scaled) he simply has the actual call; otherwise he scores every card by
# how often it's been called this battle plus the situational weights and
# guesses the highest scorer.
static func coordinator_read(rating: int, actual: int, seen: Array, weights: Array, names: Array, rng: RandomNumberGenerator) -> Dictionary:
    var chance: float = clampf(float(rating) / 100.0 * 0.7, 0.1, 0.7)
    if rng.randf() < chance:
        return {"expects": actual, "certain": true, "basis": SIGNAL_LINES[rng.randi_range(0, SIGNAL_LINES.size() - 1)]}
    var best_index: int = 0
    var best_score: float = -INF
    var total_seen: int = 0
    for count in seen:
        total_seen += int(count)
    for i in range(weights.size()):
        var score: float = float(weights[i]) + float(seen[i]) * 18.0 + float(rng.randi_range(0, 8))
        if score > best_score:
            best_score = score
            best_index = i
    var basis: String
    if total_seen > 0 and int(seen[best_index]) >= 2:
        basis = "they've gone %s %d of %d" % [names[best_index], int(seen[best_index]), total_seen]
    else:
        basis = "the situation says %s" % names[best_index]
    return {"expects": best_index, "certain": false, "basis": basis}
