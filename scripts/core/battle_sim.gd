extends RefCounted

const GameConstants = preload("res://scripts/core/game_constants.gd")
const PlayBook = preload("res://scripts/core/play_book.gd")
const Rosters = preload("res://scripts/core/rosters.gd")

# Auto-resolve: plays a whole Border War with the same cards, matchup table,
# and stat edges as the live battle, without animating anything. Also the
# call sheet's math: expected yards, card suggestions, and the stat-matchup
# strings shown on every card and in the result line.

const MAX_POSSESSIONS: int = 20
# Stadium/Capital home crowd: the attacker (home, here) throws worse on the road.
const HOME_CROWD_COMPLETION_FACTOR: float = 0.85

# Empires carry a coach personality (PlayBook.coach_tendency); the hand-made
# quick-battle rosters have no empire id and call evenly.
static func team_tendency(team: Dictionary) -> Dictionary:
    if not team.has("id"):
        return {}
    return PlayBook.coach_tendency(int(team["id"]))

# home is always the attacker, away the defender; home_crowd is true when the
# territory being fought over is a Stadium or Capital (season.home_crowd_at).
static func resolve(home: Dictionary, away: Dictionary, rng: RandomNumberGenerator, home_crowd: bool = false) -> Dictionary:
    var teams: Array = [home, away]
    var tendencies: Array = [team_tendency(home), team_tendency(away)]
    var scores: Array[int] = [0, 0]
    var log: Array[String] = []
    var offense: int = 0
    var possession: int = 1
    var start_yard: int = GameConstants.MIDFIELD_YARD
    var total: int = GameConstants.POSSESSIONS_PER_TEAM * 2

    while true:
        var sudden_death: bool = possession > total
        var score_diff: int = scores[offense] - scores[1 - offense]
        var last_possession: bool = possession == total and score_diff < 0
        var outcome: Dictionary = _resolve_possession(teams[offense], teams[1 - offense], start_yard, rng, home_crowd and offense == 0, tendencies[offense], tendencies[1 - offense], score_diff, sudden_death, last_possession)
        if outcome["touchdown"]:
            scores[offense] += 7
            start_yard = GameConstants.MIDFIELD_YARD
        else:
            start_yard = clampi(GameConstants.FIELD_YARDS - int(outcome["end_yard"]), 1, GameConstants.FIELD_YARDS - 1)
        var prefix: String = "Poss %d" % possession
        if possession > total:
            prefix = "Sudden death %d" % (possession - total)
        log.append("%s · %s: %s" % [prefix, teams[offense]["short"], outcome["summary"]])

        var completed: int = possession
        possession += 1
        if completed >= total and completed % 2 == 0 and scores[0] != scores[1]:
            break
        if completed >= MAX_POSSESSIONS:
            var coin: int = rng.randi_range(0, 1)
            scores[coin] += 7
            log.append("Marathon tie broken: %s score in overtime" % teams[coin]["short"])
            break
        offense = 1 - offense

    return {"home_score": scores[0], "away_score": scores[1], "log": log}

# Resolves one offensive play in isolation, for the SIM battle mode: the
# player (or AI) has already called both cards; this is the same card/stat
# math the auto-resolver uses, without the real-time snap/pocket/throw
# sequence.
static func resolve_single_play(offense: Dictionary, defense: Dictionary, offense_card: int, defense_card: int, attacker_penalty: bool, rng: RandomNumberGenerator) -> Dictionary:
    return _resolve_play(offense, defense, offense_card, defense_card, rng, attacker_penalty)

