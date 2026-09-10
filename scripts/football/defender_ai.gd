extends "res://scripts/football/player_body.gd"

const Rosters = preload("res://scripts/core/rosters.gd")

enum Role { CORNER, SAFETY, LINEBACKER, RUSHER }
enum Assignment { COVER, BLITZ, SPY }

const BLOCK_RADIUS: float = 34.0

var role: int = Role.CORNER
var assignment: int = Assignment.COVER
var covered_receiver = null
var spy_target = null
var blocker = null
var quarterback = null
var ball_carrier = null
var watched_football = null
var receivers: Array = []
var coverage_offset: Vector2 = Vector2(20.0, 24.0)
var offset_scale: float = 1.0
var coverage_speed: float = 175.0
var pursuit_speed: float = 205.0
var rush_speed: float = 190.0
var ai_enabled: bool = false
var pocket_seconds: float = 2.5
var rush_elapsed: float = 0.0
var shed_seconds: float = 0.0
var intercept_radius: float = 22.0
var line_x: float = 0.0

func _ready() -> void:
    body_color = Color("c14949")
    outline_color = Color("ffd7d7")
    if label_text == "P":
        label_text = "D"
    super()

func _on_stats_applied() -> void:
    var speed_ratio: float = float(stat("speed")) / 100.0
    coverage_speed = lerpf(140.0, 220.0, speed_ratio)
    pursuit_speed = lerpf(182.0, 272.0, speed_ratio)
    rush_speed = lerpf(140.0, 210.0, speed_ratio)
    intercept_radius = Rosters.intercept_radius(stat("skill"))

func reset_for_play(pos: Vector2) -> void:
    global_position = pos
    velocity = Vector2.ZERO
    ball_carrier = null
    watched_football = null
    ai_enabled = false
    rush_elapsed = 0.0
    shed_seconds = 0.0

func set_ai_enabled(enabled: bool) -> void:
    ai_enabled = enabled
    if not ai_enabled:
        velocity = Vector2.ZERO

func set_ball_carrier(carrier) -> void:
    ball_carrier = carrier

func watch_ball(ball) -> void:
    watched_football = ball

func is_rushing() -> bool:
    return role == Role.RUSHER or (role == Role.LINEBACKER and assignment == Assignment.BLITZ)

func rush_released() -> bool:
    return is_rushing() and rush_elapsed >= pocket_seconds

func can_tackle() -> bool:
    return shed_seconds <= 0.0

func _physics_process(delta: float) -> void:
    shed_seconds = maxf(shed_seconds - delta, 0.0)
    if not ai_enabled:
        velocity = Vector2.ZERO
        return

    var target: Vector2 = global_position
    var speed: float = coverage_speed

    if ball_carrier != null and is_instance_valid(ball_carrier):
        target = ball_carrier.global_position
        speed = pursuit_speed
        if shed_seconds > 0.0:
            speed *= 0.4
    elif watched_football != null and is_instance_valid(watched_football) and watched_football.is_airborne:
        # Break on the ball: defenders drive toward where it will land, not
        # where it is, so throws into coverage get contested.
        var landing: Vector2 = watched_football.end_position
        var weight: float = 0.85 if is_rushing() == false else 0.35
        target = _coverage_point().lerp(landing, weight)
        speed = pursuit_speed
    elif is_rushing():
        rush_elapsed += delta
        speed = rush_speed
        if rush_elapsed >= pocket_seconds or quarterback == null:
            if quarterback != null and is_instance_valid(quarterback):
                target = quarterback.global_position
        elif blocker != null and is_instance_valid(blocker):
            target = blocker.global_position + Vector2(34.0, 0.0)
        else:
            target = Vector2(line_x + 30.0, global_position.y)
    else:
        target = _coverage_point()

    # A blocker standing on top of a defender slows him badly; there are no
    # collisions, so this is what makes the blocker matter.
    if blocker != null and is_instance_valid(blocker) and blocker.global_position.distance_to(global_position) <= BLOCK_RADIUS:
        speed *= 0.3

    var difference: Vector2 = target - global_position
    if difference.length() > 3.0:
        velocity = difference.normalized() * speed
        move_and_slide()
    else:
        velocity = Vector2.ZERO

func _coverage_point() -> Vector2:
    if role == Role.CORNER:
        if covered_receiver != null and is_instance_valid(covered_receiver):
            return covered_receiver.global_position + coverage_offset * offset_scale
        return global_position

    if role == Role.SAFETY:
        var deepest = _deepest_receiver()
        var center_y: float = (GameConstants.FIELD_TOP + GameConstants.FIELD_BOTTOM) * 0.5
        if deepest == null:
            return Vector2(line_x + 170.0, center_y)
        var deep_x: float = maxf(deepest.global_position.x + 45.0, line_x + 150.0)
        return Vector2(deep_x, lerpf(center_y, deepest.global_position.y, 0.6))

    if role == Role.LINEBACKER:
        if assignment == Assignment.SPY and spy_target != null and is_instance_valid(spy_target):
            return spy_target.global_position + Vector2(24.0, 0.0)
        var zone: Vector2 = Vector2(line_x + 70.0, (GameConstants.FIELD_TOP + GameConstants.FIELD_BOTTOM) * 0.5)
        var nearest = _nearest_receiver(zone, 110.0)
        if nearest != null:
            return zone.lerp(nearest.global_position, 0.6)
        return zone

    return global_position

func _deepest_receiver():
    var deepest = null
    var deepest_x: float = -INF
    for receiver in receivers:
        if not is_instance_valid(receiver):
            continue
        if receiver.global_position.x > deepest_x:
            deepest_x = receiver.global_position.x
            deepest = receiver
    return deepest

func _nearest_receiver(point: Vector2, max_distance: float):
    var nearest = null
    var nearest_distance: float = max_distance
    for receiver in receivers:
        if not is_instance_valid(receiver):
            continue
        var distance: float = receiver.global_position.distance_to(point)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = receiver
    return nearest
