extends SceneTree

# Logic harness: three seasons back to back through the offseason, with the
# user's picks made like the AI's. Checks rosters, ages, rookie protection,
# potentials, and that the next season restarts everyone.

const SeasonScript = preload("res://scripts/core/season.gd")
const OffseasonScript = preload("res://scripts/core/offseason.gd")
const BattleSim = preload("res://scripts/core/battle_sim.gd")
const Rosters = preload("res://scripts/core/rosters.gd")
const RaidRules = preload("res://scripts/core/raid_rules.gd")

func _initialize() -> void:
    var season = SeasonScript.new()
    for cycle in range(3):
        _play_season(season)
        assert(season.over)
        print("SEASON %d over: winner %s, user eliminated %s, elim order %s" % [season.number, season.empire(season.winner_id)["short"], season.user_eliminated(), season.elimination_order])
        var before_ages: Array = []
        for p in season.user()["players"]:
            before_ages.append(int(p.get("age", -1)))
        var offseason = OffseasonScript.new(season)
        print("  order: ", offseason.order, " class size ", offseason.draft_class.size(), " retirements ", offseason.league_retirements)
        assert(offseason.order.size() == 12)
        assert(offseason.draft_class.size() == OffseasonScript.CLASS_SIZE)
        for i in range(offseason.order.size()):
            assert(offseason.order.count(offseason.order[i]) == 1, "duplicate in draft order")
        var reports: Array = offseason.aging[0]
        for i in range(7):
            var p: Dictionary = season.user()["players"][i]
            if not bool(reports[i]["retired"]):
                assert(int(p["age"]) == before_ages[i] + 1, "age did not advance")
            for key in Rosters.STAT_KEYS:
                assert(int(p[key]) <= int(p["potential"][key]) or int(p["age"]) > 28, "stat above potential for a young player")
        print("  user aging: ", _aging_summary(reports))
        offseason.run_ai_picks_until_user()
        assert(offseason.is_user_pick())
        var rookie: Dictionary = offseason.draft_class[0]
        var cuts: Array[int] = offseason.eligible_cuts(0, rookie)
        assert(not cuts.is_empty())
        offseason.user_pick(0, cuts[0])
        offseason.run_remaining_ai_picks()
        assert(offseason.draft_done())
        assert(offseason.picks.size() == 12)
        assert(offseason.draft_class.size() == OffseasonScript.CLASS_SIZE - 12)
        var user_pick: Dictionary = {}
        for pick in offseason.picks:
            if int(pick["empire_id"]) == 0:
                user_pick = pick
        print("  user pick #%d: %s (%s, %s) cutting %s" % [user_pick["pick"], user_pick["rookie"]["name"], user_pick["rookie"]["slot_type"], user_pick["rookie"]["grade"], user_pick["cut_name"]])

        var next = offseason.build_next_season()
        assert(next.number == season.number + 1)
        assert(not next.over and next.week == 1)
        assert(next.elimination_order.is_empty())
        for e in next.empires:
            assert(not bool(e["eliminated"]))
            assert(e["players"].size() == 7)
            assert(int(e["tag_index"]) == -1)
            assert(next.owned_by(int(e["id"])).size() == 2)
        var rookie_on_roster: bool = false
        var user_players: Array = next.user()["players"]
        for i in range(user_players.size()):
            if int(user_players[i].get("rookie_season", -1)) == next.number:
                rookie_on_roster = true
                assert(not RaidRules.can_take(next.user(), i, -1, next.number), "rookie not protected")
                assert(RaidRules.can_take(next.user(), i, -1, next.number + 1), "rookie protected too long")
        assert(rookie_on_roster, "user rookie missing")
        for p in user_players:
            assert(not p.has("morale"), "morale not cleared")
        season = next
    print("OFFSEASON OK")
    quit()

func _aging_summary(reports: Array) -> String:
    var parts: PackedStringArray = PackedStringArray()
    for r in reports:
        if bool(r["retired"]):
            parts.append("%s retired->%s" % [r["name"], r["replacement"]])
        else:
            parts.append("%s(%d)%s" % [r["name"], r["age"], str(r["changes"])])
    return " | ".join(parts)

func _play_season(season) -> void:
    var guard: int = 0
    while not season.over and guard < 40:
        guard += 1
        var targets: Array[int] = season.adjacent_enemy_territories(0)
        var target: int = -1
        if not season.user_eliminated() and not targets.is_empty() and randf() < 0.8:
            target = targets[randi_range(0, targets.size() - 1)]
        season.plan_week(target)
        if season.has_user_battle():
            var b: Dictionary = season.user_battle
            var result: Dictionary = BattleSim.resolve(season.empire(int(b["attacker"])), season.empire(int(b["defender"])), season.rng)
            var attacker_won: bool = int(result["home_score"]) > int(result["away_score"])
            var user_is_attacker: bool = int(b["attacker"]) == 0
            season.complete_user_battle(attacker_won if user_is_attacker else not attacker_won)
        else:
            season.resolve_week_without_user()
