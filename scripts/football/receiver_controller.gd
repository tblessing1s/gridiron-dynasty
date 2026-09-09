extends "res://scripts/football/player_body.gd"

signal went_out_of_bounds(receiver)

var route_points: Array[Vector2] = []
var route_index: int = 0
var running_route: bool = false
var is_ball_carrier: bool = false
var carrier_input: Vector2 = Vector2.ZERO
var route_speed: float = 190.0
var carrier_speed: float = 235.0
var auto_forward_weight: float = 0.72

func _ready() -> void:
    body_color = Color("2f77c7")
    label_text = "WR"
    super()

func start_route(points: Array[Vector2]) -> void:
    route_points = points
    route_index = 0
    running_route = true
    is_ball_carrier = false
    carrier_input = Vector2.ZERO

func stop_route() -> void:
    running_route = false
    velocity = Vector2.ZERO

func become_ball_carrier() -> void:
    running_route = false
    is_ball_carrier = true
    body_color = Color("35a85b")
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
    is_ball_carrier = false
    carrier_input = Vector2.ZERO
    body_color = Color("2f77c7")
    queue_redraw()

func _physics_process(_delta: float) -> void:
    if is_ball_carrier:
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
            keyboard = keyboard.normalized()

        var steer: Vector2 = carrier_input
        if keyboard.length() > 0.05:
            steer = keyboard

        var desired: Vector2 = Vector2.RIGHT
        if steer.length() > 0.05:
            desired = (Vector2.RIGHT * auto_forward_weight + steer * (1.0 - auto_forward_weight)).normalized()

        velocity = desired * carrier_speed
        move_and_slide()
        global_position.y = clampf(global_position.y, GameConstants.FIELD_TOP - 8.0, GameConstants.FIELD_BOTTOM + 8.0)
        if global_position.y < GameConstants.FIELD_TOP + GameConstants.OUT_OF_BOUNDS_MARGIN or global_position.y > GameConstants.FIELD_BOTTOM - GameConstants.OUT_OF_BOUNDS_MARGIN:
            went_out_of_bounds.emit(self)
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
