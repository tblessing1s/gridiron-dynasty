extends Node2D

const GameConstants = preload("res://scripts/core/game_constants.gd")
const FieldViewScript = preload("res://scripts/football/field_view.gd")
const QuarterbackScript = preload("res://scripts/football/quarterback_controller.gd")
const ReceiverScript = preload("res://scripts/football/receiver_controller.gd")
const DefenderScript = preload("res://scripts/football/defender_ai.gd")
const FootballScript = preload("res://scripts/football/football.gd")
const ScoreboardScript = preload("res://scripts/ui/scoreboard.gd")
const PerspectiveViewScript = preload("res://scripts/football/perspective_view.gd")

# Phase 1 vertical slice: one offensive drive with passing, routes, defense,
# catches, user-controlled YAC, downs, first downs, touchdown, clock, and reset.

enum PlayState { PRE_SNAP, AIMING, LIVE_PASS, LIVE_RUN, DEAD, DRIVE_OVER }
enum ViewMode { SIDELINE, BEHIND_QB }

var state: int = PlayState.PRE_SNAP
var view_mode: int = ViewMode.SIDELINE
var world_view: Node2D
var field
var scoreboard
var perspective_view
var qb
var receivers: Array = []
var defenders: Array = []
var football
var aim_line: Line2D

var home_score: int = 0
var away_score: int = 0
var down: int = 1
var yards_to_go: int = 10
var ball_yard: int = 20
var line_of_scrimmage_x: float = GameConstants.STARTING_LOS_X
var first_down_x: float = GameConstants.STARTING_LOS_X + 100.0
var play_start_x: float = GameConstants.STARTING_LOS_X
var clock_seconds: float = 300.0
var current_carrier
var steer_touch_active: bool = false
var steer_origin: Vector2 = Vector2.ZERO
var play_resolution_pending: bool = false
var tackle_grace_seconds: float = 0.0

func _ready() -> void:
    _build_world()
    _start_new_drive()

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

    qb = QuarterbackScript.new()
    qb.aim_started.connect(_on_aim_started)
    qb.throw_requested.connect(_on_throw_requested)
    qb.aim_updated.connect(_on_aim_updated)
    qb.aim_cancelled.connect(_on_aim_cancelled)
    world_view.add_child(qb)

    for i in range(2):
        var receiver = ReceiverScript.new()
        receiver.label_text = "WR%d" % (i + 1)
        receiver.went_out_of_bounds.connect(_on_receiver_out_of_bounds)
        world_view.add_child(receiver)
        receivers.append(receiver)

    for i in range(4):
        var defender = DefenderScript.new()
        defender.label_text = "D%d" % (i + 1)
        world_view.add_child(defender)
        defenders.append(defender)

    football = FootballScript.new()
    football.pass_finished.connect(_on_pass_caught)
    football.pass_incomplete.connect(_on_pass_incomplete)
    world_view.add_child(football)

    perspective_view = PerspectiveViewScript.new()
    perspective_view.configure(qb, receivers, defenders, football)
    perspective_view.visible = false
    qb.set_perspective_view(perspective_view)
    add_child(perspective_view)

    scoreboard = ScoreboardScript.new()
    scoreboard.restart_drive_requested.connect(_start_new_drive)
    scoreboard.back_to_menu_requested.connect(_back_to_menu)
    scoreboard.view_mode_toggle_requested.connect(_on_view_mode_toggle_requested)
    add_child(scoreboard)

func _start_new_drive() -> void:
    home_score = 0
    down = 1
    yards_to_go = 10
    ball_yard = 20
    line_of_scrimmage_x = GameConstants.LEFT_GOAL_X + float(ball_yard) * GameConstants.PIXELS_PER_YARD
    first_down_x = line_of_scrimmage_x + float(yards_to_go) * GameConstants.PIXELS_PER_YARD
    clock_seconds = 300.0
    current_carrier = null
    play_resolution_pending = false
    scoreboard.hide_drive_result()
    scoreboard.update_score(home_score, away_score)
    scoreboard.update_clock(clock_seconds)
    _prepare_play("Touch the QB and drag toward a receiver to throw.")

