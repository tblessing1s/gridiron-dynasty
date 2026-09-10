extends Node2D

const GameConstants = preload("res://scripts/core/game_constants.gd")
const BattleSettings = preload("res://scripts/core/battle_settings.gd")
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

var state: int = PlayState.CALLING
var mode: int = BattleSettings.Mode.PLAY
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var world_view: Node2D
var field
var scoreboard
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
    teams = [Rosters.hawks(), Rosters.forge()]
    _build_world()
    scoreboard.set_mode_text("%s MODE" % BattleSettings.mode_name(mode))
    if mode == BattleSettings.Mode.AUTO_RESOLVE:
        _auto_resolve()
    else:
        _start_battle()

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
    scoreboard.restart_requested.connect(_on_restart)
    scoreboard.back_to_menu_requested.connect(_back_to_menu)
    add_child(scoreboard)

# ---------------------------------------------------------------- battle flow

func _start_battle() -> void:
    scores[0] = 0
    scores[1] = 0
    offense_team = USER_TEAM
    possession_number = 1
    possession_log.clear()
    scoreboard.hide_result()
    _refresh_score()
    _start_possession(GameConstants.MIDFIELD_YARD, "%s attack first • possession 1 of %d • call the play" % [teams[USER_TEAM]["short"], TOTAL_POSSESSIONS])

func _auto_resolve() -> void:
    var result: Dictionary = BattleSim.resolve(teams[0], teams[1], rng)
    scores[0] = int(result["home_score"])
    scores[1] = int(result["away_score"])
    _refresh_score()
    scoreboard.update_possession("AUTO-RESOLVED")
    scoreboard.hide_cards()
    scoreboard.set_message("Battle simulated")
    state = PlayState.BATTLE_OVER
    var log: Array = result["log"]
    scoreboard.show_result(_result_title(), "\n".join(PackedStringArray(log)))

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
    running_back.apply_stats(offense_players[1])
    running_back.set_team_color(offense_color)
    receivers[0].apply_stats(offense_players[2])
    receivers[0].set_team_color(offense_color)
    receivers[1].apply_stats(offense_players[3])
    receivers[1].set_team_color(offense_color)
    for i in range(blockers.size()):
        blockers[i].apply_stats(offense_players[Rosters.LINE_START + i])
        blockers[i].set_team_color(offense_color)

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

    if down > 4:
        _end_possession(GameConstants.FIELD_YARDS - ball_yard, "turnover on downs at the %d" % ball_yard)
        return

    await get_tree().create_timer(1.15).timeout
    if state == PlayState.DEAD:
        _prepare_play()

func _score_touchdown() -> void:
    scores[offense_team] += 7
    _refresh_score()
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
    scoreboard.show_result(_result_title(), "\n".join(PackedStringArray(possession_log)))

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

func _result_title() -> String:
    var winner: int = 0 if scores[0] > scores[1] else 1
    return "%s WIN %d – %d" % [teams[winner]["short"], scores[winner], scores[1 - winner]]

func _refresh_score() -> void:
    scoreboard.update_score(scores[0], scores[1], teams[0]["short"], teams[1]["short"])

func _on_restart() -> void:
    if mode == BattleSettings.Mode.AUTO_RESOLVE:
        _auto_resolve()
    else:
        _start_battle()

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
