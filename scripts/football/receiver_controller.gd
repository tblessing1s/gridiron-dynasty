extends "res://scripts/football/player_body.gd"

const Rosters = preload("res://scripts/core/rosters.gd")

signal went_out_of_bounds(receiver)

var route_points: PackedVector2Array = PackedVector2Array()
var route_index: int = 0
var running_route: bool = false
var is_ball_carrier: bool = false
var carrier_input: Vector2 = Vector2.ZERO
var route_speed: float = 190.0
var carrier_speed: float = 235.0
var auto_forward_weight: float = 0.72
var ai_forward_weight: float = 0.55
var catch_radius: float = GameConstants.CATCH_RADIUS
var team_color: Color = Color("2f77c7")
var chasing_ball: bool = false
var ball_target: Vector2 = Vector2.ZERO
var defenders: Array = []
var user_control_allowed: bool = false

func _ready() -> void:
    body_color = team_color
    if label_text == "P":
        label_text = "WR"
    super()

func _on_stats_applied() -> void:
    var speed_ratio: float = float(stat("speed")) / 100.0
    route_speed = lerpf(125.0, 195.0, speed_ratio)
    carrier_speed = lerpf(165.0, 250.0, speed_ratio)
    catch_radius = Rosters.catch_radius(stat("skill"))

func set_team_color(color: Color) -> void:
    team_color = color
    body_color = color
    queue_redraw()

func start_route(points: PackedVector2Array) -> void:
    route_points = points
    route_index = 0
    running_route = true
    chasing_ball = false
    is_ball_carrier = false
    carrier_input = Vector2.ZERO

func chase_ball(target: Vector2) -> void:
    running_route = false
    chasing_ball = true
    ball_target = target

func stop_route() -> void:
    running_route = false
    chasing_ball = false
    velocity = Vector2.ZERO

func become_ball_carrier() -> void:
    running_route = false
    chasing_ball = false
    is_ball_carrier = true
    body_color = team_color.lightened(0.35)
    queue_redraw()

func set_carrier_input(input_dir: Vector2) -> void:
    if input_dir.length() > 0.05:
        carrier_input = input_dir.normalized()
    else:
        carrier_input = Vector2.ZERO

func reset_for_play(pos: Vector2) -> void:
    global_position = pos
    velocity = Vector2.ZERO
    route_points.clear()
    route_index = 0
    running_route = false
    chasing_ball = false
    is_ball_carrier = false
    carrier_input = Vector2.ZERO
    body_color = team_color
    queue_redraw()

func _physics_process(_delta: float) -> void:
    if is_ball_carrier:
        _run_with_ball()
        return

    if chasing_ball:
        var to_ball: Vector2 = ball_target - global_position
        if to_ball.length() < 4.0:
            velocity = Vector2.ZERO
            return
        velocity = to_ball.normalized() * route_speed * 1.05
        move_and_slide()
        return

    if not running_route or route_points.is_empty():
        velocity = Vector2.ZERO
        return

    var target: Vector2 = route_points[route_index]
    var to_target: Vector2 = target - global_position
    if to_target.length() < 12.0:
        route_index += 1
        if route_index >= route_points.size():
            running_route = false
            velocity = Vector2.ZERO
            return
        target = route_points[route_index]
        to_target = target - global_position

    velocity = to_target.normalized() * route_speed
    move_and_slide()

func _run_with_ball() -> void:
    var steer: Vector2 = Vector2.ZERO
    var forward_weight: float = ai_forward_weight
    if user_control_allowed:
        var horizontal: float = 0.0
        var vertical: float = 0.0
        if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
            horizontal += 1.0
        if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
            horizontal -= 1.0
        if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
            vertical += 1.0
        if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
            vertical -= 1.0
        var keyboard: Vector2 = Vector2(horizontal, vertical)
        if keyboard.length() > 0.05:
            steer = keyboard.normalized()
        elif carrier_input.length() > 0.05:
            steer = carrier_input
        if steer.length() > 0.05:
            forward_weight = auto_forward_weight

    if steer.length() < 0.05:
        steer = _ai_steer()

    var desired: Vector2 = Vector2.RIGHT
    if steer.length() > 0.05:
        desired = (Vector2.RIGHT * forward_weight + steer * (1.0 - forward_weight)).normalized()

    velocity = desired * carrier_speed
    move_and_slide()
    global_position.y = clampf(global_position.y, GameConstants.FIELD_TOP - 8.0, GameConstants.FIELD_BOTTOM + 8.0)
    if global_position.y < GameConstants.FIELD_TOP + GameConstants.OUT_OF_BOUNDS_MARGIN or global_position.y > GameConstants.FIELD_BOTTOM - GameConstants.OUT_OF_BOUNDS_MARGIN:
        went_out_of_bounds.emit(self)

# Runs away from the nearest defender ahead of the ball and stays off the
# sidelines, so an unsteered carrier still finds a lane.
func _ai_steer() -> Vector2:
    var threat = null
    var best_distance: float = INF
    for defender in defenders:
        if not is_instance_valid(defender):
            continue
        if defender.global_position.x < global_position.x - 20.0:
            continue
        var distance: float = defender.global_position.distance_to(global_position)
        if distance < best_distance:
            best_distance = distance
            threat = defender

    var lateral: float = 0.0
    if threat != null and best_distance < 130.0:
        lateral = signf(global_position.y - threat.global_position.y)
        if lateral == 0.0:
            lateral = 1.0
    else:
        var center_y: float = (GameConstants.FIELD_TOP + GameConstants.FIELD_BOTTOM) * 0.5
        lateral = signf(center_y - global_position.y) * 0.3

    if global_position.y < GameConstants.FIELD_TOP + 70.0:
        lateral = 1.0
    elif global_position.y > GameConstants.FIELD_BOTTOM - 70.0:
        lateral = -1.0

    if absf(lateral) < 0.05:
        return Vector2.ZERO
    return Vector2(0.15, lateral).normalized()
