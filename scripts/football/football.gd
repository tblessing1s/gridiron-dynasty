extends Node2D

const GameConstants = preload("res://scripts/core/game_constants.gd")

signal pass_finished(caught_by)
signal pass_incomplete
signal pass_intercepted(defender)

const CATCHABLE_T: float = 0.72

var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var duration: float = 0.8
var is_airborne: bool = false
var receivers: Array = []
var defenders: Array = []
var peak_height: float = 1.0

func _ready() -> void:
    z_index = 20
    queue_redraw()

func launch_to(origin: Vector2, target: Vector2, eligible_receivers: Array, covering_defenders: Array) -> void:
    start_position = origin
    global_position = origin
    receivers = eligible_receivers
    defenders = covering_defenders
    elapsed = 0.0
    is_airborne = true
    end_position = target
    end_position.x = clampf(end_position.x, GameConstants.LEFT_GOAL_X, GameConstants.RIGHT_GOAL_X + 40.0)
    end_position.y = clampf(end_position.y, GameConstants.FIELD_TOP, GameConstants.FIELD_BOTTOM)
    var distance: float = origin.distance_to(end_position)
    duration = lerpf(0.5, 1.2, clampf(distance / 470.0, 0.0, 1.0))
    visible = true

func _process(delta: float) -> void:
    if not is_airborne:
        return

    elapsed += delta
    var t: float = clampf(elapsed / duration, 0.0, 1.0)
    global_position = start_position.lerp(end_position, t)
    peak_height = 1.0 + sin(t * PI) * 0.65
    queue_redraw()

    # The ball is only catchable on the way down. Whoever is closest to it
    # wins the arrival: a defender who beats the receiver to the spot picks
    # it off or knocks it down.
    if t >= CATCHABLE_T:
        var receiver = _nearest_within(receivers, true)
        var defender = _nearest_within(defenders, false)
        if receiver != null:
            var receiver_distance: float = receiver.global_position.distance_to(global_position)
            if defender != null and defender.global_position.distance_to(global_position) < receiver_distance:
                if defender.global_position.distance_to(global_position) <= defender.intercept_radius * 0.6:
                    _intercept(defender)
                else:
                    _finish_incomplete()
                return
            _complete(receiver)
            return
        if defender != null and defender.global_position.distance_to(global_position) <= defender.intercept_radius * 0.6:
            _intercept(defender)
            return

    if t >= 1.0:
        _finish_incomplete()

func _nearest_within(candidates: Array, use_catch_radius: bool):
    var nearest = null
    var nearest_distance: float = INF
    for candidate in candidates:
        if not is_instance_valid(candidate):
            continue
        var radius: float = candidate.catch_radius if use_catch_radius else candidate.intercept_radius
        var distance: float = candidate.global_position.distance_to(global_position)
        if distance <= radius and distance < nearest_distance:
            nearest_distance = distance
            nearest = candidate
    return nearest

func _complete(receiver) -> void:
    is_airborne = false
    visible = false
    pass_finished.emit(receiver)

func _intercept(defender) -> void:
    is_airborne = false
    visible = false
    pass_intercepted.emit(defender)

func _finish_incomplete() -> void:
    is_airborne = false
    visible = true
    queue_redraw()
    pass_incomplete.emit()

func _draw() -> void:
    if not visible:
        return
    var shadow_offset: Vector2 = Vector2(5.0, 7.0) * peak_height
    _draw_ellipse(shadow_offset, Vector2(8.0, 4.0), Color(0.0, 0.0, 0.0, 0.35))
    _draw_ellipse(Vector2.ZERO, Vector2(8.0, 5.0) * peak_height, Color("6b3b1e"))
    draw_line(Vector2(-3.0, -1.0), Vector2(3.0, 1.0), Color.WHITE, 1.2)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
    var points: PackedVector2Array = PackedVector2Array()
    var segments: int = 18
    for i in range(segments):
        var angle: float = TAU * float(i) / float(segments)
        points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
    draw_colored_polygon(points, color)