static func _resolve_possession(offense: Dictionary, defense: Dictionary, start_yard: int, rng: RandomNumberGenerator, attacker_penalty: bool, offense_tendency: Dictionary, defense_tendency: Dictionary, score_diff: int, sudden_death: bool, last_possession: bool) -> Dictionary:
    var yard: int = start_yard
    var down: int = 1
    var yards_to_go: int = GameConstants.FIRST_DOWN_YARDS
    var plays: int = 0
    while plays < 100:
        plays += 1
        var sit: Dictionary = PlayBook.situation(down, yards_to_go, yard, GameConstants.FIELD_YARDS, score_diff, sudden_death, last_possession)
        var offense_card: int = PlayBook.ai_offense_card(down, yards_to_go, rng, sit, offense_tendency)
        var defense_card: int = PlayBook.ai_defense_card(down, yards_to_go, rng, sit, defense_tendency)
        var play: Dictionary = _resolve_play(offense, defense, offense_card, defense_card, rng, attacker_penalty)
        if play["turnover"]:
            # An interception is picked off air_yards downfield, not back at
            # the snap — match football_game._resolve_sim_play's spot.
            var pick_yard: int = clampi(yard + int(play.get("air_yards", 0)), 1, GameConstants.FIELD_YARDS - 1)
            return {"touchdown": false, "end_yard": pick_yard, "summary": "%s at the %d (%d plays)" % [play["result"], pick_yard, plays]}
        var yards: int = int(play["yards"])
        yard += yards
        if yard >= GameConstants.FIELD_YARDS:
            return {"touchdown": true, "end_yard": GameConstants.FIELD_YARDS, "summary": "TOUCHDOWN in %d plays" % plays}
        yard = maxi(yard, 1)
        if yards >= yards_to_go:
            down = 1
            yards_to_go = mini(GameConstants.FIRST_DOWN_YARDS, GameConstants.FIELD_YARDS - yard)
        else:
            down += 1
            yards_to_go = maxi(yards_to_go - yards, 1)
        if down > 4:
            return {"touchdown": false, "end_yard": yard, "summary": "turnover on downs at the %d (%d plays)" % [yard, plays]}
    return {"touchdown": false, "end_yard": yard, "summary": "stalled at the %d" % yard}

