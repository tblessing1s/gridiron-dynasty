extends Node2D

const GameConstants = preload("res://scripts/core/game_constants.gd")
const BattleSettings = preload("res://scripts/core/battle_settings.gd")
const SeasonState = preload("res://scripts/core/season_state.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")
const Rosters = preload("res://scripts/core/rosters.gd")
const PlayBook = preload("res://scripts/core/play_book.gd")
const BattleSim = preload("res://scripts/core/battle_sim.gd")
const FieldViewScript = preload("res://scripts/football/field_view.gd")
const QuarterbackScript = preload("res://scripts/football/quarterback_controller.gd")
const ReceiverScript = preload("res://scripts/football/receiver_controller.gd")
const BlockerScript = preload("res://scripts/football/blocker_controller.gd")
const DefenderScript = preload("res://scripts/football/defender_ai.gd")
const FootballScript = preload("res://scripts/football/football.gd")
const ThrowTargetScript = preload("res://scripts/football/throw_target.gd")
const ScoreboardScript = preload("res://scripts/ui/scoreboard.gd")
const MatchupScreenScript = preload("res://scripts/ui/matchup_screen.gd")
const AftermathScreenScript = preload("res://scripts/ui/aftermath_screen.gd")
const RaidScreenScript = preload("res://scripts/ui/raid_screen.gd")
const BattleXp = preload("res://scripts/core/battle_xp.gd")
const RaidRules = preload("res://scripts/core/raid_rules.gd")
const PlayerRow = preload("res://scripts/ui/player_row.gd")

# Border War battle: 7-a-side, three possessions each, four downs, no kicks.
# The user always calls the plays. In PLAY mode they also throw the ball on
# their own passing plays; runs, the run after the catch, and the defense all
# play themselves.

enum PlayState { CALLING, PRE_SNAP, LIVE_POCKET, LIVE_PASS, LIVE_RUN, DEAD, BATTLE_OVER }

const USER_TEAM: int = 0
const TOTAL_POSSESSIONS: int = GameConstants.POSSESSIONS_PER_TEAM * 2
const AUTO_SNAP_DELAY: float = 0.8
const SCREEN_RELEASE_SECONDS: float = 0.45
const DRAW_HANDOFF_SECONDS: float = 0.35
const CENTER_Y: float = (GameConstants.FIELD_TOP + GameConstants.FIELD_BOTTOM) * 0.5
const LINE_SPACING: float = 46.0
const DEFENDER_COUNT: int = 4 + Rosters.LINE_SIZE
# The attacker plays away: the home crowd widens their throw scatter.
const HOME_CROWD_SCATTER: float = 1.25

var state: int = PlayState.CALLING
var mode: int = BattleSettings.Mode.PLAY
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var world_view: Node2D
var field
var scoreboard
var matchup_screen
var aftermath_screen
var raid_screen
var franchise_tag_index: int = -1
var ai_tag_index: int = -1
var season_mode: bool = false
var season_reported: bool = false
var attacker_team: int = 0
var context: Dictionary = {}
var battle_stats: Array = [[], []]
var auto_resolved: bool = false
var last_user_won: bool = false
var camera: Camera2D
var qb
var running_back
var blockers: Array = []
var receivers: Array = []
var catchers: Array = []
var defenders: Array = []
var football
var aim_line: Line2D
var throw_target

var teams: Array = []
var scores: Array[int] = [0, 0]
var offense_team: int = USER_TEAM
var possession_number: int = 1
var possession_log: Array[String] = []

var down: int = 1
var yards_to_go: int = GameConstants.FIRST_DOWN_YARDS
var ball_yard: int = GameConstants.MIDFIELD_YARD
var line_of_scrimmage_x: float = GameConstants.STARTING_LOS_X
var first_down_x: float = GameConstants.STARTING_LOS_X + 100.0
var play_start_x: float = GameConstants.STARTING_LOS_X

var offense_card: int = PlayBook.Offense.SLANTS
var defense_card: int = PlayBook.Defense.COVER
var current_carrier
var steer_touch_active: bool = false
var steer_origin: Vector2 = Vector2.ZERO
var play_resolution_pending: bool = false
var tackle_grace_seconds: float = 0.0
var snap_timer: float = -1.0
var hold_seconds: float = 0.0
var ai_decision_seconds: float = 1.2

func _ready() -> void:
    rng.randomize()
    mode = BattleSettings.mode
    _load_teams()
    _build_world()
    scoreboard.set_mode_text("%s MODE" % BattleSettings.mode_name(mode))
    scoreboard.setup_border(teams[0], teams[1])
    _show_matchup()

# In a season the battle comes from the map: the user's empire against the
# other side of the pending battle, attacker decided by the map. Otherwise
# it is the quick battle, Hawks attacking Forge.
func _load_teams() -> void:
    var battle: Dictionary = SeasonState.battle
    if not battle.is_empty() and SeasonState.season != null:
        var season = SeasonState.season
        var attacker_id: int = int(battle["attacker"])
        var defender_id: int = int(battle["defender"])
        var user_is_attacker: bool = attacker_id == season.USER_EMPIRE
        var opponent: Dictionary = season.empire(defender_id if user_is_attacker else attacker_id)
        var target: Dictionary = season.territory(int(battle["territory"]))
        var origin_id: int = int(battle["origin"])
        season_mode = true
        teams = [season.user(), opponent]
        attacker_team = 0 if user_is_attacker else 1
        context = {
            "territory": target["name"],
            "origin": season.territory(origin_id)["name"] if origin_id >= 0 else "your border",
            "user_is_attacker": user_is_attacker,
            "target_is_capital": bool(target["is_capital"]),
            "origin_is_capital": origin_id >= 0 and bool(season.territory(origin_id)["is_capital"]),
        }
    else:
        season_mode = false
        teams = [Rosters.hawks(), Rosters.forge()]
        attacker_team = 0
        context = {"territory": "Ironvale", "origin": "Harbor Point", "user_is_attacker": true, "target_is_capital": false, "origin_is_capital": false}

