extends SceneTree

# Save/load harness: round-trips the dynasty at several points and checks
# the restored state is identical and still playable.

const SeasonScript = preload("res://scripts/core/season.gd")
const OffseasonScript = preload("res://scripts/core/offseason.gd")
const SeasonState = preload("res://scripts/core/season_state.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")
const BattleSim = preload("res://scripts/core/battle_sim.gd")
const BattleSettings = preload("res://scripts/core/battle_settings.gd")

func _initialize() -> void:
    SaveGame.delete()
    assert(not SaveGame.exists())
    assert(not SaveGame.load_dynasty(), "load without a file should fail")

    var season = SeasonScript.new()
    SeasonState.season = season
    SeasonState.battle = {}
    SeasonState.offseason = null
    BattleSettings.mode = BattleSettings.Mode.WATCH
    _play_weeks(season, 3)

    # 1. Mid-season with a pending user battle.
    var targets: Array[int] = season.adjacent_enemy_territories(0)
    season.plan_week(targets[0])
    assert(season.has_user_battle())
    SeasonState.battle = season.user_battle.duplicate()
    var before: Dictionary = season.to_dict()
    var before_battle: Dictionary = SeasonState.battle.duplicate()
    assert(SaveGame.save())
    print("saved mid-season: ", SaveGame.summary(), " (", FileAccess.open(SaveGame.SAVE_PATH, FileAccess.READ).get_length(), " bytes)")
    BattleSettings.mode = BattleSettings.Mode.PLAY
    SeasonState.clear()
    assert(SaveGame.load_dynasty())
    assert(BattleSettings.mode == BattleSettings.Mode.WATCH, "mode not restored")
    var loaded = SeasonState.season
    assert(loaded.to_dict() == before, "season changed across save/load")
    assert(SeasonState.battle == before_battle, "pending battle changed across save/load")
    assert(SeasonState.offseason == null)
    assert(loaded.empire(0)["color"] is Color)
    assert(loaded.territory(0)["adjacency"] is Array)
    assert(typeof(loaded.user()["players"][0]["speed"]) == TYPE_INT)
    print("mid-season round trip identical; user players sample: ", loaded.user()["players"][0])

    # Keep playing on the loaded season: finish the pending battle and the season.
    var b: Dictionary = SeasonState.battle
    var result: Dictionary = BattleSim.resolve(loaded.empire(int(b["attacker"])), loaded.empire(int(b["defender"])), loaded.rng)
    loaded.complete_user_battle(int(result["home_score"]) > int(result["away_score"]))
    SeasonState.battle = {}
    _play_weeks(loaded, 40)
    assert(loaded.over)
    print("loaded season finished: winner ", loaded.empire(loaded.winner_id)["short"])

    # 2. Mid-draft, on the user's pick.
    var offseason = OffseasonScript.new(loaded)
    offseason.run_ai_picks_until_user()
    SeasonState.offseason = offseason
    var before_off: Dictionary = offseason.to_dict()
    var before_season: Dictionary = loaded.to_dict()
    assert(SaveGame.save())
    print("saved mid-draft: ", SaveGame.summary(), " cursor=", offseason.pick_cursor)
    SeasonState.clear()
    assert(SaveGame.load_dynasty())
    var loaded_off = SeasonState.offseason
    assert(loaded_off != null)
    assert(loaded_off.previous == SeasonState.season)
    assert(loaded_off.to_dict() == before_off, "offseason changed across save/load")
    assert(SeasonState.season.to_dict() == before_season, "season changed across offseason save/load")
    assert(loaded_off.is_user_pick())
    assert(typeof(loaded_off.aging.keys()[0]) == TYPE_INT)
    var cuts: Array[int] = loaded_off.eligible_cuts(0, loaded_off.draft_class[0])
    loaded_off.user_pick(0, cuts[0])
    loaded_off.run_remaining_ai_picks()
    assert(loaded_off.draft_done())
    var next = loaded_off.build_next_season()
    SeasonState.season = next
    SeasonState.offseason = null
    assert(SaveGame.save())
    print("saved new season: ", SaveGame.summary())

    # 3. Fresh season 2 round trip and play on.
    var before_next: Dictionary = next.to_dict()
    SeasonState.clear()
    assert(SaveGame.load_dynasty())
    assert(SeasonState.season.to_dict() == before_next)
    assert(SeasonState.season.number == 2)
    _play_weeks(SeasonState.season, 2)
    print("season 2 playable after load: week ", SeasonState.season.week)

    # 4. Corrupt file is ignored.
    var file: FileAccess = FileAccess.open(SaveGame.SAVE_PATH, FileAccess.WRITE)
    file.store_string("{ not json")
    file.close()
    SeasonState.clear()
    assert(not SaveGame.load_dynasty())
    SaveGame.delete()
    assert(not SaveGame.exists())
    print("SAVE/LOAD OK")
    quit()

func _play_weeks(season, count: int) -> void:
    var played: int = 0
    while not season.over and played < count:
        played += 1
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
