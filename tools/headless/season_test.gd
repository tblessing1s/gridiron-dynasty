extends SceneTree

# Logic harness: runs whole seasons with the user's battles auto-resolved
# through BattleSim, checking invariants each week.

const SeasonScript = preload("res://scripts/core/season.gd")
const BattleSim = preload("res://scripts/core/battle_sim.gd")
const Rosters = preload("res://scripts/core/rosters.gd")

var previous_resources: Dictionary = {}

func _initialize() -> void:
    var seasons: int = 5
    for s in range(seasons):
        var season = SeasonScript.new()
        previous_resources.clear()
        var weeks_played: int = 0
        while not season.over and weeks_played < 40:
            weeks_played += 1
            var targets: Array[int] = season.adjacent_enemy_territories(season.USER_EMPIRE)
            var target: int = -1
            if not season.user_eliminated() and not targets.is_empty() and randf() < 0.8:
                target = targets[randi_range(0, targets.size() - 1)]
            season.plan_week(target)
            if season.has_user_battle():
                var b: Dictionary = season.user_battle
                var attacker: Dictionary = season.empire(int(b["attacker"]))
                var defender: Dictionary = season.empire(int(b["defender"]))
                var result: Dictionary = BattleSim.resolve(attacker, defender, season.rng, season.home_crowd_at(int(b["territory"])))
                var attacker_won: bool = int(result["home_score"]) > int(result["away_score"])
                var user_is_attacker: bool = int(b["attacker"]) == season.USER_EMPIRE
                var user_won: bool = attacker_won if user_is_attacker else not attacker_won
                season.complete_user_battle(user_won)
            else:
                season.resolve_week_without_user()
            _check_invariants(season)
            if s == 0:
                print("week %d: %s" % [season.week - 1, " | ".join(PackedStringArray(season.log))])
        var table: Array = season.standings()
        print("SEASON %d over after %d weeks; winner=%s; user eliminated=%s; alive=%d; standings top=%s %d" % [s + 1, weeks_played, season.empire(season.winner_id)["short"], season.user_eliminated(), season.alive_empires().size(), table[0]["short"], table[0]["territories"]])
        assert(season.over)
    print("ALL SEASONS OK")
    quit()

func _check_invariants(season) -> void:
    var counted: int = 0
    for e in season.empires:
        var owned: Array[int] = season.owned_by(int(e["id"]))
        counted += owned.size()
        if bool(e["eliminated"]):
            assert(owned.is_empty(), "eliminated empire still owns land")
        else:
            assert(owned.size() > 0, "alive empire owns nothing")
            assert(owned.has(int(e["capital_id"])), "alive empire lost its capital without elimination")
        assert(e["players"].size() == 7, "roster size drifted")
        var players: Array = e["players"]
        for i in range(players.size()):
            var overall: int = Rosters.overall(players[i], i)
            assert(overall >= 0 and overall <= 99, "overall out of 0-99 range")
        var id: int = int(e["id"])
        var training_points: int = int(e["training_points"])
        var money: int = int(e["money"])
        assert(training_points >= 0, "training points went negative")
        assert(money >= 0, "money went negative")
        if previous_resources.has(id):
            var prior: Dictionary = previous_resources[id]
            assert(training_points >= int(prior["training_points"]), "training points decreased")
            assert(money >= int(prior["money"]), "money decreased")
        previous_resources[id] = {"training_points": training_points, "money": money}
    assert(counted == season.territories.size(), "territory count drifted")