func _show_matchup() -> void:
    state = PlayState.BATTLE_OVER
    scoreboard.hide_cards()
    scoreboard.visible = false
    aftermath_screen.visible = false
    raid_screen.visible = false
    season_reported = false
    franchise_tag_index = int(teams[0].get("tag_index", -1))
    ai_tag_index = int(teams[1].get("tag_index", -1))
    if ai_tag_index < 0:
        ai_tag_index = _best_player_index(teams[1])
        if season_mode:
            teams[1]["tag_index"] = ai_tag_index
    matchup_screen.setup(teams[0], teams[1], mode, HOME_CROWD_SCATTER, ai_tag_index, context, franchise_tag_index if season_mode else -1)
    matchup_screen.visible = true

func _show_aftermath() -> void:
    state = PlayState.BATTLE_OVER
    scoreboard.hide_cards()
    scoreboard.visible = false
    last_user_won = scores[0] > scores[1]
    var xp_report: Array = []
    if not auto_resolved:
        for team_index in range(2):
            var players: Array = teams[team_index]["players"]
            for i in range(players.size()):
                var gains: Dictionary = BattleXp.gains(battle_stats[team_index][i])
                if gains.is_empty():
                    continue
                var kept: Dictionary = BattleXp.apply(players[i], gains, rng)
                if kept.is_empty():
                    continue
                xp_report.append({"team": team_index, "index": i, "gains": kept})
    var subtitle: String = "Territory captured" if last_user_won else "Border territory lost"
    if season_mode and not season_reported:
        season_reported = true
        SeasonState.season.complete_user_battle(last_user_won)
        SeasonState.battle = {}
        SaveGame.save()
        if not SeasonState.season.log.is_empty():
            subtitle = str(SeasonState.season.log[0])
    aftermath_screen.setup(teams[0], teams[1], scores, last_user_won, possession_log, xp_report, battle_stats[0], auto_resolved, subtitle)
    aftermath_screen.visible = true

func _show_raid() -> void:
    aftermath_screen.visible = false
    var after_text: String = "BACK TO MAP" if season_mode else "PLAY AGAIN"
    var season_number: int = int(SeasonState.season.number) if season_mode else -1
    if last_user_won:
        raid_screen.setup(teams[0], teams[1], ai_tag_index, true, after_text, season_number)
    else:
        raid_screen.setup(teams[1], teams[0], franchise_tag_index, false, after_text, season_number)
    raid_screen.visible = true

func _after_raid() -> void:
    if season_mode:
        get_tree().change_scene_to_file("res://scenes/map.tscn")
    else:
        _show_matchup()

func _on_raid_confirmed(take_index: int, give_index: int) -> void:
    if last_user_won:
        RaidRules.apply(teams[0], teams[1], take_index, give_index)
    else:
        RaidRules.apply(teams[1], teams[0], take_index, give_index)
    if season_mode:
        SaveGame.save()

func _best_player_index(team: Dictionary) -> int:
    var players: Array = team["players"]
    var best: int = 0
    var best_overall: int = -1
    for i in range(players.size()):
        var overall: int = PlayerRow.overall(players[i])
        if overall > best_overall:
            best_overall = overall
            best = i
    return best

func _reset_battle_stats() -> void:
    battle_stats = [[], []]
    for team_index in range(2):
        var players: Array = teams[team_index]["players"]
        for i in range(players.size()):
            battle_stats[team_index].append(BattleXp.empty_stats())

func _bump(team_index: int, player_index: int, key: String, amount: int = 1) -> void:
    if player_index < 0 or player_index >= battle_stats[team_index].size():
        return
    var stats: Dictionary = battle_stats[team_index][player_index]
    stats[key] = int(stats[key]) + amount

func _defense_team() -> int:
    return 1 - offense_team

func _on_matchup_play() -> void:
    matchup_screen.visible = false
    scoreboard.visible = true
    _start_battle()

func _on_matchup_auto() -> void:
    matchup_screen.visible = false
    scoreboard.visible = true
    _auto_resolve()

func _on_tag_changed(index: int) -> void:
    franchise_tag_index = index
    if season_mode:
        teams[0]["tag_index"] = index

