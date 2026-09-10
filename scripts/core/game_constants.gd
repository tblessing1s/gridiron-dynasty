extends RefCounted

const SCREEN_SIZE: Vector2 = Vector2(1280.0, 720.0)
const FIELD_RECT: Rect2 = Rect2(40.0, 90.0, 1200.0, 600.0)
const LEFT_GOAL_X: float = 140.0
const RIGHT_GOAL_X: float = 1140.0
const FIELD_TOP: float = 100.0
const FIELD_BOTTOM: float = 680.0
const END_ZONE_WIDTH: float = 100.0

# Border War is played on a short 40-yard field so three possessions each can
# actually produce points.
const FIELD_YARDS: int = 40
const PIXELS_PER_YARD: float = 25.0
const MIDFIELD_YARD: int = 20
const FIRST_DOWN_YARDS: int = 10
const POSSESSIONS_PER_TEAM: int = 3
const STARTING_LOS_X: float = LEFT_GOAL_X + float(MIDFIELD_YARD) * PIXELS_PER_YARD

const PLAYER_RADIUS: float = 14.0
const TACKLE_RADIUS: float = 26.0
const CATCH_RADIUS: float = 34.0
const OUT_OF_BOUNDS_MARGIN: float = 12.0
