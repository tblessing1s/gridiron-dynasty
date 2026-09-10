extends "res://scripts/football/player_body.gd"

signal throw_requested(direction: Vector2, strength: float)
signal aim_started
signal aim_updated(direction: Vector2, strength: float)
signal aim_cancelled

var aiming: bool = false
var aim_start: Vector2 = Vector2.ZERO
var can_throw: bool = true
var input_enabled: bool = false
const MAX_DRAG: float = 260.0
const MIN_THROW_DRAG: float = 35.0

func _ready() -> void:
    label_text = "QB"
    super()

func _unhandled_input(event: InputEvent) -> void:
    if not input_enabled or not can_throw:
        return

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _begin_aim(_to_world(event.position))
        elif aiming:
            _release_aim(_to_world(event.position))
        return

    if event is InputEventMouseMotion and aiming:
        _update_aim(_to_world(event.position))
        return

    if event is InputEventScreenTouch:
        if event.pressed:
            _begin_aim(_to_world(event.position))
        elif aiming:
            _release_aim(_to_world(event.position))
        return

    if event is InputEventScreenDrag and aiming:
        _update_aim(_to_world(event.position))

func _to_world(screen_pos: Vector2) -> Vector2:
    return get_viewport().canvas_transform.affine_inverse() * screen_pos

func _begin_aim(world_pos: Vector2) -> void:
    if global_position.distance_to(world_pos) <= 55.0:
        aiming = true
        aim_start = global_position
        aim_started.emit()
        aim_updated.emit(Vector2.RIGHT, 0.0)

# Slingshot aim: the ball flies opposite to the pull, so the player drags
# away from the receiver they want to hit.
func _update_aim(world_pos: Vector2) -> void:
    var drag: Vector2 = world_pos - aim_start
    var distance: float = minf(drag.length(), MAX_DRAG)
    if distance <= 0.001:
        return
    aim_updated.emit(-drag.normalized(), distance / MAX_DRAG)

func _release_aim(world_pos: Vector2) -> void:
    var drag: Vector2 = world_pos - aim_start
    aiming = false
    if drag.length() < MIN_THROW_DRAG:
        aim_cancelled.emit()
        return
    var direction: Vector2 = -drag.normalized()
    var strength: float = clampf(drag.length() / MAX_DRAG, 0.25, 1.0)
    can_throw = false
    throw_requested.emit(direction, strength)

func cancel_aim() -> void:
    if aiming:
        aiming = false
        aim_cancelled.emit()

func reset_for_play(pos: Vector2) -> void:
    global_position = pos
    velocity = Vector2.ZERO
    aiming = false
    can_throw = true
    input_enabled = false