func _build_world() -> void:
    world_view = Node2D.new()
    add_child(world_view)

    field = FieldViewScript.new()
    world_view.add_child(field)

    aim_line = Line2D.new()
    aim_line.width = 3.0
    aim_line.default_color = Color(1, 0.85, 0.3, 0.78)
    aim_line.visible = false
    aim_line.z_index = 30
    world_view.add_child(aim_line)

    throw_target = ThrowTargetScript.new()
    world_view.add_child(throw_target)

    qb = QuarterbackScript.new()
    qb.aim_started.connect(_on_aim_started)
    qb.throw_requested.connect(_on_throw_requested)
    qb.aim_updated.connect(_on_aim_updated)
    qb.aim_cancelled.connect(_on_aim_cancelled)
    world_view.add_child(qb)

    for i in range(Rosters.LINE_SIZE):
        var lineman = BlockerScript.new()
        lineman.lead_offset = Vector2(38.0, _line_offset_y(i))
        world_view.add_child(lineman)
        blockers.append(lineman)

    for i in range(2):
        var receiver = ReceiverScript.new()
        receiver.label_text = "WR"
        receiver.went_out_of_bounds.connect(_on_carrier_out_of_bounds)
        world_view.add_child(receiver)
        receivers.append(receiver)

    running_back = ReceiverScript.new()
    running_back.label_text = "RB"
    running_back.went_out_of_bounds.connect(_on_carrier_out_of_bounds)
    world_view.add_child(running_back)

    catchers = [receivers[0], receivers[1], running_back]

    for i in range(DEFENDER_COUNT):
        var defender = DefenderScript.new()
        world_view.add_child(defender)
        defenders.append(defender)

    football = FootballScript.new()
    football.pass_finished.connect(_on_pass_caught)
    football.pass_incomplete.connect(_on_pass_incomplete)
    football.pass_intercepted.connect(_on_pass_intercepted)
    world_view.add_child(football)

    camera = Camera2D.new()
    camera.zoom = Vector2(1.8, 1.8)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 6.0
    camera.limit_left = int(GameConstants.FIELD_RECT.position.x)
    camera.limit_right = int(GameConstants.FIELD_RECT.end.x)
    camera.limit_top = int(GameConstants.FIELD_RECT.position.y)
    camera.limit_bottom = int(GameConstants.FIELD_RECT.end.y)
    camera.position = Vector2(line_of_scrimmage_x, CENTER_Y)
    world_view.add_child(camera)
    camera.make_current()

    scoreboard = ScoreboardScript.new()
    scoreboard.card_selected.connect(_on_card_selected)
    add_child(scoreboard)

    matchup_screen = MatchupScreenScript.new()
    matchup_screen.play_requested.connect(_on_matchup_play)
    matchup_screen.auto_requested.connect(_on_matchup_auto)
    matchup_screen.menu_requested.connect(_back_to_menu)
    matchup_screen.tag_changed.connect(_on_tag_changed)
    add_child(matchup_screen)

    aftermath_screen = AftermathScreenScript.new()
    aftermath_screen.raid_requested.connect(_show_raid)
    aftermath_screen.menu_requested.connect(_back_to_menu)
    aftermath_screen.visible = false
    add_child(aftermath_screen)

    raid_screen = RaidScreenScript.new()
    raid_screen.raid_confirmed.connect(_on_raid_confirmed)
    raid_screen.play_again_requested.connect(_after_raid)
    raid_screen.menu_requested.connect(_back_to_menu)
    raid_screen.visible = false
    add_child(raid_screen)

# ---------------------------------------------------------------- battle flow

func _start_battle() -> void:
    scores[0] = 0
    scores[1] = 0
    offense_team = attacker_team
    possession_number = 1
    possession_log.clear()
    auto_resolved = false
    _reset_battle_stats()
    _refresh_score()
    _start_possession(GameConstants.MIDFIELD_YARD, "%s attack first • possession 1 of %d • call the play" % [teams[attacker_team]["short"], TOTAL_POSSESSIONS])

func _auto_resolve() -> void:
    var result: Dictionary = BattleSim.resolve(teams[attacker_team], teams[1 - attacker_team], rng)
    scores[attacker_team] = int(result["home_score"])
    scores[1 - attacker_team] = int(result["away_score"])
    _refresh_score()
    scoreboard.update_possession("AUTO-RESOLVED")
    auto_resolved = true
    _reset_battle_stats()
    possession_log.clear()
    for line in result["log"]:
        possession_log.append(str(line))
    _show_aftermath()

func _start_possession(start_yard: int, intro: String) -> void:
    down = 1
    yards_to_go = GameConstants.FIRST_DOWN_YARDS
    ball_yard = clampi(start_yard, 1, GameConstants.FIELD_YARDS - 1)
    line_of_scrimmage_x = GameConstants.LEFT_GOAL_X + float(ball_yard) * GameConstants.PIXELS_PER_YARD
    _assign_teams()
    _prepare_play(intro)

func _assign_teams() -> void:
    var offense: Dictionary = teams[offense_team]
    var defense: Dictionary = teams[1 - offense_team]
    var offense_players: Array = offense["players"]
    var defense_players: Array = defense["players"]
    var offense_color: Color = offense["color"]
    var defense_color: Color = defense["color"]

    qb.apply_stats(offense_players[0])
    qb.set_team_color(offense_color)
    qb.player_index = 0
    running_back.apply_stats(offense_players[1])
    running_back.set_team_color(offense_color)
    running_back.player_index = 1
    receivers[0].apply_stats(offense_players[2])
    receivers[0].set_team_color(offense_color)
    receivers[0].player_index = 2
    receivers[1].apply_stats(offense_players[3])
    receivers[1].set_team_color(offense_color)
    receivers[1].player_index = 3
    for i in range(blockers.size()):
        blockers[i].apply_stats(offense_players[Rosters.LINE_START + i])
        blockers[i].set_team_color(offense_color)
        blockers[i].player_index = Rosters.LINE_START + i

    var roles: Array[int] = [DefenderScript.Role.SAFETY, DefenderScript.Role.LINEBACKER, DefenderScript.Role.CORNER, DefenderScript.Role.CORNER]
    var labels: Array[String] = ["S", "LB", "CB", "CB"]
    for i in range(Rosters.LINE_SIZE):
        roles.append(DefenderScript.Role.RUSHER)
        labels.append("X")
    for i in range(defenders.size()):
        var defender = defenders[i]
        defender.role = roles[i]
        defender.label_text = labels[i]
        defender.apply_stats(defense_players[i])
        defender.set_team_color(defense_color)
        defender.player_index = i
        defender.quarterback = qb
        defender.blockers = blockers
        defender.blocker = blockers[1]
        defender.spy_target = running_back
        defender.receivers = catchers
    defenders[2].covered_receiver = receivers[0]
    defenders[3].covered_receiver = receivers[1]
    for i in range(Rosters.LINE_SIZE):
        _rusher(i).blocker = blockers[i]

    for catcher in catchers:
        catcher.defenders = defenders
        catcher.user_control_allowed = _user_controls_offense()

    field.set_end_zone_labels(offense["short"])

