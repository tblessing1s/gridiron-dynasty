extends RefCounted

const GameConstants = preload("res://scripts/core/game_constants.gd")
const PlayBook = preload("res://scripts/core/play_book.gd")
const Rosters = preload("res://scripts/core/rosters.gd")

# Auto-resolve: plays a whole Border War with the same cards, matchup table,
# and stat edges as the live battle, without animating anything.

const MAX_POSSESSIONS: int = 20
# Stadium/Capital home crowd: the attacker (home, here) throws worse on the road.
const HOME_CROWD_COMPLETION_FACTOR: float = 0.85

# home is always the attacker, away the defender; home_crowd is true when the
# territory being fought over is a Stadium or Capital (season.home_crowd_at).
static func resolve(home: Dictionary, away: Dictionary, rng: RandomNumberGenerator, home_crowd: bool = false) -> Dictionary:
    var teams: Array = [home, away]
    var scores: Array[int] = [0, 0]
    var log: Array[String] = []
    var offense: int = 0
    var possession: int = 1
    var start_yard: int = GameConstants.MIDFIELD_YARD
    var total: int = GameConstants.POSSESSIONS_PER_TEAM * 2

    while true:
        var outcome: Dictionary = _resolve_possession(teams[offense], teams[1 - offense], start_yard, rng, home_crowd and offense == 0)
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

static func _resolve_possession(offense: Dictionary, defense: Dictionary, start_yard: int, rng: RandomNumberGenerator, attacker_penalty: bool) -> Dictionary:
    var yard: int = start_yard
    var down: int = 1
    var yards_to_go: int = GameConstants.FIRST_DOWN_YARDS
    var plays: int = 0
    while plays < 100:
        plays += 1
        var offense_card: int = PlayBook.ai_offense_card(down, yards_to_go, rng)
        var defense_card: int = PlayBook.ai_defense_card(down, yards_to_go, rng)
        var play: Dictionary = _resolve_play(offense, defense, offense_card, defense_card, rng, attacker_penalty)
        if play["turnover"]:
            return {"touchdown": false, "end_yard": yard, "summary": "%s at the %d (%d plays)" % [play["result"], yard, plays]}
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

    if PlayBook.OFFENSE_IS_RUN[offense_card]:
        var run_edge: float = (float(_stat(op[1], "speed") + _stat(op[1], "power") - _stat(dp[1], "speed") - _stat(dp[1], "power")) + block_power - rush_power) / 300.0
        var run_factor: float = 1.0 + run_edge
        var mean: float = 5.0 if offense_card == PlayBook.Offense.DRAW else 6.0
        var deviation: float = 3.0 if offense_card == PlayBook.Offense.DRAW else 4.0
        var run_yards: int = int(round(rng.randfn(mean, deviation) * multiplier * run_factor))
        return {"yards": maxi(run_yards, -3), "result": "RUN", "turnover": false}

    var sack_chance: float = clampf(0.08 + (rush_power - block_power) * 0.004, 0.02, 0.35)
    if defense_card == PlayBook.Defense.BLITZ:
        sack_chance *= 1.5
    if rng.randf() < sack_chance:
        return {"yards": -rng.randi_range(4, 8), "result": "SACK", "turnover": false}

    var pass_edge: float = float(_stat(op[0], "skill") + _stat(op[2], "speed") + _stat(op[3], "speed") - _stat(dp[2], "speed") - _stat(dp[3], "speed") - _stat(dp[0], "awareness")) / 300.0
    var pass_factor: float = 1.0 + pass_edge
    var completion: float = 0.68
    var mean_yards: float = 7.0
    var deviation_yards: float = 4.0
    var interception_chance: float = 0.03
    if offense_card == PlayBook.Offense.DEEP_SHOT:
        completion = 0.42
        mean_yards = 18.0
        deviation_yards = 7.0
        interception_chance = 0.07
    completion = clampf(completion * (0.75 + 0.25 * multiplier) * pass_factor, 0.1, 0.92)
    if attacker_penalty:
        completion *= HOME_CROWD_COMPLETION_FACTOR
    if rng.randf() < completion:
        var pass_yards: int = maxi(int(round(rng.randfn(mean_yards, deviation_yards) * multiplier * pass_factor)), 1)
        return {"yards": pass_yards, "result": "PASS", "turnover": false}
    if multiplier < 1.0:
        interception_chance *= 2.0
    if rng.randf() < interception_chance:
        return {"yards": 0, "result": "INTERCEPTED", "turnover": true}
    return {"yards": 0, "result": "INCOMPLETE", "turnover": false}

static func _stat(player: Dictionary, key: String) -> int:
    return int(player.get(key, 50))
