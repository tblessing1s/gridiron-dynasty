extends Node2D

const GameConstants = preload("res://scripts/core/game_constants.gd")

var line_of_scrimmage_x: float = GameConstants.STARTING_LOS_X
var first_down_x: float = GameConstants.STARTING_LOS_X + (10.0 * GameConstants.PIXELS_PER_YARD)

func _ready() -> void:
    z_index = -10
    queue_redraw()

func set_markers(los_x: float, first_x: float) -> void:
    line_of_scrimmage_x = los_x
    first_down_x = first_x
    queue_redraw()

func _draw() -> void:
    var rect: Rect2 = GameConstants.FIELD_RECT
    draw_rect(rect, Color("17653a"), true)

    draw_rect(Rect2(rect.position, Vector2(GameConstants.END_ZONE_WIDTH, rect.size.y)), Color("234a72"), true)
    draw_rect(Rect2(Vector2(rect.end.x - GameConstants.END_ZONE_WIDTH, rect.position.y), Vector2(GameConstants.END_ZONE_WIDTH, rect.size.y)), Color("7a2f35"), true)

    draw_line(Vector2(GameConstants.LEFT_GOAL_X, GameConstants.FIELD_TOP), Vector2(GameConstants.LEFT_GOAL_X, GameConstants.FIELD_BOTTOM), Color.WHITE, 4.0)
    draw_line(Vector2(GameConstants.RIGHT_GOAL_X, GameConstants.FIELD_TOP), Vector2(GameConstants.RIGHT_GOAL_X, GameConstants.FIELD_BOTTOM), Color.WHITE, 4.0)

    for yard in range(5, 100, 5):
        var x: float = GameConstants.LEFT_GOAL_X + float(yard) * GameConstants.PIXELS_PER_YARD
        var width: float = 1.0
        var alpha: float = 0.3
        if yard % 10 == 0:
            width = 3.0
            alpha = 0.6
        draw_line(Vector2(x, GameConstants.FIELD_TOP), Vector2(x, GameConstants.FIELD_BOTTOM), Color(1.0, 1.0, 1.0, alpha), width)

    for yard in range(1, 100):
        var x: float = GameConstants.LEFT_GOAL_X + float(yard) * GameConstants.PIXELS_PER_YARD
        draw_line(Vector2(x, 330.0), Vector2(x, 340.0), Color(1.0, 1.0, 1.0, 0.55), 1.0)
        draw_line(Vector2(x, 440.0), Vector2(x, 450.0), Color(1.0, 1.0, 1.0, 0.55), 1.0)

    draw_line(Vector2(line_of_scrimmage_x, GameConstants.FIELD_TOP), Vector2(line_of_scrimmage_x, GameConstants.FIELD_BOTTOM), Color("48a7ff"), 3.0)
    if first_down_x < GameConstants.RIGHT_GOAL_X:
        draw_line(Vector2(first_down_x, GameConstants.FIELD_TOP), Vector2(first_down_x, GameConstants.FIELD_BOTTOM), Color("ffd84d"), 3.0)

    _draw_centered_text(Vector2(90.0, 390.0), "HOME", 24)
    _draw_centered_text(Vector2(1190.0, 390.0), "TD", 24)

func _draw_centered_text(pos: Vector2, text: String, font_size: int) -> void:
    var font: Font = ThemeDB.fallback_font
    var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    draw_string(font, pos - Vector2(text_size.x * 0.5, -text_size.y * 0.25), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 0.78))
