extends SceneTree

# Headless harness: plays N battles back to back through matchup, battle,
# aftermath, and raid, calling the same handlers the UI would.

const BattleSettings = preload("res://scripts/core/battle_settings.gd")
const RaidRules = preload("res://scripts/core/raid_rules.gd")
const PlayBook = preload("res://scripts/core/play_book.gd")

var game
var frames: int = 0
var max_frames: int = 40000
var throws: int = 0
var cards: int = 0
var battles_wanted: int = 2
var battles_done: int = 0
var mode_arg: int = BattleSettings.Mode.SIM
var sim_checks_done: int = 0
var last_msg: String = ""
var raid_confirmed_this_battle: bool = false
var replay_arg: bool = false
var awaiting_replay: bool = false
var replay_deadline_frame: int = 0
const REPLAY_TIMEOUT_FRAMES: int = 600

func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() > 0:
        mode_arg = int(args[0])
    if args.size() > 1:
        battles_wanted = int(args[1])
    if args.size() > 2:
        replay_arg = int(args[2]) != 0
    BattleSettings.mode = mode_arg
    # A resolved down's message/detail don't appear until the replay tween
    # finishes, so the default run keeps it off for a synchronous, frame-
    # exact test; replay_arg=1 exercises the tweened path instead (see the
    # awaiting_replay branch below).
    BattleSettings.replay = replay_arg
    BattleSettings.replay_speed = 1.0
    var scene: PackedScene = load("res://scenes/game.tscn")
    game = scene.instantiate()
    root.add_child(game)
    print("MODE ", BattleSettings.mode_name(mode_arg), " replay=", replay_arg)

func _roster_line(team: Dictionary) -> String:
    var parts: PackedStringArray = PackedStringArray()
    for p in team["players"]:
        parts.append("%s(%d/%d/%d/%d)" % [p["name"], p["speed"], p["power"], p["skill"], p["awareness"]])
    return " ".join(parts)

func _physics_process(_delta: float) -> bool:
    frames += 1
    if game == null:
        return true

    # A down's message/detail don't appear until the replay tween's
    # `finished` fires, so wait it out (bounded) instead of asserting on the
    # same tick _on_card_selected was called.
    if awaiting_replay:
        if game.state == game.PlayState.REPLAYING:
            assert(frames <= replay_deadline_frame, "SIM replay did not reach 'finished' within the timeout")
            return false
        awaiting_replay = false
        assert(not game.scoreboard.detail_label.text.is_empty(), "SIM detail line should not be empty after a replayed down resolves")
        assert(game.lineup_strips.rows[0].size() == 7 and game.lineup_strips.rows[1].size() == 7, "lineup strips should have seven rows per side")
        for side in range(2):
            for i in range(7):
                assert(not str(game.lineup_strips.rows[side][i]["ovr"].text).is_empty(), "row overall should not be empty")
        var any_highlight: bool = not game.lineup_strips.highlighted[0].is_empty() or not game.lineup_strips.highlighted[1].is_empty()
        assert(any_highlight, "a highlight should be applied after a replayed SIM down")
        if sim_checks_done < 3:
            print("DETAIL (replayed): ", game.scoreboard.detail_label.text)
            sim_checks_done += 1

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
            assert(rs.take_index >= 0 and rs.give_index >= 0, "AI could not find a raid target in quick battle")
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
        var index: int = randi_range(0, PlayBook.OFFENSE_NAMES.size() - 1) if game._user_on_offense() else randi_range(0, PlayBook.DEFENSE_NAMES.size() - 1)
        cards += 1
        if mode_arg == BattleSettings.Mode.SIM:
            assert(not game.scoreboard.coach_label.text.is_empty(), "coach line should not be empty on a CALLING step")
            assert(not game.scoreboard.read_label.text.is_empty(), "read line should not be empty on a CALLING step")
            if sim_checks_done < 3:
                print("COACH: ", game.scoreboard.coach_label.text)
        game._on_card_selected(index)
        if mode_arg == BattleSettings.Mode.SIM and replay_arg:
            awaiting_replay = true
            replay_deadline_frame = frames + REPLAY_TIMEOUT_FRAMES
        elif mode_arg == BattleSettings.Mode.SIM:
            assert(not game.scoreboard.detail_label.text.is_empty(), "SIM detail line should not be empty after a down resolves")
            assert(game.lineup_strips.rows[0].size() == 7 and game.lineup_strips.rows[1].size() == 7, "lineup strips should have seven rows per side")
            for side in range(2):
                for i in range(7):
                    assert(not str(game.lineup_strips.rows[side][i]["ovr"].text).is_empty(), "row overall should not be empty")
            var any_highlight: bool = not game.lineup_strips.highlighted[0].is_empty() or not game.lineup_strips.highlighted[1].is_empty()
            assert(any_highlight, "a highlight should be applied after a SIM down")
            if sim_checks_done < 3:
                print("DETAIL: ", game.scoreboard.detail_label.text)
                sim_checks_done += 1
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