static func _resolve_play(offense: Dictionary, defense: Dictionary, offense_card: int, defense_card: int, rng: RandomNumberGenerator, attacker_penalty: bool) -> Dictionary:
    var multiplier: float = PlayBook.matchup_multiplier(offense_card, defense_card)
    var op: Array = offense["players"]
    var dp: Array = defense["players"]
    var block_power: float = Rosters.line_power(op)
    var rush_power: float = Rosters.line_power(dp)
    var header: String = "%s vs %s (%s ×%.2f)" % [PlayBook.OFFENSE_NAMES[offense_card], PlayBook.DEFENSE_NAMES[defense_card], PlayBook.matchup_label(offense_card, defense_card), multiplier]
    var pocket_seconds: float = _pocket_seconds(block_power, rush_power)

    if PlayBook.OFFENSE_IS_RUN[offense_card]:
        if offense_card == PlayBook.Offense.SWEEP:
            return _resolve_sweep(op, dp, multiplier, header, rng, offense_card, defense_card, pocket_seconds)
        var run_edge: float = (float(_stat(op[1], "speed") + _stat(op[1], "power") - _stat(dp[1], "speed") - _stat(dp[1], "power")) + block_power - rush_power) / 300.0
        var run_factor: float = 1.0 + run_edge
        var mean: float = 5.0 if offense_card == PlayBook.Offense.DRAW else 6.0
        var deviation: float = 3.0 if offense_card == PlayBook.Offense.DRAW else 4.0
        var run_yards: int = int(round(rng.randfn(mean, deviation) * multiplier * run_factor))
        var yards: int = maxi(run_yards, -3)
        var detail: String = "%s • %s SPD/PWR %d/%d vs %s LB %d/%d • LINE %d vs %d • edge %+d%%" % [header, str(op[1]["name"]), _stat(op[1], "speed"), _stat(op[1], "power"), str(dp[1]["name"]), _stat(dp[1], "speed"), _stat(dp[1], "power"), int(round(block_power)), int(round(rush_power)), int(round(run_edge * 100.0))]
        var extra: Dictionary = {"ball_carrier": 1, "tackler": 1, "hole": "inside"}
        if offense_card == PlayBook.Offense.SCREEN:
            extra["target"] = 1
            extra["air_yards"] = clampi(2, 0, maxi(yards, 0))
            extra["run_after"] = yards - int(extra["air_yards"])
            extra["hole"] = "outside"
        else:
            extra["run_after"] = yards
        return _finish({"yards": yards, "result": "RUN", "turnover": false, "detail": detail}, offense_card, defense_card, pocket_seconds, extra)

    var sack_chance: float = clampf(0.08 + (rush_power - block_power) * 0.004, 0.02, 0.35)
    if defense_card == PlayBook.Defense.BLITZ:
        sack_chance *= 1.5
    if offense_card == PlayBook.Offense.PLAY_ACTION:
        sack_chance *= 1.35
    sack_chance = clampf(sack_chance, 0.02, 0.6)
    if rng.randf() < sack_chance:
        var sack_detail: String = "%s • SACKED • pocket %d vs rush %d • %d%% sack chance" % [header, int(round(block_power)), int(round(rush_power)), int(round(sack_chance * 100.0))]
        var tackler: int = Rosters.LINE_START + rng.randi_range(0, Rosters.LINE_SIZE - 1)
        var sack_extra: Dictionary = {"ball_carrier": 0, "tackler": tackler, "sack_chance": sack_chance}
        return _finish({"yards": -rng.randi_range(4, 8), "result": "SACK", "turnover": false, "detail": sack_detail}, offense_card, defense_card, minf(pocket_seconds, 1.2), sack_extra)

    var target: int = 3 if rng.randf() < 0.5 else 2
    var pass_edge: float = float(_stat(op[0], "skill") + _stat(op[2], "speed") + _stat(op[3], "speed") - _stat(dp[2], "speed") - _stat(dp[3], "speed") - _stat(dp[0], "awareness")) / 300.0
    var pass_factor: float = 1.0 + pass_edge
    var completion: float = 0.68
    var mean_yards: float = 7.0
    var deviation_yards: float = 4.0
    var interception_chance: float = 0.03
    var air_ratio: float = 0.4
    if offense_card == PlayBook.Offense.DEEP_SHOT:
        completion = 0.42
        mean_yards = 18.0
        deviation_yards = 7.0
        interception_chance = 0.07
        air_ratio = 0.85
    elif offense_card == PlayBook.Offense.PLAY_ACTION:
        completion = 0.56
        mean_yards = 11.0
        deviation_yards = 5.0
        interception_chance = 0.05
        air_ratio = 0.6
    completion = clampf(completion * (0.75 + 0.25 * multiplier) * pass_factor, 0.1, 0.92)
    if attacker_penalty:
        completion *= HOME_CROWD_COMPLETION_FACTOR
    if defense_card == PlayBook.Defense.PRESS:
        completion *= 0.9
        deviation_yards *= 1.25
    var complete_detail: String = "%s • %s SKL %d • WRs SPD %d/%d vs CBs %d/%d, %s AWR %d • %d%% to complete" % [header, str(op[0]["name"]), _stat(op[0], "skill"), _stat(op[2], "speed"), _stat(op[3], "speed"), _stat(dp[2], "speed"), _stat(dp[3], "speed"), str(dp[0]["name"]), _stat(dp[0], "awareness"), int(round(completion * 100.0))]
    var pass_extra: Dictionary = {"target": target, "tackler": target, "completion_chance": completion, "sack_chance": sack_chance, "pick_chance": interception_chance}
    if rng.randf() < completion:
        var pass_yards: int = maxi(int(round(rng.randfn(mean_yards, deviation_yards) * multiplier * pass_factor)), 1)
        var air_yards: int = clampi(int(round(float(pass_yards) * air_ratio)), 1, pass_yards)
        pass_extra["ball_carrier"] = target
        pass_extra["air_yards"] = air_yards
        pass_extra["run_after"] = pass_yards - air_yards
        return _finish({"yards": pass_yards, "result": "PASS", "turnover": false, "detail": complete_detail}, offense_card, defense_card, pocket_seconds, pass_extra)
    if multiplier < 1.0:
        interception_chance *= 2.0
        pass_extra["pick_chance"] = interception_chance
    if rng.randf() < interception_chance:
        var pick_detail: String = "%s • INTERCEPTED • %s reads it • %d%% pick chance" % [header, str(dp[0]["name"]), int(round(interception_chance * 100.0))]
        pass_extra["ball_carrier"] = -1
        pass_extra["tackler"] = -1
        pass_extra["interceptor"] = 0
        pass_extra["air_yards"] = clampi(int(round(mean_yards * 0.8)), 1, 40)
        return _finish({"yards": 0, "result": "INTERCEPTED", "turnover": true, "detail": pick_detail}, offense_card, defense_card, pocket_seconds, pass_extra)
    pass_extra["ball_carrier"] = -1
    pass_extra["air_yards"] = clampi(int(round(mean_yards * 0.8)), 1, 40)
    pass_extra["run_after"] = 0
    return _finish({"yards": 0, "result": "INCOMPLETE", "turnover": false, "detail": complete_detail}, offense_card, defense_card, pocket_seconds, pass_extra)