func _prepare_play(message: String = "") -> void:
    state = PlayState.CALLING
    current_carrier = null
    steer_touch_active = false
    play_resolution_pending = false
    tackle_grace_seconds = 0.0
    snap_timer = -1.0
    hold_seconds = 0.0
    play_start_x = line_of_scrimmage_x
    first_down_x = minf(line_of_scrimmage_x + float(yards_to_go) * GameConstants.PIXELS_PER_YARD, GameConstants.RIGHT_GOAL_X)
    field.set_markers(line_of_scrimmage_x, first_down_x)
    field.clear_route_previews()

    var los: float = line_of_scrimmage_x
    qb.reset_for_play(Vector2(los - 55.0, CENTER_Y))
    running_back.reset_for_play(Vector2(los - 100.0, CENTER_Y + 40.0))
    receivers[0].reset_for_play(Vector2(los - 4.0, 245.0))
    receivers[1].reset_for_play(Vector2(los - 4.0, 540.0))
    defenders[0].reset_for_play(Vector2(los + 170.0, CENTER_Y))
    defenders[1].reset_for_play(Vector2(los + 95.0, CENTER_Y))
    defenders[2].reset_for_play(Vector2(los + 55.0, 245.0))
    defenders[3].reset_for_play(Vector2(los + 55.0, 540.0))
    for i in range(Rosters.LINE_SIZE):
        blockers[i].reset_for_play(Vector2(los - 22.0, CENTER_Y + _line_offset_y(i)))
        _rusher(i).reset_for_play(Vector2(los + 22.0, CENTER_Y + _line_offset_y(i)))
    for defender in defenders:
        defender.line_x = los

    football.visible = false
    football.is_airborne = false
    aim_line.visible = false
    aim_line.clear_points()
    throw_target.hide_marker()

    scoreboard.update_situation(down, yards_to_go, ball_yard)
    scoreboard.update_possession(_possession_text())
    scoreboard.update_border(_frontier_fraction(line_of_scrimmage_x))
    _offer_cards()
    scoreboard.set_message(message if not message.is_empty() else "Call the play.")

func _offer_cards() -> void:
    if _user_on_offense():
        defense_card = PlayBook.ai_defense_card(down, yards_to_go, rng)
        var awareness: int = qb.stat("awareness")
        var read_known: bool = rng.randf() < Rosters.read_chance(awareness)
        var hints: Array[String] = []
        for i in range(PlayBook.OFFENSE_NAMES.size()):
            if read_known:
                hints.append("vs %s: %s" % [PlayBook.DEFENSE_NAMES[defense_card], PlayBook.matchup_label(i, defense_card)])
            else:
                hints.append(PlayBook.OFFENSE_HINTS[i])
        if read_known:
            scoreboard.set_read("READ (%s, AWR %d): defense showing %s" % [qb.player_name(), awareness, PlayBook.DEFENSE_NAMES[defense_card]])
        else:
            scoreboard.set_read("READ (%s, AWR %d): no tell this time" % [qb.player_name(), awareness])
        scoreboard.show_cards(PlayBook.OFFENSE_NAMES, hints)
    else:
        offense_card = PlayBook.ai_offense_card(down, yards_to_go, rng)
        var safety = defenders[0]
        var awareness: int = safety.stat("awareness")
        var read_known: bool = rng.randf() < Rosters.read_chance(awareness)
        if read_known:
            var look: String = "RUN" if PlayBook.OFFENSE_IS_RUN[offense_card] else "PASS"
            scoreboard.set_read("READ (%s, AWR %d): offense in a %s look" % [safety.player_name(), awareness, look])
        else:
            scoreboard.set_read("READ (%s, AWR %d): no tell this time" % [safety.player_name(), awareness])
        scoreboard.show_cards(PlayBook.DEFENSE_NAMES, PlayBook.DEFENSE_HINTS)

func _on_card_selected(index: int) -> void:
    if state != PlayState.CALLING:
        return
    if _user_on_offense():
        offense_card = index
    else:
        defense_card = index
    scoreboard.hide_cards()
    _setup_formation()
    state = PlayState.PRE_SNAP

    var called: String = PlayBook.OFFENSE_NAMES[offense_card] if _user_on_offense() else PlayBook.DEFENSE_NAMES[defense_card]
    if _user_throws_this_play():
        qb.input_enabled = true
        scoreboard.set_message("%s • Hold the QB to snap • Pull back away from your target • Release to throw" % called)
    else:
        snap_timer = AUTO_SNAP_DELAY
        scoreboard.set_message("%s called • snapping…" % called)