func _prepare_play(message: String = "") -> void:
    state = PlayState.PRE_SNAP
    current_carrier = null
    steer_touch_active = false
    play_resolution_pending = false
    tackle_grace_seconds = 0.0
    play_start_x = line_of_scrimmage_x
    first_down_x = line_of_scrimmage_x + float(yards_to_go) * GameConstants.PIXELS_PER_YARD
    field.set_markers(line_of_scrimmage_x, first_down_x)
    perspective_view.update_markers(line_of_scrimmage_x, first_down_x)
    perspective_view.set_target(qb)

    qb.reset_for_play(Vector2(line_of_scrimmage_x - 55.0, 390.0))
    receivers[0].reset_for_play(Vector2(line_of_scrimmage_x - 4.0, 245.0))
    receivers[1].reset_for_play(Vector2(line_of_scrimmage_x - 4.0, 540.0))

    # Defenders align over the receivers plus two shallow zone defenders.
    defenders[0].reset_for_play(Vector2(line_of_scrimmage_x + 55.0, 245.0), receivers[0])
    defenders[0].coverage_offset = Vector2(20, 24)
    defenders[1].reset_for_play(Vector2(line_of_scrimmage_x + 55.0, 540.0), receivers[1])
    defenders[1].coverage_offset = Vector2(20, -24)
    defenders[2].reset_for_play(Vector2(line_of_scrimmage_x + 115.0, 340.0), receivers[0])
    defenders[2].coverage_offset = Vector2(85, 90)
    defenders[3].reset_for_play(Vector2(line_of_scrimmage_x + 125.0, 455.0), receivers[1])
    defenders[3].coverage_offset = Vector2(85, -90)

    field.set_route_previews(_build_routes())

    football.visible = false
    football.is_airborne = false
    aim_line.visible = false
    aim_line.clear_points()

    scoreboard.update_situation(down, yards_to_go, ball_yard)
    scoreboard.set_message(message if not message.is_empty() else "Touch the QB and drag to aim.")

func _begin_routes() -> void:
    var routes: Array[PackedVector2Array] = _build_routes()
    receivers[0].start_route(routes[0])
    receivers[1].start_route(routes[1])
    field.clear_route_previews()

func _build_routes() -> Array[PackedVector2Array]:
    var max_x: float = GameConstants.RIGHT_GOAL_X + 10.0
    var route_one: PackedVector2Array = PackedVector2Array([
        Vector2(minf(line_of_scrimmage_x + 120.0, max_x), 245.0),
        Vector2(minf(line_of_scrimmage_x + 245.0, max_x), 330.0),
        Vector2(minf(line_of_scrimmage_x + 390.0, max_x), 330.0)
    ])
    var route_two: PackedVector2Array = PackedVector2Array([
        Vector2(minf(line_of_scrimmage_x + 150.0, max_x), 540.0),
        Vector2(minf(line_of_scrimmage_x + 275.0, max_x), 475.0),
        Vector2(minf(line_of_scrimmage_x + 430.0, max_x), 475.0)
    ])
    var routes: Array[PackedVector2Array] = [route_one, route_two]
    return routes

func _on_aim_updated(direction: Vector2, strength: float) -> void:
    if state != PlayState.AIMING:
        return
    _update_projected_arc(direction, strength)

func _on_aim_started() -> void:
    if state == PlayState.PRE_SNAP:
        # Pressing the QB is the snap. Routes, coverage, and the clock all begin
        # while the player is still holding and aiming; release launches the ball.
        state = PlayState.AIMING
        _begin_routes()
        for defender in defenders:
            defender.set_ai_enabled(true)
        scoreboard.set_message("Play live • Hold and drag to lead a receiver • Release to throw")

func _update_projected_arc(direction: Vector2, strength: float) -> void:
    aim_line.clear_points()
    var origin: Vector2 = qb.global_position
    var throw_distance: float = lerpf(165.0, 470.0, maxf(strength, 0.2))
    var target: Vector2 = origin + direction * throw_distance
    target.x = clampf(target.x, GameConstants.LEFT_GOAL_X, GameConstants.RIGHT_GOAL_X + 40.0)
    target.y = clampf(target.y, GameConstants.FIELD_TOP, GameConstants.FIELD_BOTTOM)

    var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
    for i in range(18):
        var t: float = float(i) / 17.0
        var point: Vector2 = origin.lerp(target, t)
        point += perpendicular * sin(t * PI) * 14.0
        aim_line.add_point(point)
    aim_line.visible = true

func _on_aim_cancelled() -> void:
    aim_line.visible = false
    aim_line.clear_points()
    if state == PlayState.AIMING:
        scoreboard.set_message("Throw cancelled • Touch the QB, drag, and release")

func _on_throw_requested(direction: Vector2, strength: float) -> void:
    if state != PlayState.AIMING:
        return
    state = PlayState.LIVE_PASS
    aim_line.visible = false
    aim_line.clear_points()
    football.launch(qb.global_position + Vector2(20, 0), direction, strength, receivers)
    for defender in defenders:
        defender.set_ai_enabled(true)
        defender.watch_ball(football)
    scoreboard.set_message("Pass in the air…")

func _on_pass_caught(receiver) -> void:
    if state != PlayState.LIVE_PASS:
        return
    current_carrier = receiver
    tackle_grace_seconds = 0.32
    current_carrier.become_ball_carrier()
    perspective_view.set_target(current_carrier)
    state = PlayState.LIVE_RUN
    for other_receiver in receivers:
        if other_receiver != receiver:
            other_receiver.stop_route()
    for defender in defenders:
        defender.set_ball_carrier(receiver)
    scoreboard.set_message("Caught! Drag to steer the runner toward the end zone.")

