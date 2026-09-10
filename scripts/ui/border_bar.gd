extends Control

# Tug-of-war strip: the line of scrimmage drawn as the frontier between two
# empires. Home color fills from the left up to the frontier.

const NAME_WIDTH: float = 96.0

var home_color: Color = Color("2f77c7")
var away_color: Color = Color("c2622a")
var home_short: String = "HOME"
var away_short: String = "AWAY"
var fraction: float = 0.5

func setup(home: Dictionary, away: Dictionary) -> void:
    home_color = home["color"]
    away_color = away["color"]
    home_short = home["short"]
    away_short = away["short"]
    queue_redraw()

func set_fraction(value: float) -> void:
    fraction = clampf(value, 0.0, 1.0)
    queue_redraw()

func _draw() -> void:
    var track: Rect2 = Rect2(NAME_WIDTH, 0.0, size.x - NAME_WIDTH * 2.0, size.y)
    var split_x: float = track.position.x + track.size.x * fraction
    draw_rect(Rect2(track.position, Vector2(split_x - track.position.x, track.size.y)), home_color, true)
    draw_rect(Rect2(Vector2(split_x, track.position.y), Vector2(track.end.x - split_x, track.size.y)), away_color, true)
    draw_rect(track, Color(1, 1, 1, 0.85), false, 2.0)
    draw_line(Vector2(split_x, track.position.y - 4.0), Vector2(split_x, track.end.y + 4.0), Color.WHITE, 3.0)

    var font: Font = ThemeDB.fallback_font
    var font_size: int = 16
    var home_size: Vector2 = font.get_string_size(home_short, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    var baseline: float = size.y * 0.5 + home_size.y * 0.3
    draw_string(font, Vector2(track.position.x - home_size.x - 10.0, baseline), home_short, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, home_color.lightened(0.35))
    draw_string(font, Vector2(track.end.x + 10.0, baseline), away_short, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, away_color.lightened(0.35))
