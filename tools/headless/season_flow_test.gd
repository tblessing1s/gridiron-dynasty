extends SceneTree

# Scene-flow harness: main menu -> new season -> map -> battle -> map,
# for a few weeks, driving the real scenes through their handlers.

const BattleSettings = preload("res://scripts/core/battle_settings.gd")
const SeasonState = preload("res://scripts/core/season_state.gd")
const RaidRules = preload("res://scripts/core/raid_rules.gd")

var frames: int = 0
var weeks_wanted: int = 4
var battles_started: int = 0
var mode_arg: int = BattleSettings.Mode.WATCH
var last_scene_name: String = ""
var map_action_taken_for_week: int = -1

func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() > 0:
        mode_arg = int(args[0])
    if args.size() > 1:
        weeks_wanted = int(args[1])
    BattleSettings.mode = mode_arg
    change_scene_to_file("res://scenes/main.tscn")

func _physics_process(_delta: float) -> bool:
    frames += 1
    if frames > 60000:
        print("TIMEOUT")
        return true
    var scene: Node = current_scene
    if scene == null:
        return false
    if scene.name != last_scene_name:
        last_scene_name = scene.name
        print("[%5d] scene: %s" % [frames, scene.name])

    if scene.name == "MainMenu":
        if frames > 5:
            scene._on_new_season()
        return false

    if scene.name == "SeasonMap":
        var season = SeasonState.season
        if season == null or scene.season == null:
            return false
        if season.over:
            print("SEASON OVER at week ", season.week, " winner ", season.empire(season.winner_id)["short"])
            return true
        if season.week > weeks_wanted:
            print("DONE ", weeks_wanted, " weeks; user territories=", season.owned_by(0).size(), " eliminated=", season.user_eliminated())
            for row in season.standings():
                print("   ", row["short"], " ", row["territories"], " elim=", row["eliminated"])
            return true
        if map_action_taken_for_week == season.week:
            return false
        map_action_taken_for_week = season.week
        var targets: Array[int] = season.adjacent_enemy_territories(0)
        print("--- WEEK ", season.week, " log: ", season.log, " targets=", targets)
        if not targets.is_empty() and not season.user_eliminated():
            scene._on_tile_pressed(targets[0])
            print("    target text: ", scene.target_label.text.replace("\n", " / "))
            scene._on_attack_pressed()
        else:
            scene._on_rest_pressed()
        return false

    if scene.name == "FootballGame":
        var game = scene
        if game.matchup_screen.visible:
            battles_started += 1
            if game.franchise_tag_index < 0:
                game.matchup_screen._on_tag_pressed(2)
            print("    battle ", battles_started, ": season_mode=", game.season_mode, " attacker_team=", game.attacker_team, " vs ", game.teams[1]["short"], " tag=", game.franchise_tag_index)
            if mode_arg == BattleSettings.Mode.AUTO_RESOLVE:
                game.matchup_screen.auto_requested.emit()
            else:
                game.matchup_screen.play_requested.emit()
            return false
        if game.aftermath_screen.visible:
            print("    aftermath: user_won=", game.last_user_won, " ", game.scores, " week now ", SeasonState.season.week)
            game.aftermath_screen.raid_requested.emit()
            return false
        if game.raid_screen.visible:
            var rs = game.raid_screen
            if rs.applied:
                rs.play_again_requested.emit()
                return false
            if rs.user_is_winner:
                var take: int = 0 if rs.loser_tag != 0 else 1
                rs._on_take_pressed(take)
                for j in range(7):
                    if RaidRules.same_slot(take, j):
                        rs._on_give_pressed(j)
                        break
            print("    raid: ", rs.summary_label.text)
            rs._on_confirm_pressed()
            return false
        var state: int = game.state
        if state == game.PlayState.CALLING:
            game._on_card_selected(randi_range(0, 3) if game._user_on_offense() else randi_range(0, 2))
        elif state == game.PlayState.PRE_SNAP and game._user_throws_this_play():
            game._on_aim_started()
        elif state == game.PlayState.LIVE_POCKET and game._user_throws_this_play() and game.hold_seconds > 0.9:
            var target = game.receivers[randi_range(0, 1)]
            var direction: Vector2 = (target.global_position - game.qb.global_position).normalized()
            game._on_throw_requested(direction, 0.6)
    return false