static func _resolve_sweep(op: Array, dp: Array, multiplier: float, header: String, rng: RandomNumberGenerator, offense_card: int, defense_card: int, pocket_seconds: float) -> Dictionary:
    var block_power: float = Rosters.line_power(op)
    var rush_power: float = Rosters.line_power(dp)
    var edge_speed: float = _edge_speed(dp)
    var run_edge: float = (float(_stat(op[1], "speed")) * 1.5 - edge_speed * 1.5 + (block_power - rush_power) * 0.5) / 300.0
    var run_factor: float = 1.0 + run_edge
    var run_yards: int = int(round(rng.randfn(6.0, 6.0) * multiplier * run_factor))
    var yards: int = maxi(run_yards, -6)
    var detail: String = "%s • %s SPD %d vs edge %d • edge %+d%%" % [header, str(op[1]["name"]), _stat(op[1], "speed"), int(round(edge_speed)), int(round(run_edge * 100.0))]
    var extra: Dictionary = {"ball_carrier": 1, "tackler": 1, "hole": "outside", "run_after": yards}
    return _finish({"yards": yards, "result": "RUN", "turnover": false, "detail": detail}, offense_card, defense_card, pocket_seconds, extra)

# Merges a resolved play's core outcome (yards/result/turnover/detail) with
# the structural fields the SIM replay (scripts/ui/play_replay.gd) and the
# aftermath's XP report both read from, so all three agree with one source.
static func _finish(base: Dictionary, offense_card: int, defense_card: int, pocket_seconds: float, extra: Dictionary) -> Dictionary:
    var result: Dictionary = {
        "offense_card": offense_card,
        "defense_card": defense_card,
        "ball_carrier": -1,
        "target": -1,
        "tackler": -1,
        "interceptor": -1,
        "air_yards": 0,
        "run_after": 0,
        "hole": "",
        "pocket_seconds": pocket_seconds,
        "completion_chance": 0.0,
        "sack_chance": 0.0,
        "pick_chance": 0.0,
    }
    for key in base.keys():
        result[key] = base[key]
    for key in extra.keys():
        result[key] = extra[key]
    return result

static func _edge_speed(dp: Array) -> float:
    return (float(_stat(dp[1], "speed")) + float(_stat(dp[2], "speed")) + float(_stat(dp[3], "speed"))) / 3.0

static func _stat(player: Dictionary, key: String) -> int:
    return int(player.get(key, 50))

# How long the SIM replay (scripts/ui/play_replay.gd) shows the pocket
# holding before the ball comes out or the rush gets home — a narrower,
# replay-scaled range than the real-time engine's Rosters.pocket_seconds.
static func _pocket_seconds(block_power: float, rush_power: float) -> float:
    return clampf(1.4 + (block_power - rush_power) * 0.02, 0.6, 2.2)

