extends Node2D

const GameConstants = preload("res://scripts/core/game_constants.gd")

# A hand-rolled perspective projection so the "behind the QB" view can fake a
# Madden-style vanishing-point look while everything else in the game stays
# flat 2D shapes - there's no Camera3D or shader involved.

const HORIZON_Y: float = 190.0
const BASELINE_Y: float = 690.0
const VANISH_DEPTH: float = 260.0
const LATERAL_GAIN: float = 1.3
const MIN_SCALE: float = 0.12
const MAX_SCALE: float = 1.6
const MAX_YARD_DEPTH: float = 700.0
const MIN_YARD_DEPTH: float = -80.0

var target: Node2D = null
var qb_node: Node2D = null
var receivers: Array = []
var defenders: Array = []
var football_node: Node2D = null
var line_of_scrimmage_x: float = 0.0
var first_down_x: float = 0.0

func _ready() -> void:
    z_index = 15

func configure(qb: Node2D, receiver_list: Array, defender_list: Array, ball: Node2D) -> void:
    qb_node = qb
    receivers = receiver_list
    defenders = defender_list
    football_node = ball

func update_markers(los_x: float, first_x: float) -> void:
    line_of_scrimmage_x = los_x
    first_down_x = first_x

func set_target(node: Node2D) -> void:
    target = node

func _get_eye() -> Vector2:
    if target != null and is_instance_valid(target):
        return target.global_position
    return Vector2(line_of_scrimmage_x, (GameConstants.FIELD_TOP + GameConstants.FIELD_BOTTOM) * 0.5)

# Projects a world-space point to {pos, scale} in screen space. depth is the
# distance downfield of the current viewpoint (the QB, or the ball carrier
# once the ball is caught); lateral is the sideways offset from it. Both
# shrink toward the horizon's vanishing point as depth grows.
func project(world_pos: Vector2) -> Dictionary:
    var eye: Vector2 = _get_eye()
    var depth: float = world_pos.x - eye.x
    var lateral: float = world_pos.y - eye.y
    var s: float = clampf(VANISH_DEPTH / (VANISH_DEPTH + depth), MIN_SCALE, MAX_SCALE)
    var screen_center_x: float = GameConstants.SCREEN_SIZE.x * 0.5
    var screen_pos: Vector2 = Vector2(
        screen_center_x + lateral * LATERAL_GAIN * s,
        HORIZON_Y + (BASELINE_Y - HORIZON_Y) * s
    )
    return {"pos": screen_pos, "scale": s}

# Inverse of project(): turns a screen-space touch/click into the world
# position it visually corresponds to, so aiming/steering still lines up
# with what the player sees while this view is active.
func unproject(screen_pos: Vector2) -> Vector2:
    var eye: Vector2 = _get_eye()
    var s: float = clampf((screen_pos.y - HORIZON_Y) / (BASELINE_Y - HORIZON_Y), MIN_SCALE, MAX_SCALE)
    var depth: float = VANISH_DEPTH * (1.0 / s - 1.0)
    var screen_center_x: float = GameConstants.SCREEN_SIZE.x * 0.5
    var lateral: float = (screen_pos.x - screen_center_x) / (LATERAL_GAIN * s)
    return Vector2(eye.x + depth, eye.y + lateral)

func _process(_delta: float) -> void:
    if visible:
        queue_redraw()

func _draw() -> void:
    if qb_node == null:
        return

    _draw_field()

    for receiver in receivers:
        if is_instance_valid(receiver) and receiver.visible:
            _draw_player(receiver, receiver.body_color, receiver.label_text)
    for defender in defenders:
        if is_instance_valid(defender) and defender.visible:
            _draw_player(defender, defender.body_color, defender.label_text)
    if is_instance_valid(qb_node) and qb_node.visible:
        _draw_player(qb_node, qb_node.body_color, qb_node.label_text)
    if football_node != null and is_instance_valid(football_node) and football_node.visible:
        _draw_ball()

func _draw_field() -> void:
    draw_rect(Rect2(0, 0, GameConstants.SCREEN_SIZE.x, HORIZON_Y), Color("0c2a1c"), true)
    draw_rect(Rect2(0, HORIZON_Y, GameConstants.SCREEN_SIZE.x, BASELINE_Y - HORIZON_Y), Color("17653a"), true)

    var eye: Vector2 = _get_eye()
    var near_x: float = eye.x + MIN_YARD_DEPTH
    var far_x: float = eye.x + MAX_YARD_DEPTH

    _draw_sideline(GameConstants.FIELD_TOP, near_x, far_x)
    _draw_sideline(GameConstants.FIELD_BOTTOM, near_x, far_x)

    var yard: int = 0
    while yard <= 100:
        var world_x: float = GameConstants.LEFT_GOAL_X + float(yard) * GameConstants.PIXELS_PER_YARD
        if world_x >= near_x and world_x <= far_x:
            var is_goal_line: bool = yard == 0 or yard == 100
            var color: Color = Color(1.0, 1.0, 1.0, 0.6 if is_goal_line else 0.32)
            var width: float = 3.0 if is_goal_line else 1.5
            _draw_yard_band(world_x, color, width)
        yard += 5

    if line_of_scrimmage_x >= near_x and line_of_scrimmage_x <= far_x:
        _draw_yard_band(line_of_scrimmage_x, Color("48a7ff"), 3.0)
    if first_down_x < GameConstants.RIGHT_GOAL_X and first_down_x >= near_x and first_down_x <= far_x:
        _draw_yard_band(first_down_x, Color("ffd84d"), 3.0)

func _draw_sideline(world_y: float, near_x: float, far_x: float) -> void:
    var near_proj: Dictionary = project(Vector2(near_x, world_y))
    var far_proj: Dictionary = project(Vector2(far_x, world_y))
    draw_line(near_proj["pos"], far_proj["pos"], Color.WHITE, 3.0)

func _draw_yard_band(world_x: float, color: Color, width: float) -> void:
    var left: Dictionary = project(Vector2(world_x, GameConstants.FIELD_TOP))
    var right: Dictionary = project(Vector2(world_x, GameConstants.FIELD_BOTTOM))
    draw_line(left["pos"], right["pos"], color, width)

func _draw_player(node: Node2D, color: Color, label: String) -> void:
    var proj: Dictionary = project(node.global_position)
    var scale_factor: float = proj["scale"]
    var radius: float = GameConstants.PLAYER_RADIUS * scale_factor * 1.35
    if radius < 1.0:
        return
    draw_circle(proj["pos"], radius + 3.0, Color.WHITE)
    draw_circle(proj["pos"], radius, color)
    var font_size: int = clampi(int(round(13.0 * scale_factor)), 8, 22)
    var font: Font = ThemeDB.fallback_font
    var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    draw_string(font, proj["pos"] + Vector2(-text_size.x * 0.5, text_size.y * 0.34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _draw_ball() -> void:
    var proj: Dictionary = project(football_node.global_position)
    var scale_factor: float = proj["scale"]
    draw_circle(proj["pos"], maxf(6.0 * scale_factor, 1.5), Color("6b3b1e"))