func _setup_formation() -> void:
    # Each rusher fights his own blocker; the pocket lasts until the first
    # one wins his matchup.
    var shortest_pocket: float = INF
    for i in range(Rosters.LINE_SIZE):
        var pocket: float = Rosters.pocket_seconds(blockers[i].stat("power"), _rusher(i).stat("power"))
        _rusher(i).pocket_seconds = pocket
        shortest_pocket = minf(shortest_pocket, pocket)
    for defender in defenders:
        defender.assignment = defense_card
        defender.offset_scale = 1.0
    defenders[1].pocket_seconds = shortest_pocket * 0.6 + 0.3
    if defense_card == PlayBook.Defense.COVER:
        defenders[2].offset_scale = 0.7
        defenders[3].offset_scale = 0.7
    elif defense_card == PlayBook.Defense.BLITZ:
        defenders[2].offset_scale = 1.8
        defenders[3].offset_scale = 1.8
    field.set_route_previews(_build_routes())
    ai_decision_seconds = Rosters.decision_seconds(qb.stat("awareness"))

func _build_routes() -> Array[PackedVector2Array]:
    var los: float = line_of_scrimmage_x
    var max_x: float = GameConstants.RIGHT_GOAL_X + 10.0
    var wr1: PackedVector2Array = PackedVector2Array()
    var wr2: PackedVector2Array = PackedVector2Array()
    var rb: PackedVector2Array = PackedVector2Array()
    var yd: float = GameConstants.PIXELS_PER_YARD
    match offense_card:
        PlayBook.Offense.SLANTS:
            wr1 = PackedVector2Array([Vector2(los + 3.0 * yd, 245.0), Vector2(los + 7.0 * yd, 320.0), Vector2(los + 14.0 * yd, 340.0)])
            wr2 = PackedVector2Array([Vector2(los + 4.0 * yd, 540.0), Vector2(los + 8.0 * yd, 470.0), Vector2(los + 15.0 * yd, 450.0)])
        PlayBook.Offense.DEEP_SHOT:
            wr1 = PackedVector2Array([Vector2(los + 5.0 * yd, 235.0), Vector2(los + 16.0 * yd, 215.0), Vector2(los + 30.0 * yd, 215.0)])
            wr2 = PackedVector2Array([Vector2(los + 5.0 * yd, 540.0), Vector2(los + 12.0 * yd, 440.0), Vector2(los + 24.0 * yd, 400.0)])
        PlayBook.Offense.DRAW:
            wr1 = PackedVector2Array([Vector2(los + 3.0 * yd, 245.0)])
            wr2 = PackedVector2Array([Vector2(los + 3.0 * yd, 540.0)])
            rb = PackedVector2Array([Vector2(los - 60.0, CENTER_Y + 30.0)])
        PlayBook.Offense.SCREEN:
            wr1 = PackedVector2Array([Vector2(los + 2.0 * yd, 200.0)])
            wr2 = PackedVector2Array([Vector2(los + 2.0 * yd, 590.0)])
            rb = PackedVector2Array([Vector2(los - 40.0, 520.0), Vector2(los + 1.0 * yd, 560.0)])
    var routes: Array[PackedVector2Array] = [_clamp_route(wr1, max_x), _clamp_route(wr2, max_x), _clamp_route(rb, max_x)]
    return routes

func _clamp_route(route: PackedVector2Array, max_x: float) -> PackedVector2Array:
    var clamped: PackedVector2Array = PackedVector2Array()
    for point in route:
        clamped.append(Vector2(minf(point.x, max_x), point.y))
    return clamped

func _snap() -> void:
    state = PlayState.LIVE_POCKET
    hold_seconds = 0.0
    snap_timer = -1.0
    field.clear_route_previews()
    var routes: Array[PackedVector2Array] = _build_routes()
    receivers[0].start_route(routes[0])
    receivers[1].start_route(routes[1])
    if routes[2].size() > 0:
        running_back.start_route(routes[2])
    for defender in defenders:
        defender.set_ai_enabled(true)
    for i in range(battle_stats[0].size()):
        _bump(0, i, "plays")
        _bump(1, i, "plays")
    scoreboard.set_read("")
    scoreboard.set_message("%s vs %s • %.1fs pocket" % [PlayBook.OFFENSE_NAMES[offense_card], PlayBook.DEFENSE_NAMES[defense_card], _shortest_pocket()])

func _handoff(carrier) -> void:
    current_carrier = carrier
    carrier.become_ball_carrier()
    tackle_grace_seconds = 0.45
    for lineman in blockers:
        lineman.lead_for(carrier)
    for defender in defenders:
        defender.set_ball_carrier(carrier)
    qb.can_throw = false
    qb.input_enabled = false
    state = PlayState.LIVE_RUN
    var steer_hint: String = " • drag to steer" if _user_controls_offense() else ""
    scoreboard.set_message("Handoff to %s%s" % [carrier.player_name(), steer_hint])

# ---------------------------------------------------------------- per frame

func _physics_process(delta: float) -> void:
    _update_camera()
    match state:
        PlayState.PRE_SNAP:
            if snap_timer >= 0.0:
                snap_timer -= delta
                if snap_timer <= 0.0:
                    _snap()
        PlayState.LIVE_POCKET:
            hold_seconds += delta
            if _check_sack():
                return
            if offense_card == PlayBook.Offense.DRAW:
                if hold_seconds >= DRAW_HANDOFF_SECONDS:
                    _handoff(running_back)
            elif not _user_throws_this_play():
                _ai_throw_decision()
        PlayState.LIVE_RUN:
            _update_run(delta)

