extends Node2D

const GameConstants = preload("res://scripts/core/game_constants.gd")

signal pass_finished(caught_by)
signal pass_incomplete

var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var duration: float = 0.8
var is_airborne: bool = false
var receivers: Array = []
var accuracy_radius: float = GameConstants.CATCH_RADIUS
var peak_height: float = 1.0

func _ready() -> void:
    z_index = 20
    queue_redraw()

func launch(origin: Vector2, direction: Vector2, strength: float, eligible_receivers: Array) -> void:
    start_position = origin
    global_position = origin
    receivers = eligible_receivers
    elapsed = 0.0
    is_airborne = true
    duration = lerpf(0.55, 1.15, strength)
    var throw_distance: float = lerpf(165.0, 470.0, strength)
    end_position = origin + direction * throw_distance
    end_position.x = clampf(end_position.x, GameConstants.LEFT_GOAL_X, GameConstants.RIGHT_GOAL_X + 40.0)
    end_position.y = clampf(end_position.y, GameConstants.FIELD_TOP, GameConstants.FIELD_BOTTOM)
    visible = true

func _process(delta: float) -> void:
    if not is_airborne:
        return

    elapsed += delta
    var t: float = clampf(elapsed / duration, 0.0, 1.0)
    global_position = start_position.lerp(end_position, t)
    peak_height = 1.0 + sin(t * PI) * 0.65
    queue_redraw()

    if t > 0.42:
        for receiver in receivers:
            if is_instance_valid(receiver) and receiver.global_position.distance_to(global_position) <= accuracy_radius:
                _complete(receiver)
                return

    if t >= 1.0:
        _finish_incomplete()

func _complete(receiver) -> void:
    is_airborne = false
    visible = false
    pass_finished.emit(receiver)

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