# ---------------------------------------------------------------- the call sheet

# One short "why" string per card, naming the stats that decide it, plus a
# float edge (positive favors the side named). Powers the stat hint (and the
# ★ on the coordinator's suggestion) shown on every card face.
static func card_edges(offense: Dictionary, defense: Dictionary) -> Dictionary:
    var op: Array = offense["players"]
    var dp: Array = defense["players"]
    var block_power: float = Rosters.line_power(op)
    var rush_power: float = Rosters.line_power(dp)
    var edge_speed: float = _edge_speed(dp)

    var offense_hints: Array[String] = [
        "QB%d WR%d v CB%d" % [_stat(op[0], "skill"), _stat(op[2], "speed"), _stat(dp[2], "speed")],
        "QB%d WR%d v CB%d" % [_stat(op[0], "skill"), _stat(op[3], "speed"), _stat(dp[3], "speed")],
        "RB%d/%d v LB%d/%d" % [_stat(op[1], "speed"), _stat(op[1], "power"), _stat(dp[1], "speed"), _stat(dp[1], "power")],
        "RB%d/%d v LB%d/%d" % [_stat(op[1], "speed"), _stat(op[1], "power"), _stat(dp[1], "speed"), _stat(dp[1], "power")],
        "RB%d v edge%d" % [_stat(op[1], "speed"), int(round(edge_speed))],
        "QB%d v %s AWR%d" % [_stat(op[0], "skill"), str(dp[0]["name"]), _stat(dp[0], "awareness")],
    ]
    var offense_edges: Array[float] = [
        float(_stat(op[0], "skill") + _stat(op[2], "speed") - _stat(dp[2], "speed")) / 100.0,
        float(_stat(op[0], "skill") + _stat(op[3], "speed") - _stat(dp[3], "speed")) / 100.0,
        float(_stat(op[1], "speed") + _stat(op[1], "power") - _stat(dp[1], "speed") - _stat(dp[1], "power")) / 100.0 + (block_power - rush_power) / 100.0,
        float(_stat(op[1], "speed") + _stat(op[1], "power") - _stat(dp[1], "speed") - _stat(dp[1], "power")) / 100.0 + (block_power - rush_power) / 100.0,
        (float(_stat(op[1], "speed")) - edge_speed) / 100.0,
        float(_stat(op[0], "skill") - _stat(dp[0], "awareness")) / 100.0,
    ]

    var defense_hints: Array[String] = [
        "WR%d/%d v CB%d/%d" % [_stat(op[2], "speed"), _stat(op[3], "speed"), _stat(dp[2], "speed"), _stat(dp[3], "speed")],
        "RUSH%d v LINE%d" % [int(round(rush_power)), int(round(block_power))],
        "%s AWR%d v QB%d" % [str(dp[0]["name"]), _stat(dp[0], "awareness"), _stat(op[0], "skill")],
        "CB%d/%d v WR%d/%d" % [_stat(dp[2], "skill"), _stat(dp[3], "skill"), _stat(op[2], "speed"), _stat(op[3], "speed")],
    ]
    var defense_edges: Array[float] = [
        float(_stat(dp[2], "speed") + _stat(dp[3], "speed") - _stat(op[2], "speed") - _stat(op[3], "speed")) / 100.0,
        (rush_power - block_power) / 100.0,
        float(_stat(dp[0], "awareness") - _stat(op[0], "skill")) / 100.0,
        float(_stat(dp[2], "skill") + _stat(dp[3], "skill") - _stat(op[2], "speed") - _stat(op[3], "speed")) / 100.0,
    ]

    return {"offense_hints": offense_hints, "defense_hints": defense_hints, "offense_edges": offense_edges, "defense_edges": defense_edges}