func _check_sack() -> bool:
    for defender in defenders:
        if not defender.rush_released() or not defender.can_tackle():
            continue
        if defender.global_position.distance_to(qb.global_position) <= GameConstants.TACKLE_RADIUS + 4.0:
            qb.cancel_aim()
            _bump(_defense_team(), defender.player_index, "sacks")
            _finish_play(qb.global_position.x, true, "SACKED by %s" % defender.player_name())
            return true
    return false

func _ai_throw_decision() -> void:
    if offense_card == PlayBook.Offense.SCREEN:
        if hold_seconds >= SCREEN_RELEASE_SECONDS:
            _throw_to(running_back)
        return

    var pressure: bool = _nearest_rusher_distance() < 75.0
    if hold_seconds < ai_decision_seconds and not pressure:
        return

    var best = null
    var best_score: float = -INF
    var best_separation: float = 0.0
    for receiver in receivers:
        var separation: float = _nearest_defender_distance(receiver.global_position)
        var depth: float = receiver.global_position.x - line_of_scrimmage_x
        var score: float = separation + depth * 0.2
        if score > best_score:
            best_score = score
            best = receiver
            best_separation = separation

    var desperate: bool = pressure or hold_seconds > ai_decision_seconds + 1.4
    if best != null and (best_separation > 50.0 or desperate):
        _throw_to(best)
    elif desperate:
        _launch(Vector2(qb.global_position.x + 220.0, GameConstants.FIELD_TOP + 4.0))

func _throw_to(receiver) -> void:
    var lead: Vector2 = receiver.global_position + receiver.velocity * 0.5
    _launch(lead)

func _launch(target: Vector2) -> void:
    var scatter: float = Rosters.scatter_px(qb.stat("skill")) * rng.randf()
    if offense_team == attacker_team:
        scatter *= HOME_CROWD_SCATTER
    var angle: float = rng.randf() * TAU
    var landing: Vector2 = target + Vector2(cos(angle), sin(angle)) * scatter
    landing.x = clampf(landing.x, GameConstants.LEFT_GOAL_X, GameConstants.RIGHT_GOAL_X + 40.0)
    landing.y = clampf(landing.y, GameConstants.FIELD_TOP, GameConstants.FIELD_BOTTOM)

    state = PlayState.LIVE_PASS
    qb.can_throw = false
    qb.input_enabled = false
    aim_line.visible = false
    aim_line.clear_points()
    throw_target.hide_marker()
    for i in range(Rosters.LINE_SIZE):
        if not _rusher(i).rush_released():
            _bump(offense_team, blockers[i].player_index, "pocket_wins")

    football.launch_to(qb.global_position + Vector2(20.0, 0.0), landing, catchers, defenders)

    var nearest = null
    var nearest_distance: float = INF
    for catcher in catchers:
        var distance: float = catcher.global_position.distance_to(landing)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = catcher
    if nearest != null and nearest_distance < 240.0:
        nearest.chase_ball(landing)

    for defender in defenders:
        defender.watch_ball(football)
    scoreboard.set_message("Pass in the air…")

func _update_run(delta: float) -> void:
    if current_carrier == null or play_resolution_pending:
        return
    tackle_grace_seconds = maxf(tackle_grace_seconds - delta, 0.0)
    scoreboard.update_border(_frontier_fraction(current_carrier.global_position.x))

    if current_carrier.global_position.x >= GameConstants.RIGHT_GOAL_X:
        _score_touchdown()
        return

    if tackle_grace_seconds > 0.0:
        return

    for defender in defenders:
        if not defender.can_tackle():
            continue
        if defender.global_position.distance_to(current_carrier.global_position) > GameConstants.TACKLE_RADIUS:
            continue
        var chance: float = Rosters.break_tackle_chance(current_carrier.stat("power"), defender.stat("power"))
        if rng.randf() < chance:
            defender.shed_seconds = 0.6
            tackle_grace_seconds = 0.2
            scoreboard.set_message("%s breaks the tackle!" % current_carrier.player_name())
            return
        _bump(_defense_team(), defender.player_index, "tackles")
        _finish_play(current_carrier.global_position.x, true, "TACKLED by %s" % defender.player_name())
        return

# ---------------------------------------------------------------- user throw

func _on_aim_started() -> void:
    if state == PlayState.PRE_SNAP and _user_throws_this_play():
        _snap()

func _on_aim_updated(direction: Vector2, strength: float) -> void:
    if state != PlayState.LIVE_POCKET or not _user_throws_this_play():
        return
    var target: Vector2 = _throw_point(direction, strength)
    _update_projected_arc(target)
    throw_target.show_at(target, _nearest_defender_distance(target) < 48.0)

func _on_aim_cancelled() -> void:
    aim_line.visible = false
    aim_line.clear_points()
    throw_target.hide_marker()
    if state == PlayState.LIVE_POCKET:
        scoreboard.set_message("Throw cancelled • press the QB and pull back again")

func _on_throw_requested(direction: Vector2, strength: float) -> void:
    if state != PlayState.LIVE_POCKET or not _user_throws_this_play():
        return
    _launch(_throw_point(direction, strength))

