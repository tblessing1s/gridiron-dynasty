extends SceneTree

# Scene-flow harness: a finished season -> map summary -> offseason scene
# (aging, draft with a user pick, new map) -> map of season 2.

const BattleSettings = preload("res://scripts/core/battle_settings.gd")
const SeasonState = preload("res://scripts/core/season_state.gd")
const SeasonScript = preload("res://scripts/core/season.gd")
const BattleSim = preload("res://scripts/core/battle_sim.gd")

var frames: int = 0
var last_scene: String = ""
var did_offseason_click: bool = false
var draft_clicked: bool = false

func _initialize() -> void:
    BattleSettings.mode = BattleSettings.Mode.AUTO_RESOLVE
    var season = SeasonScript.new()
    var guard: int = 0
    while not season.over and guard < 40:
        guard += 1
        season.plan_week(-1)
        if season.has_user_battle():
            var b: Dictionary = season.user_battle
            var result: Dictionary = BattleSim.resolve(season.empire(int(b["attacker"])), season.empire(int(b["defender"])), season.rng, season.home_crowd_at(int(b["territory"])))
            season.complete_user_battle(int(result["home_score"]) < int(result["away_score"]))
        else:
            season.resolve_week_without_user()
    SeasonState.season = season
    SeasonState.battle = {}
    print("prepared finished season: winner ", season.empire(season.winner_id)["short"])
    change_scene_to_file("res://scenes/main.tscn")

func _physics_process(_delta: float) -> bool:
    frames += 1
    if frames > 3000:
        print("TIMEOUT in scene ", last_scene)
        return true
    var scene: Node = current_scene
    if scene == null:
        return false
    if scene.name != last_scene:
        last_scene = scene.name
        print("[%4d] scene: %s" % [frames, scene.name])

    if scene.name == "MainMenu":
        if frames > 5:
            print("   menu offers continue offseason: ", SeasonState.season.over)
            scene._on_continue_offseason()
        return false

    if scene.name == "Offseason":
        var off = scene.offseason
        if scene.step == scene.Step.AGING:
            print("   aging page shown; league retirements=", off.league_retirements)
            scene.step = scene.Step.DRAFT
            off.run_ai_picks_until_user()
            scene._show_step()
            return false
        if scene.step == scene.Step.DRAFT:
            if off.draft_done():
                print("   draft done: ", off.picks.size(), " picks")
                scene.step = scene.Step.DONE
                scene._show_step()
                return false
            if not draft_clicked:
                draft_clicked = true
                print("   on the clock at pick ", off.pick_cursor + 1, "; class top: ", off.draft_class[0]["name"], " ", off.draft_class[0]["slot_type"], " ", off.draft_class[0]["grade"])
                scene._on_rookie_pressed(0)
                var cuts: Array[int] = off.eligible_cuts(0, off.draft_class[0])
                scene._on_cut_pressed(cuts[0], 1)
                print("   summary: ", scene.summary_label.text, " confirm disabled=", scene.confirm_button.disabled)
                scene._on_confirm_pick()
            return false
        if scene.step == scene.Step.DONE:
            print("   done page; starting season ", off.next_number)
            scene._on_start_season()
            return false

    if scene.name == "SeasonMap":
        var season = SeasonState.season
        if season == null or scene.season == null:
            return false
        print("   map: season ", season.number, " week ", season.week, " over=", season.over, " user territories=", season.owned_by(0).size(), " label='", scene.week_label.text, "'")
        var rookies: int = 0
        for p in season.user()["players"]:
            if int(p.get("rookie_season", -1)) == season.number:
                rookies += 1
        print("   user rookies protected this season: ", rookies)
        scene._show_roster()
        print("   roster overlay visible: ", scene.roster_panel.visible)
        return true
    return false