# The resolver's math without dice: a pick charged at -15, a sack at -6.
static func expected_yards(offense: Dictionary, defense: Dictionary, offense_card: int, defense_card: int) -> float:
    var multiplier: float = PlayBook.matchup_multiplier(offense_card, defense_card)
    var op: Array = offense["players"]
    var dp: Array = defense["players"]
    var block_power: float = Rosters.line_power(op)
    var rush_power: float = Rosters.line_power(dp)

    if PlayBook.OFFENSE_IS_RUN[offense_card]:
        if offense_card == PlayBook.Offense.SWEEP:
            var edge_speed: float = _edge_speed(dp)
            var sweep_edge: float = (float(_stat(op[1], "speed")) * 1.5 - edge_speed * 1.5 + (block_power - rush_power) * 0.5) / 300.0
            return 6.0 * multiplier * (1.0 + sweep_edge)
        var run_edge: float = (float(_stat(op[1], "speed") + _stat(op[1], "power") - _stat(dp[1], "speed") - _stat(dp[1], "power")) + block_power - rush_power) / 300.0
        var mean: float = 5.0 if offense_card == PlayBook.Offense.DRAW else 6.0
        return mean * multiplier * (1.0 + run_edge)

    var sack_chance: float = clampf(0.08 + (rush_power - block_power) * 0.004, 0.02, 0.35)
    if defense_card == PlayBook.Defense.BLITZ:
        sack_chance *= 1.5
    if offense_card == PlayBook.Offense.PLAY_ACTION:
        sack_chance *= 1.35
    sack_chance = clampf(sack_chance, 0.02, 0.6)

    var pass_edge: float = float(_stat(op[0], "skill") + _stat(op[2], "speed") + _stat(op[3], "speed") - _stat(dp[2], "speed") - _stat(dp[3], "speed") - _stat(dp[0], "awareness")) / 300.0
    var pass_factor: float = 1.0 + pass_edge
    var completion: float = 0.68
    var mean_yards: float = 7.0
    var interception_chance: float = 0.03
    if offense_card == PlayBook.Offense.DEEP_SHOT:
        completion = 0.42
        mean_yards = 18.0
        interception_chance = 0.07
    elif offense_card == PlayBook.Offense.PLAY_ACTION:
        completion = 0.56
        mean_yards = 11.0
        interception_chance = 0.05
    completion = clampf(completion * (0.75 + 0.25 * multiplier) * pass_factor, 0.1, 0.92)
    if defense_card == PlayBook.Defense.PRESS:
        completion *= 0.9
    if multiplier < 1.0:
        interception_chance *= 2.0

    var complete_value: float = mean_yards * multiplier * pass_factor
    var incomplete_value: float = interception_chance * -15.0
    return sack_chance * -6.0 + (1.0 - sack_chance) * (completion * complete_value + (1.0 - completion) * incomplete_value)

static func suggest_offense(offense: Dictionary, defense: Dictionary, expected_defense_card: int, sit: Dictionary) -> int:
    var best_card: int = PlayBook.Offense.SLANTS
    var best_value: float = -INF
    for card in range(PlayBook.OFFENSE_NAMES.size()):
        var value: float = expected_yards(offense, defense, card, expected_defense_card)
        if card == PlayBook.Offense.DEEP_SHOT and bool(sit.get("red_zone", false)):
            value *= 0.5
        if bool(sit.get("short", false)) and PlayBook.OFFENSE_FAMILY[card] == PlayBook.Family.PASS:
            value *= 0.85
        if value > best_value:
            best_value = value
            best_card = card
    return best_card

static func suggest_defense(offense: Dictionary, defense: Dictionary, expected_offense_card: int, sit: Dictionary) -> int:
    var best_card: int = PlayBook.Defense.COVER
    var best_value: float = INF
    for card in range(PlayBook.DEFENSE_NAMES.size()):
        var value: float = expected_yards(offense, defense, expected_offense_card, card)
        if value < best_value:
            best_value = value
            best_card = card
    return best_card
