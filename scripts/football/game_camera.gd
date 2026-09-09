extends Camera2D

const GameConstants = preload("res://scripts/core/game_constants.gd")

enum ViewMode { SIDELINE, BEHIND_QB }

const SIDELINE_ZOOM: Vector2 = Vector2(1.0, 1.0)
const BEHIND_QB_ZOOM: Vector2 = Vector2(0.55, 0.55)
const BEHIND_QB_FORWARD_OFFSET: float = 170.0
const FOLLOW_SHARPNESS: float = 8.0

var view_mode: int = ViewMode.SIDELINE
var target: Node2D = null

func _ready() -> void:
    var center: Vector2 = GameConstants.SCREEN_SIZE * 0.5
    position = center
    zoom = SIDELINE_ZOOM
    make_current()

func set_view_mode(mode: int) -> void:
    view_mode = mode

func set_target(node: Node2D) -> void:
    target = node

func _process(delta: float) -> void:
    var desired_position: Vector2 = GameConstants.SCREEN_SIZE * 0.5
    var desired_zoom: Vector2 = SIDELINE_ZOOM

    if view_mode == ViewMode.BEHIND_QB and target != null and is_instance_valid(target):
        desired_zoom = BEHIND_QB_ZOOM
        desired_position = target.global_position + Vector2(BEHIND_QB_FORWARD_OFFSET, 0.0)
        desired_position.x = clampf(
            desired_position.x,
            GameConstants.FIELD_RECT.position.x + 220.0,
            GameConstants.FIELD_RECT.end.x - 40.0
        )
        desired_position.y = clampf(
            desired_position.y,
            GameConstants.FIELD_TOP + 70.0,
            GameConstants.FIELD_BOTTOM - 70.0
        )

    var t: float = clampf(delta * FOLLOW_SHARPNESS, 0.0, 1.0)
    position = position.lerp(desired_position, t)
    zoom = zoom.lerp(desired_zoom, t)