func _throw_point(direction: Vector2, strength: float) -> Vector2:
    var throw_distance: float = lerpf(165.0, 470.0, maxf(strength, 0.2))
    var target: Vector2 = qb.global_position + direction * throw_distance
    target.x = clampf(target.x, GameConstants.LEFT_GOAL_X, GameConstants.RIGHT_GOAL_X + 40.0)
    target.y = clampf(target.y, GameConstants.FIELD_TOP, GameConstants.FIELD_BOTTOM)
    return target

func _update_projected_arc(target: Vector2) -> void:
    aim_line.clear_points()
    var origin: Vector2 = qb.global_position
    var direction: Vector2 = (target - origin).normalized()
    var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
    for i in range(18):
        var t: float = float(i) / 17.0
        var point: Vector2 = origin.lerp(target, t)
        point += perpendicular * sin(t * PI) * 14.0
        aim_line.add_point(point)
    aim_line.visible = true

# ---------------------------------------------------------------- ball events

func _on_pass_caught(receiver) -> void:
    if state != PlayState.LIVE_PASS:
        return
    current_carrier = receiver
    tackle_grace_seconds = 0.25
    receiver.become_ball_carrier()
    _bump(offense_team, receiver.player_index, "catches")
    _bump(offense_team, qb.player_index, "completions")
    state = PlayState.LIVE_RUN
    for catcher in catchers:
        if catcher != receiver:
            catcher.stop_route()
    for lineman in blockers:
        lineman.lead_for(receiver)
    for defender in defenders:
        defender.set_ball_carrier(receiver)
    var steer_hint: String = " • drag to steer" if _user_controls_offense() else ""
    scoreboard.set_message("Caught by %s%s" % [receiver.player_name(), steer_hint])

func _on_pass_incomplete() -> void:
    if state != PlayState.LIVE_PASS:
        return
    _finish_play(play_start_x, false, "INCOMPLETE")

func _on_pass_intercepted(defender) -> void:
    if state != PlayState.LIVE_PASS:
        return
    var spot_yard: int = clampi(int(round((defender.global_position.x - GameConstants.LEFT_GOAL_X) / GameConstants.PIXELS_PER_YARD)), 1, GameConstants.FIELD_YARDS - 1)
    _bump(_defense_team(), defender.player_index, "interceptions")
    _end_possession(GameConstants.FIELD_YARDS - spot_yard, "INTERCEPTED by %s at the %d" % [defender.player_name(), spot_yard])

func _on_carrier_out_of_bounds(carrier) -> void:
    if state == PlayState.LIVE_RUN and carrier == current_carrier and not play_resolution_pending:
        _finish_play(carrier.global_position.x, true, "OUT OF BOUNDS")

# ---------------------------------------------------------------- resolution

func _finish_play(end_x: float, counts_yards: bool, result_text: String) -> void:
    if play_resolution_pending or state == PlayState.BATTLE_OVER:
        return
    play_resolution_pending = true
    state = PlayState.DEAD
    _freeze_players()

    var gained_yards: int = 0
    if counts_yards:
        gained_yards = int(round((end_x - play_start_x) / GameConstants.PIXELS_PER_YARD))
    if current_carrier != null and gained_yards > 0:
        _bump(offense_team, current_carrier.player_index, "yards", gained_yards)
        _bump(offense_team, current_carrier.player_index, "plays")
    var reached_first_down: bool = counts_yards and end_x >= first_down_x

    ball_yard = clampi(ball_yard + gained_yards, 1, GameConstants.FIELD_YARDS - 1)
    line_of_scrimmage_x = GameConstants.LEFT_GOAL_X + float(ball_yard) * GameConstants.PIXELS_PER_YARD

    if reached_first_down:
        down = 1
        yards_to_go = mini(GameConstants.FIRST_DOWN_YARDS, GameConstants.FIELD_YARDS - ball_yard)
        scoreboard.set_message("%s • %+d yards • FIRST DOWN" % [result_text, gained_yards])
    else:
        down += 1
        var remaining_pixels: float = maxf(first_down_x - line_of_scrimmage_x, 0.0)
        yards_to_go = maxi(int(ceil(remaining_pixels / GameConstants.PIXELS_PER_YARD)), 1)
        scoreboard.set_message("%s • %+d yards" % [result_text, gained_yards])

    scoreboard.update_situation(mini(down, 4), yards_to_go, ball_yard)
    scoreboard.update_border(_frontier_fraction(line_of_scrimmage_x))

    if down > 4:
        _end_possession(GameConstants.FIELD_YARDS - ball_yard, "turnover on downs at the %d" % ball_yard)
        return

    await get_tree().create_timer(1.15).timeout
    if state == PlayState.DEAD:
        _prepare_play()

func _score_touchdown() -> void:
    scores[offense_team] += 7
    _refresh_score()
    if current_carrier != null:
        var gained_yards: int = int(round((GameConstants.RIGHT_GOAL_X - play_start_x) / GameConstants.PIXELS_PER_YARD))
        _bump(offense_team, current_carrier.player_index, "yards", maxi(gained_yards, 0))
        _bump(offense_team, current_carrier.player_index, "touchdowns")
    _end_possession(GameConstants.MIDFIELD_YARD, "TOUCHDOWN")