func _on_pass_incomplete() -> void:
    if state != PlayState.LIVE_PASS:
        return
    scoreboard.set_message("Incomplete pass")
    _finish_play(play_start_x, false, "INCOMPLETE")

func _physics_process(delta: float) -> void:
    if state == PlayState.AIMING or state == PlayState.LIVE_PASS or state == PlayState.LIVE_RUN:
        clock_seconds = maxf(clock_seconds - delta, 0.0)
        scoreboard.update_clock(clock_seconds)
        if clock_seconds <= 0.0:
            _end_drive("TIME EXPIRED", "The drive ended when the game clock reached 0:00.")
            return

    if state != PlayState.LIVE_RUN or current_carrier == null or play_resolution_pending:
        return

    tackle_grace_seconds = maxf(tackle_grace_seconds - delta, 0.0)

    # Touchdown.
    if current_carrier.global_position.x >= GameConstants.RIGHT_GOAL_X:
        home_score += 7
        scoreboard.update_score(home_score, away_score)
        _end_drive("TOUCHDOWN!", "You completed the Phase 1 drive and reached the end zone.")
        return

    # Tackles.
    for defender in defenders:
        if tackle_grace_seconds > 0.0:
            break
        if defender.global_position.distance_to(current_carrier.global_position) <= GameConstants.TACKLE_RADIUS:
            _finish_play(current_carrier.global_position.x, true, "TACKLED")
            return

func _unhandled_input(event: InputEvent) -> void:
    if state != PlayState.LIVE_RUN or current_carrier == null:
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
    if view_mode == ViewMode.BEHIND_QB:
        return perspective_view.unproject(screen_pos)
    return get_viewport().canvas_transform.affine_inverse() * screen_pos

func _on_receiver_out_of_bounds(receiver) -> void:
    if state == PlayState.LIVE_RUN and receiver == current_carrier and not play_resolution_pending:
        _finish_play(receiver.global_position.x, true, "OUT OF BOUNDS")

func _finish_play(end_x: float, caught: bool, result_text: String) -> void:
    if play_resolution_pending or state == PlayState.DRIVE_OVER:
        return
    play_resolution_pending = true
    state = PlayState.DEAD
    qb.can_throw = false
    for receiver in receivers:
        receiver.stop_route()
        receiver.is_ball_carrier = false
    for defender in defenders:
        defender.set_ai_enabled(false)
        defender.ball_carrier = null

    var gained_yards: int = 0
    if caught:
        gained_yards = int(round((end_x - play_start_x) / GameConstants.PIXELS_PER_YARD))
        gained_yards = maxi(gained_yards, 0)

    var new_ball_yard: int = clampi(ball_yard + gained_yards, 0, 99)
    var reached_first_down: bool = end_x >= first_down_x

    if reached_first_down:
        ball_yard = new_ball_yard
        down = 1
        yards_to_go = mini(10, 100 - ball_yard)
        line_of_scrimmage_x = GameConstants.LEFT_GOAL_X + float(ball_yard) * GameConstants.PIXELS_PER_YARD
        scoreboard.set_message("%s • %d yards • FIRST DOWN" % [result_text, gained_yards])
    else:
        ball_yard = new_ball_yard
        down += 1
        var remaining_pixels: float = maxf(first_down_x - (GameConstants.LEFT_GOAL_X + float(ball_yard) * GameConstants.PIXELS_PER_YARD), 0.0)
        yards_to_go = maxi(int(ceil(remaining_pixels / GameConstants.PIXELS_PER_YARD)), 1)
        line_of_scrimmage_x = GameConstants.LEFT_GOAL_X + float(ball_yard) * GameConstants.PIXELS_PER_YARD
        scoreboard.set_message("%s • %d yards" % [result_text, gained_yards])

    scoreboard.update_situation(mini(down, 4), yards_to_go, ball_yard)

    if down > 4:
        _end_drive("TURNOVER ON DOWNS", "The defense stopped the drive before you reached the end zone.")
        return

    await get_tree().create_timer(1.15).timeout
    if state != PlayState.DRIVE_OVER:
        _prepare_play()

func _end_drive(title: String, detail: String) -> void:
    state = PlayState.DRIVE_OVER
    play_resolution_pending = true
    qb.can_throw = false
    for receiver in receivers:
        receiver.running_route = false
        receiver.is_ball_carrier = false
        receiver.velocity = Vector2.ZERO
    for defender in defenders:
        defender.set_ai_enabled(false)
        defender.ball_carrier = null
    football.is_airborne = false
    scoreboard.show_drive_result(title, detail)

func _back_to_menu() -> void:
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_view_mode_toggle_requested() -> void:
    view_mode = ViewMode.BEHIND_QB if view_mode == ViewMode.SIDELINE else ViewMode.SIDELINE
    var is_behind_qb: bool = view_mode == ViewMode.BEHIND_QB
    world_view.visible = not is_behind_qb
    perspective_view.visible = is_behind_qb
    scoreboard.set_view_mode_label(is_behind_qb)
