extends "res://scripts/football/player_body.gd"

signal throw_requested(direction: Vector2, strength: float)
signal aim_updated(direction: Vector2, strength: float)
signal aim_cancelled

var aiming: bool = false
var aim_start: Vector2 = Vector2.ZERO
var can_throw: bool = true
const MAX_DRAG: float = 260.0
const MIN_THROW_DRAG: float = 35.0

func _ready() -> void:
    body_color = Color("2f77c7")
    label_text = "QB"
    super()

func _unhandled_input(event: InputEvent) -> void:
    if not can_throw:
        return

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _begin_aim(event.position)
        elif aiming:
            _release_aim(event.position)
        return

    if event is InputEventMouseMotion and aiming:
        _update_aim(event.position)
        return

    if event is InputEventScreenTouch:
        if event.pressed:
            _begin_aim(event.position)
        elif aiming:
            _release_aim(event.position)
        return

    if event is InputEventScreenDrag and aiming:
        _update_aim(event.position)

func _begin_aim(screen_pos: Vector2) -> void:
    if global_position.distance_to(screen_pos) <= 55.0:
        aiming = true
        aim_start = global_position
        aim_updated.emit(Vector2.RIGHT, 0.0)

func _update_aim(screen_pos: Vector2) -> void:
    var drag: Vector2 = screen_pos - aim_start
    var distance: float = minf(drag.length(), MAX_DRAG)
    if distance <= 0.001:
        return
    aim_updated.emit(drag.normalized(), distance / MAX_DRAG)

func _release_aim(screen_pos: Vector2) -> void:
    var drag: Vector2 = screen_pos - aim_start
    aiming = false
    if drag.length() < MIN_THROW_DRAG:
        aim_cancelled.emit()
        return
    var direction: Vector2 = drag.normalized()
    var strength: float = clampf(drag.length() / MAX_DRAG, 0.25, 1.0)
    can_throw = false
    throw_requested.emit(direction, strength)

func reset_for_play(pos: Vector2) -> void:
    global_position = pos
    velocity = Vector2.ZERO
    aiming = false
    can_throw = true