func _end_possession(next_start_yard: int, reason: String) -> void:
    if state == PlayState.BATTLE_OVER:
        return
    play_resolution_pending = true
    state = PlayState.DEAD
    _freeze_players()

    var offense: Dictionary = teams[offense_team]
    var prefix: String = "Poss %d" % possession_number
    if possession_number > TOTAL_POSSESSIONS:
        prefix = "Sudden death %d" % (possession_number - TOTAL_POSSESSIONS)
    possession_log.append("%s · %s: %s" % [prefix, offense["short"], reason])
    scoreboard.set_message("%s • %s" % [offense["short"], reason])

    var completed: int = possession_number
    possession_number += 1
    if completed >= TOTAL_POSSESSIONS and completed % 2 == 0 and scores[0] != scores[1]:
        _end_battle()
        return

    offense_team = 1 - offense_team
    var next_team: Dictionary = teams[offense_team]
    var intro: String = "%s ball • possession %d of %d • call the play" % [next_team["short"], possession_number, TOTAL_POSSESSIONS]
    if completed >= TOTAL_POSSESSIONS:
        intro = "SUDDEN DEATH • %s ball • call the play" % next_team["short"]

    await get_tree().create_timer(1.8).timeout
    if state != PlayState.DEAD:
        return
    _start_possession(next_start_yard, intro)

func _end_battle() -> void:
    state = PlayState.BATTLE_OVER
    scoreboard.update_possession("FINAL")
    _show_aftermath()

func _freeze_players() -> void:
    qb.can_throw = false
    qb.input_enabled = false
    qb.cancel_aim()
    for catcher in catchers:
        catcher.stop_route()
        catcher.is_ball_carrier = false
        catcher.velocity = Vector2.ZERO
    for lineman in blockers:
        lineman.lead_for(null)
    for defender in defenders:
        defender.set_ai_enabled(false)
        defender.ball_carrier = null
        defender.watched_football = null
    football.is_airborne = false
    aim_line.visible = false
    aim_line.clear_points()
    throw_target.hide_marker()

# ---------------------------------------------------------------- helpers

func _user_on_offense() -> bool:
    return offense_team == USER_TEAM

func _rusher(index: int):
    return defenders[4 + index]

func _line_offset_y(index: int) -> float:
    return (float(index) - float(Rosters.LINE_SIZE - 1) * 0.5) * LINE_SPACING

func _shortest_pocket() -> float:
    var shortest: float = INF
    for i in range(Rosters.LINE_SIZE):
        shortest = minf(shortest, _rusher(i).pocket_seconds)
    return shortest

func _user_controls_offense() -> bool:
    return _user_on_offense() and mode == BattleSettings.Mode.PLAY

func _user_throws_this_play() -> bool:
    return _user_controls_offense() and not PlayBook.OFFENSE_IS_RUN[offense_card]

func _nearest_defender_distance(point: Vector2) -> float:
    var nearest: float = INF
    for defender in defenders:
        nearest = minf(nearest, defender.global_position.distance_to(point))
    return nearest

func _nearest_rusher_distance() -> float:
    var nearest: float = INF
    for defender in defenders:
        if defender.rush_released():
            nearest = minf(nearest, defender.global_position.distance_to(qb.global_position))
    return nearest

func _possession_text() -> String:
    var offense: Dictionary = teams[offense_team]
    if possession_number > TOTAL_POSSESSIONS:
        return "SUDDEN DEATH • %s BALL" % offense["short"]
    return "POSS %d/%d • %s BALL" % [possession_number, TOTAL_POSSESSIONS, offense["short"]]

func _refresh_score() -> void:
    scoreboard.update_score(scores[0], scores[1], teams[0]["short"], teams[1]["short"])

# Frontier as a 0..1 fraction from the user's side of the map. Both teams
# attack to the right on screen, so the away team's yardage is mirrored.
func _frontier_fraction(world_x: float) -> float:
    var yard: float = clampf((world_x - GameConstants.LEFT_GOAL_X) / GameConstants.PIXELS_PER_YARD, 0.0, float(GameConstants.FIELD_YARDS))
    var fraction: float = yard / float(GameConstants.FIELD_YARDS)
    return fraction if _user_on_offense() else 1.0 - fraction

func _back_to_menu() -> void:
    get_tree().change_scene_to_file("res://scenes/main.tscn")

# ---------------------------------------------------------------- input & camera

func _unhandled_input(event: InputEvent) -> void:
    if state != PlayState.LIVE_RUN or current_carrier == null or not _user_controls_offense():
        return

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        steer_touch_active = event.pressed
        if event.pressed:
            steer_origin = _to_world(event.position)
        else:
            current_carrier.set_carrier_input(Vector2.ZERO)
        return

    if event is InputEventMouseMotion and steer_touch_active:
        current_carrier.set_carrier_input(_to_world(event.position) - steer_origin)
        return

    if event is InputEventScreenTouch:
        steer_touch_active = event.pressed
        if event.pressed:
            steer_origin = _to_world(event.position)
        else:
            current_carrier.set_carrier_input(Vector2.ZERO)
        return

    if event is InputEventScreenDrag and steer_touch_active:
        current_carrier.set_carrier_input(_to_world(event.position) - steer_origin)

func _to_world(screen_pos: Vector2) -> Vector2:
    return get_viewport().canvas_transform.affine_inverse() * screen_pos

func _update_camera() -> void:
    var focus: Vector2 = Vector2(line_of_scrimmage_x + 90.0, CENTER_Y)
    if state == PlayState.LIVE_PASS and football != null:
        focus = football.global_position
    elif state == PlayState.LIVE_RUN and current_carrier != null and is_instance_valid(current_carrier):
        focus = current_carrier.global_position
    camera.position = focus
