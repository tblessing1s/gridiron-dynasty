extends SceneTree

# Headless harness: plays N battles back to back through matchup, battle,
# aftermath, and raid, calling the same handlers the UI would.

const BattleSettings = preload("res://scripts/core/battle_settings.gd")
const RaidRules = preload("res://scripts/core/raid_rules.gd")

var game
var frames: int = 0
var max_frames: int = 40000
var throws: int = 0
var cards: int = 0
var battles_wanted: int = 2
var battles_done: int = 0
var mode_arg: int = BattleSettings.Mode.PLAY
var last_msg: String = ""
var raid_confirmed_this_battle: bool = false

func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() > 0:
        mode_arg = int(args[0])
    if args.size() > 1:
        battles_wanted = int(args[1])
    BattleSettings.mode = mode_arg
    var scene: PackedScene = load("res://scenes/game.tscn")
    game = scene.instantiate()
    root.add_child(game)
    print("MODE ", BattleSettings.mode_name(mode_arg))

func _roster_line(team: Dictionary) -> String:
    var parts: PackedStringArray = PackedStringArray()
    for p in team["players"]:
        parts.append("%s(%d/%d/%d/%d)" % [p["name"], p["speed"], p["power"], p["skill"], p["awareness"]])
    return " ".join(parts)

func _physics_process(_delta: float) -> bool:
    frames += 1
    if game == null:
        return true

    if game.matchup_screen.visible:
        if battles_done >= battles_wanted:
            print("DONE after ", battles_done, " battles")
            print("HAWKS: ", _roster_line(game.teams[0]))
            print("FORGE: ", _roster_line(game.teams[1]))
            return true
        print("--- MATCHUP (battle ", battles_done + 1, ") ai_tag=", game.ai_tag_index, " tagging Reyes")
        game.matchup_screen._on_tag_pressed(2)
        raid_confirmed_this_battle = false
        if mode_arg == BattleSettings.Mode.AUTO_RESOLVE:
            game.matchup_screen.auto_requested.emit()
        else:
            game.matchup_screen.play_requested.emit()
        return false

    if game.aftermath_screen.visible:
        print("--- AFTERMATH user_won=", game.last_user_won, " score=", game.scores)
        for team_index in range(2):
            for i in range(7):
                var s: Dictionary = game.battle_stats[team_index][i]
                if int(s["catches"]) + int(s["tackles"]) + int(s["interceptions"]) + int(s["sacks"]) + int(s["pocket_wins"]) > 0:
                    print("    ", game.teams[team_index]["short"], " ", game.teams[team_index]["players"][i]["name"], " ", s)
        game.aftermath_screen.raid_requested.emit()
        return false

    if game.raid_screen.visible:
        var rs = game.raid_screen
        if rs.applied:
            print("--- RAID applied: ", rs.summary_label.text)
            battles_done += 1
            rs.play_again_requested.emit()
            return false
        if rs.user_is_winner:
            var loser_tag: int = rs.loser_tag
            var take: int = 0 if loser_tag != 0 else 1
            rs._on_take_pressed(take)
            var give: int = -1
            for j in range(7):
                if RaidRules.same_slot(take, j):
                    give = j
                    break
            rs._on_give_pressed(give)
            print("--- RAID pick: take=", take, " give=", give, " summary=", rs.summary_label.text, " confirm_disabled=", rs.confirm_button.disabled)
            # Try an illegal give first to prove it is rejected.
            rs._on_give_pressed(6 if take != 6 else 0)
        else:
            print("--- RAID (AI): ", rs.summary_label.text)
        rs._on_confirm_pressed()
        return false

    var state: int = game.state
    var msg: String = game.scoreboard.message_label.text
    if msg != last_msg:
        last_msg = msg
        if "TOUCHDOWN" in msg or "INTERCEPT" in msg or "turnover" in msg or "SACKED" in msg:
            print("[%5d] " % frames, msg, "  border=%.2f" % game.scoreboard.border_bar.fraction)
    if state == game.PlayState.CALLING:
        var index: int = randi_range(0, 3) if game._user_on_offense() else randi_range(0, 2)
        cards += 1
        game._on_card_selected(index)
    elif state == game.PlayState.PRE_SNAP and game._user_throws_this_play():
        game._on_aim_started()
    elif state == game.PlayState.LIVE_POCKET and game._user_throws_this_play():
        if game.hold_seconds > 0.9:
            var target = game.receivers[randi_range(0, 1)]
            var direction: Vector2 = (target.global_position - game.qb.global_position).normalized()
            var strength: float = clampf(target.global_position.distance_to(game.qb.global_position) / 470.0, 0.25, 1.0)
            game._on_aim_updated(direction, strength)
            throws += 1
            game._on_throw_requested(direction, strength)
    if frames >= max_frames:
        print("TIMEOUT at state ", state, " possession ", game.possession_number)
        return true
    return false
