extends "res://scripts/football/player_body.gd"

var covered_receiver = null
var ball_carrier = null
var coverage_offset: Vector2 = Vector2(12.0, 18.0)
var coverage_speed: float = 175.0
var pursuit_speed: float = 205.0
var watched_football = null
var ai_enabled: bool = false

func _ready() -> void:
    body_color = Color("c14949")
    outline_color = Color("ffd7d7")
    if label_text == "P":
        label_text = "D"
    super()

func reset_for_play(pos: Vector2, receiver) -> void:
    global_position = pos
    velocity = Vector2.ZERO
    covered_receiver = receiver
    ball_carrier = null
    watched_football = null
    ai_enabled = false

func set_ai_enabled(enabled: bool) -> void:
    ai_enabled = enabled
    if not ai_enabled:
        velocity = Vector2.ZERO

func set_ball_carrier(carrier) -> void:
    ball_carrier = carrier

func watch_ball(ball) -> void:
    watched_football = ball

func _physics_process(_delta: float) -> void:
    if not ai_enabled:
        velocity = Vector2.ZERO
        return
    var target: Vector2 = global_position
    var speed: float = coverage_speed

    if ball_carrier != null and is_instance_valid(ball_carrier):
        target = ball_carrier.global_position
        speed = pursuit_speed
    elif watched_football != null and is_instance_valid(watched_football) and watched_football.is_airborne:
        var coverage_target: Vector2 = global_position
        if covered_receiver != null and is_instance_valid(covered_receiver):
            coverage_target = covered_receiver.global_position + coverage_offset
        target = coverage_target.lerp(watched_football.global_position, 0.38)
    elif covered_receiver != null and is_instance_valid(covered_receiver):
        target = covered_receiver.global_position + coverage_offset

    var difference: Vector2 = target - global_position
    if difference.length() > 3.0:
        velocity = difference.normalized() * speed
        move_and_slide()
    else:
        velocity = Vector2.ZERO
